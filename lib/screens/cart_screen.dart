import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/order.dart';
import '../utils/currency_utils.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'John Doe');
  final TextEditingController _addressController = TextEditingController(text: '402 Sunrise Heights');
  final TextEditingController _cityController = TextEditingController(text: 'Mumbai');
  final TextEditingController _pinController = TextEditingController(text: '400050');
  final TextEditingController _phoneController = TextEditingController(text: '9876543210');
  
  final _formKey = GlobalKey<FormState>();
  bool _isProcessingCheckout = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pinController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _processDemoPayment(AppStateProvider provider, bool simulateSuccess) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final fullAddress = '${_nameController.text.trim()}, ${_addressController.text.trim()}, ${_cityController.text.trim()}, PIN: ${_pinController.text.trim()}, Phone: ${_phoneController.text.trim()}';


    setState(() {
      _isProcessingCheckout = true;
    });

    // Prevent duplicate taps & simulate network payment gateway latency
    await Future.delayed(const Duration(milliseconds: 1200));

    Order? order = await provider.checkout(
      shippingAddress: fullAddress,
      simulateSuccess: simulateSuccess,
    );

    if (mounted) {
      setState(() {
        _isProcessingCheckout = false;
      });

      if (simulateSuccess && order != null) {
        _showOrderConfirmationDialog(context, order);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Demo payment cancelled/failed. No order or commission created.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showOrderConfirmationDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
            SizedBox(width: 8),
            Text('Order Confirmed!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: ${order.id}', style: const TextStyle(color: Colors.amber, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Total Amount: ${CurrencyUtils.formatPaise(order.totalPaise)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Shipping Address:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(order.shippingAddress, style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade900,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '🎉 Eligible creator commissions recorded as "Pending" until order completion by Admin!',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Back to previous screen
            },
            child: const Text('Continue Shopping', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final cart = provider.userCart;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: Text('Shopping Cart (${cart.length})', style: const TextStyle(color: Colors.white)),
      ),
      body: cart.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.remove_shopping_cart, size: 64, color: Colors.white38),
                  SizedBox(height: 12),
                  Text('Your cart is empty', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cart Items List (Preserves Creator Attribution)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cart.length,
                    itemBuilder: (ctx, idx) {
                      final item = cart[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.product.imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey.shade800,
                                  child: const Icon(Icons.shopping_bag, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyUtils.formatPaise(item.product.pricePaise),
                                    style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                                  ),
                                  if (item.referrerCreatorId != null)
                                    Text(
                                      'Attributed to Creator: ${item.referrerCreatorId}',
                                      style: const TextStyle(color: Colors.amber, fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            // Quantity Controls
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                                  onPressed: () {
                                    provider.updateCartQuantity(item.product.id, item.referrerCreatorId, item.referrerPostId, item.quantity - 1);
                                  },
                                ),
                                Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                                  onPressed: () {
                                    provider.updateCartQuantity(item.product.id, item.referrerCreatorId, item.referrerPostId, item.quantity + 1);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Shipping Address Validation Section
                  const Text('Delivery Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Recipient Name', filled: true, fillColor: Colors.black26),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _addressController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Address', filled: true, fillColor: Colors.black26),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Address required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _cityController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'City', filled: true, fillColor: Colors.black26),
                          validator: (v) => v == null || v.trim().isEmpty ? 'City required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _pinController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'PIN Code', filled: true, fillColor: Colors.black26),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'PIN Code required';
                            if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) return 'Enter a valid 6-digit PIN';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Mobile Number (+91 is assumed)', filled: true, fillColor: Colors.black26),
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Mobile Number required';
                            String clean = v.trim().replaceAll('+91', '');
                            if (!RegExp(r'^\d{10}$').hasMatch(clean)) return 'Enter a valid 10-digit mobile number';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Order Summary Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.pinkAccent.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        const Text('Order Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(color: Colors.white24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Items Subtotal:', style: TextStyle(color: Colors.white70)),
                            Text(CurrencyUtils.formatPaise(provider.cartTotalPaise), style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Shipping Fee:', style: TextStyle(color: Colors.white70)),
                            Text('FREE', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(color: Colors.white24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Payable:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              CurrencyUtils.formatPaise(provider.cartTotalPaise),
                              style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Functional Demo Payment Controls (Requirement #6)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Demo payment — no real money charged.',
                            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _isProcessingCheckout
                      ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                      : Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                                onPressed: () => _processDemoPayment(provider, true),
                                icon: const Icon(Icons.check_circle, color: Colors.white),
                                label: const Text('Simulate Successful Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                                onPressed: () => _processDemoPayment(provider, false),
                                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                                label: const Text('Simulate Failed / Cancelled Payment', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
    );
  }
}
