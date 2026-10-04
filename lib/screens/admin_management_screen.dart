import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../models/user.dart';
import '../models/order.dart';
import '../models/wallet.dart';
import '../models/review_and_verification.dart';
import '../utils/currency_utils.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _revShareCreatorController =
      TextEditingController(text: 'u_creator1');
  final TextEditingController _revShareBudgetController = TextEditingController(
    text: '5000',
  );
  double _revShareRate = 0.20; // 20% default

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _revShareCreatorController.dispose();
    _revShareBudgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final user = provider.currentUser;

    if (user == null || user.role != UserRole.admin) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.grey.shade900,
          title: const Text(
            'Admin Portal Restricted',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Restricted Access - Admin Account Required',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () {
                  provider.switchDemoUser('u_admin');
                },
                child: const Text(
                  'Switch to Demo Admin Account',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final allOrders = provider.allOrders;
    final withdrawals = provider.allWithdrawalRequests;
    final verifications = provider.allVerificationApplications;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Admin Platform Management',
          style: TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Payouts'),
            Tab(text: 'Badges'),
            Tab(text: 'Rev Share'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Order Completion & Commission Release Management
          allOrders.isEmpty
              ? const Center(
                  child: Text(
                    'No orders to manage.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: allOrders.length,
                  itemBuilder: (ctx, idx) {
                    final order = allOrders[idx];
                    return Card(
                      color: Colors.grey.shade900,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order: ${order.id}',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Status: ${order.status.name.toUpperCase()}',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Buyer: ${order.buyerName} • Amount: ${CurrencyUtils.formatPaise(order.totalPaise)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (order.status == OrderStatus.paid)
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    onPressed: () async {
                                      await provider.updateOrderStatus(
                                        order.id,
                                        OrderStatus.completed,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Order Completed! Attributed Creator Commission Released to Available Balance.',
                                                ),
                                              ),
                                            );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Complete Order & Release Comm',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    onPressed: () async {
                                      await provider.updateOrderStatus(
                                        order.id,
                                        OrderStatus.cancelled,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.cancel,
                                      size: 16,
                                      color: Colors.redAccent,
                                    ),
                                    label: const Text(
                                      'Cancel & Reverse',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // 2. Withdrawal Request Payout Approval/Rejection
          withdrawals.isEmpty
              ? const Center(
                  child: Text(
                    'No withdrawal requests.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: withdrawals.length,
                  itemBuilder: (ctx, idx) {
                    final req = withdrawals[idx];
                    return Card(
                      color: Colors.grey.shade900,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          '${req.creatorName} - ${CurrencyUtils.formatPaise(req.amountPaise)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'UPI: ${req.upiIdOrBank}\nStatus: ${req.status.name.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        trailing: req.status == WithdrawalStatus.pending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check_circle,
                                      color: Colors.greenAccent,
                                    ),
                                    onPressed: () async {
                                      await provider.processWithdrawal(
                                        req.id,
                                        true,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.cancel,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      await provider.processWithdrawal(
                                        req.id,
                                        false,
                                        reason: 'Admin rejected',
                                      );
                                    },
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                ),

          // 3. Creator Verification Review Section (Requirement #9)
          verifications.isEmpty
              ? const Center(
                  child: Text(
                    'No creator applications.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: verifications.length,
                  itemBuilder: (ctx, idx) {
                    final app = verifications[idx];
                    return Card(
                      color: Colors.grey.shade900,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.creatorName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Category: ${app.category} • Social: ${app.socialLink}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reason: ${app.reason}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Submitted: ${app.submittedAt.toLocal().toString().substring(0, 16)}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            if (app.decidedAt != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Decision: ${app.decidedAt!.toLocal().toString().substring(0, 16)} by admin',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            if (app.rejectionReason != null &&
                                app.rejectionReason!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade900.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Rejection Reason: ${app.rejectionReason}',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            if (app.status == VerificationStatus.pending)
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    onPressed: () async {
                                      await provider.processVerification(
                                        app.id,
                                        true,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Creator badge approved!',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                      }
                                    },
                                    child: const Text(
                                      'Approve Badge ✔️',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    onPressed: () async {
                                      // Require rejection reason
                                      final TextEditingController reasonCtrl =
                                          TextEditingController();
                                      final String?
                                      reason = await showDialog<String>(
                                        context: context,
                                        builder: (dialogCtx) => AlertDialog(
                                          backgroundColor: Colors.grey.shade900,
                                          title: const Text(
                                            'Rejection Reason',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          content: TextField(
                                            controller: reasonCtrl,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                            maxLines: 3,
                                            decoration: const InputDecoration(
                                              hintText: 'Required: explain why the application is rejected',
                                              hintStyle: TextStyle(
                                                color: Colors.white38,
                                              ),
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogCtx),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                              onPressed: () {
                                                if (reasonCtrl.text
                                                    .trim()
                                                    .isNotEmpty) {
                                                  Navigator.pop(
                                                    dialogCtx,
                                                    reasonCtrl.text.trim(),
                                                  );
                                                }
                                              },
                                              child: const Text(
                                                'Confirm Reject',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (reason != null && context.mounted) {
                                        await provider.processVerification(
                                          app.id,
                                          false,
                                          rejectionReason: reason,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Application rejected: $reason',
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text(
                                      'Reject',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'Status: ${app.status.name.toUpperCase()}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // 4. Verified Creator Revenue Share Allocation (Requirement #11)
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade900.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purpleAccent),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified Creator Revenue Share (Up to 30%)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Project Assumption: Illustrative program separate from product affiliate commission. Admin records demo platform revenue allocation with a rate capped at 30%.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _revShareCreatorController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Target Creator ID (e.g. u_creator1)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _revShareBudgetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Platform Source Amount (in ₹ Rupees)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Revenue Share Rate: ${(_revShareRate * 100).toInt()}% (Cap: 30%)',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _revShareRate,
                  min: 0.05,
                  max: 0.30,
                  divisions: 25,
                  activeColor: Colors.pinkAccent,
                  onChanged: (val) {
                    setState(() {
                      _revShareRate = val;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                    ),
                    onPressed: () async {
                      double? amountRupees = double.tryParse(
                        _revShareBudgetController.text.trim(),
                      );
                      if (amountRupees != null && amountRupees > 0) {
                        int sourcePaise = (amountRupees * 100).round();
                        final messenger = ScaffoldMessenger.of(context);
                        await provider.recordRevenueShare(
                          _revShareCreatorController.text.trim(),
                          sourcePaise,
                          _revShareRate,
                          'Platform Revenue Allocation Campaign',
                        );
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Revenue Share Record created!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Record Revenue Share Allocation',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
