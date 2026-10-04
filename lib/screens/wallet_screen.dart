import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/wallet.dart';
import '../utils/currency_utils.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _upiController = TextEditingController(text: 'priya@upi');
  static const int minWithdrawalPaise = 10000; // Minimum withdrawal: ₹100 (10,000 paise)

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final user = provider.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('User not selected', style: TextStyle(color: Colors.white))),
      );
    }

    final commissions = provider.currentCreatorCommissions;
    final withdrawals = provider.currentCreatorWithdrawals;

    int totalAvailablePaise = commissions
        .where((c) => c.status == CommissionStatus.available)
        .fold(0, (sum, c) => sum + c.amountPaise);

    int pendingWithdrawalsPaise = withdrawals
        .where((w) => w.status == WithdrawalStatus.pending)
        .fold(0, (sum, w) => sum + w.amountPaise);

    int netAvailableBalancePaise = totalAvailablePaise - pendingWithdrawalsPaise;

    int pendingCommissionPaise = commissions
        .where((c) => c.status == CommissionStatus.pending)
        .fold(0, (sum, c) => sum + c.amountPaise);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Creator Wallet & Earnings', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Available Balance & Pending Cards
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.deepPurpleAccent],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Balance for Payout', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyUtils.formatPaise(netAvailableBalancePaise),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
                  ),
                  if (pendingWithdrawalsPaise > 0)
                    Text(
                      '(${CurrencyUtils.formatPaise(pendingWithdrawalsPaise)} reserved for pending withdrawal requests)',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                    ),
                  const Divider(color: Colors.white38, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pending Order Commission:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        CurrencyUtils.formatPaise(pendingCommissionPaise),
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Withdrawal Form Section (Requirement #7)
            const Text('Request Demo Withdrawal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
              'Minimum withdrawal limit: ₹100. Requested funds are immediately reserved to prevent overspending.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Amount (in ₹ Rupees)',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: 'e.g. 200',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _upiController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'UPI ID / Bank Account',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                      onPressed: () async {
                        double? amountRupees = double.tryParse(_amountController.text.trim());
                        if (amountRupees == null || amountRupees <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid numeric amount.')),
                          );
                          return;
                        }

                        int amountPaise = (amountRupees * 100).round();
                        if (amountPaise < minWithdrawalPaise) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Amount is below minimum withdrawal limit of ₹100.')),
                          );
                          return;
                        }

                        WithdrawalRequest? req = await provider.requestWithdrawal(
                          amountPaise,
                          _upiController.text.trim(),
                        );

                        if (mounted) {
                          if (req != null) {
                            _amountController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Withdrawal request submitted for Admin review!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Insufficient available balance for this request.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text('Submit Payout Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Withdrawal History List
            Text(
              'Withdrawal Requests (${withdrawals.length})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            withdrawals.isEmpty
                ? const Text('No withdrawal requests yet.', style: TextStyle(color: Colors.white54))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: withdrawals.length,
                    itemBuilder: (ctx, idx) {
                      final req = withdrawals[idx];
                      return Card(
                        color: Colors.grey.shade900,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(
                            CurrencyUtils.formatPaise(req.amountPaise),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'UPI: ${req.upiIdOrBank}\nRequested: ${req.requestedAt.toString().substring(0, 16)}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          trailing: _buildWithdrawalStatusBadge(req.status),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawalStatusBadge(WithdrawalStatus status) {
    Color bg;
    String label;
    switch (status) {
      case WithdrawalStatus.pending:
        bg = Colors.amber;
        label = 'Pending Admin Review';
        break;
      case WithdrawalStatus.approved:
        bg = Colors.green;
        label = 'Approved (Simulated)';
        break;
      case WithdrawalStatus.rejected:
        bg = Colors.red;
        label = 'Rejected (Refunded)';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
