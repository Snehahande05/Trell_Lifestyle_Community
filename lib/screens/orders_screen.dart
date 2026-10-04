import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../utils/currency_utils.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final orders = provider.userOrders;
    final currentUser = provider.currentUser;
    final isAdmin = currentUser?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          isAdmin ? 'All Orders (Admin)' : 'My Purchase Orders',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: orders.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No orders placed yet.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (ctx, idx) {
                final order = orders[idx];
                return Card(
                  color: Colors.grey.shade900,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                order.id,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusBadge(order.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Placed: ${order.createdAt.toString().substring(0, 16)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        // Order items with attribution info
                        ...order.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.productName} ×${item.quantity}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      CurrencyUtils.formatPaise(
                                        item.totalPaise,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.referrerCreatorId != null)
                                  Text(
                                    '  Attributed to creator: ${item.referrerCreatorId} | ${(item.commissionRate * 100).toStringAsFixed(0)}% commission',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                    ),
                                  )
                                else
                                  const Text(
                                    '  Direct purchase — no affiliate commission',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              CurrencyUtils.formatPaise(order.totalPaise),
                              style: const TextStyle(
                                color: Colors.pinkAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Shipping: ${order.shippingAddress}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Admin can only advance to permitted next states
                        // Customer cannot change order status
                        if (isAdmin)
                          _buildAdminTransitionControls(
                            context,
                            provider,
                            order,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAdminTransitionControls(
    BuildContext context,
    AppStateProvider provider,
    Order order,
  ) {
    // Show only permitted transitions for the current status
    final List<(String label, OrderStatus next, Color color)> allowed = [];

    if (order.status.canTransitionTo(OrderStatus.completed)) {
      allowed.add(('Mark Completed', OrderStatus.completed, Colors.green));
    }
    if (order.status.canTransitionTo(OrderStatus.cancelled)) {
      allowed.add(('Cancel Order', OrderStatus.cancelled, Colors.orange));
    }
    if (order.status.canTransitionTo(OrderStatus.refunded)) {
      allowed.add(('Issue Refund', OrderStatus.refunded, Colors.purple));
    }

    if (allowed.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        children: allowed.map((entry) {
          return OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: entry.$3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            onPressed: () async {
              await provider.updateOrderStatus(order.id, entry.$2);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Order ${order.id} → ${entry.$1}')),
                );
              }
            },
            child: Text(
              entry.$1,
              style: TextStyle(color: entry.$3, fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg;
    String label;
    switch (status) {
      case OrderStatus.pending:
        bg = Colors.orange;
        label = 'Pending Payment';
        break;
      case OrderStatus.paid:
        bg = Colors.blue;
        label = 'Paid (Demo) — Awaiting Fulfilment';
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
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
