import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/order.dart';
import '../utils/currency_utils.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final orders = provider.userOrders;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text('My Purchase Orders', style: TextStyle(color: Colors.white)),
      ),
      body: orders.isEmpty
          ? const Center(
              child: Text('No orders placed yet.', style: TextStyle(color: Colors.white54)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (ctx, idx) {
                final order = orders[idx];
                return Card(
                  color: Colors.grey.shade900,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              order.id,
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            _buildStatusBadge(order.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Placed on: ${order.createdAt.toString().substring(0, 16)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const Divider(color: Colors.white24),
                        ...order.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.productName} (x${item.quantity})',
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ),
                                Text(
                                  CurrencyUtils.formatPaise(item.totalPaise),
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text(
                              CurrencyUtils.formatPaise(order.totalPaise),
                              style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg;
    String label;
    switch (status) {
      case OrderStatus.pending:
        bg = Colors.orange;
        label = 'Pending';
        break;
      case OrderStatus.paid:
        bg = Colors.blue;
        label = 'Paid (Demo)';
        break;
      case OrderStatus.completed:
        bg = Colors.green;
        label = 'Completed';
        break;
      case OrderStatus.cancelled:
        bg = Colors.red;
        label = 'Cancelled';
        break;
      case OrderStatus.refunded:
        bg = Colors.purple;
        label = 'Refunded';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
