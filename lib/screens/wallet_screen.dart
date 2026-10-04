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

    // Compute each ledger bucket precisely from commissions
    int availablePaise = commissions
        .where((c) => c.status == CommissionStatus.available)
        .fold(0, (sum, c) => sum + c.amountPaise);
    int reservedPaise = commissions
        .where((c) => c.status == CommissionStatus.reserved)
        .fold(0, (sum, c) => sum + c.amountPaise);
    int pendingPaise = commissions
        .where((c) => c.status == CommissionStatus.pending)
        .fold(0, (sum, c) => sum + c.amountPaise);
    int paidOutPaise = commissions
        .where((c) => c.status == CommissionStatus.paidOut)
        .fold(0, (sum, c) => sum + c.amountPaise);
    // Clawback amounts are negative
    int clawbackSum = commissions
        .where((c) => c.status == CommissionStatus.clawback)
        .fold(0, (sum, c) => sum + c.amountPaise);
    bool hasClawbackDebt = clawbackSum < 0;

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
            // Demo payout disclaimer
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo payout — no real bank/UPI transfer. All withdrawals are simulated.',
                      style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Balance Breakdown Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurpleAccent]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Affiliate Commission Ledger', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  _buildBalanceRow('Pending (order not completed yet):', CurrencyUtils.formatPaise(pendingPaise), Colors.amberAccent),
                  _buildBalanceRow('Available (ready to withdraw):', CurrencyUtils.formatPaise(availablePaise), Colors.greenAccent),
                  _buildBalanceRow('Reserved (withdrawal in review):', CurrencyUtils.formatPaise(reservedPaise), Colors.lightBlueAccent),
                  _buildBalanceRow('Paid Out (withdrawn — demo):', CurrencyUtils.formatPaise(paidOutPaise), Colors.purpleAccent),
                  if (hasClawbackDebt) ...[
                    const Divider(color: Colors.white38),
                    _buildBalanceRow(
                      'Recovery Due (refund after payout):',
                      '-${CurrencyUtils.formatPaise(clawbackSum.abs())}',
                      Colors.redAccent,
                    ),
                    const Text(
                      '⚠ Withdrawals blocked until recovery debt is cleared from future earnings.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Withdrawal Form
            const Text('Request Demo Withdrawal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
              'Minimum: ₹100. Available balance is moved to "Reserved" on submission. Approved by admin moves it to "Paid Out". Rejection releases it back to "Available".',
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
                      onPressed: hasClawbackDebt ? null : () async {
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

                        if (_upiController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a UPI ID or bank account.')),
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
                                content: Text('Withdrawal request submitted! Funds reserved pending admin approval.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cannot submit: Insufficient available balance or outstanding recovery debt.'),
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

            // Withdrawal History
            Text(
              'Withdrawal History (${withdrawals.length})',
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
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    CurrencyUtils.formatPaise(req.amountPaise),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  _buildWithdrawalStatusBadge(req.status),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Ref: ${req.id}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              Text('To: ${req.upiIdOrBank}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              Text('Requested: ${req.requestedAt.toString().substring(0, 16)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              if (req.processedAt != null)
                                Text('Processed: ${req.processedAt.toString().substring(0, 16)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              if (req.rejectionReason != null)
                                Text('Reason: ${req.rejectionReason}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
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
        label = 'Paid Out (Demo)';
        break;
      case WithdrawalStatus.rejected:
        bg = Colors.red;
        label = 'Rejected — Released';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
