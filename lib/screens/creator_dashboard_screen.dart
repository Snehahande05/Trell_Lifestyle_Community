import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../utils/currency_utils.dart';
import 'wallet_screen.dart';
import 'promotions_screen.dart';

class CreatorDashboardScreen extends StatelessWidget {
  const CreatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final user = provider.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Please select a user account.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final analytics = provider.getCreatorAnalytics(user.id);
    final products = provider.allProducts;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          '${user.name} — Creator Analytics',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.amber),
            tooltip: 'My Wallet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.campaign, color: Colors.pinkAccent),
            tooltip: 'Promote Posts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PromotionsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Disclaimer banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.shade900.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purpleAccent),
              ),
              child: const Row(
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Local demo analytics — data stored on-device only. Refunded orders are excluded from conversion counts.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Follower & Post overview
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Followers',
                    '${analytics['followers']}',
                    Icons.people,
                    Colors.cyanAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Published Posts',
                    '${analytics['publishedPosts']}',
                    Icons.video_collection,
                    Colors.pinkAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Earnings Ledger Section
            const Text(
              'Affiliate Commission Ledger',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.purpleAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  _buildLedgerRow(
                    'Pending (awaiting fulfilment)',
                    CurrencyUtils.formatPaise(
                      analytics['pendingCommissionPaise'],
                    ),
                    Colors.amberAccent,
                  ),
                  _buildLedgerRow(
                    'Available (ready to withdraw)',
                    CurrencyUtils.formatPaise(
                      analytics['availableCommissionPaise'],
                    ),
                    Colors.greenAccent,
                  ),
                  _buildLedgerRow(
                    'Reserved (withdrawal pending)',
                    CurrencyUtils.formatPaise(
                      analytics['reservedCommissionPaise'],
                    ),
                    Colors.lightBlueAccent,
                  ),
                  _buildLedgerRow(
                    'Paid Out (withdrawn — demo)',
                    CurrencyUtils.formatPaise(
                      analytics['paidOutCommissionPaise'],
                    ),
                    Colors.purpleAccent,
                  ),
                  if ((analytics['recoveryDuePaise'] as int) > 0)
                    _buildLedgerRow(
                      'Recovery Due (refund after payout)',
                      '-${CurrencyUtils.formatPaise(analytics['recoveryDuePaise'])}',
                      Colors.redAccent,
                    ),
                  const Divider(color: Colors.white24, height: 20),
                  _buildLedgerRow(
                    'Lifetime Gross Earnings',
                    CurrencyUtils.formatPaise(
                      analytics['lifetimeEarningsPaise'],
                    ),
                    Colors.white,
                    bold: true,
                  ),
                  const SizedBox(height: 4),
                  // Reconciliation equation display
                  Text(
                    'Reconciliation: Gross ₹ ${CurrencyUtils.formatPaise(analytics['grossCommissionPaise'])} '
                    '− Reversed ₹ ${CurrencyUtils.formatPaise(analytics['reversedCommissionPaise'])} '
                    '= Pending + Available + Reserved + Paid Out',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sales Metrics
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Attributed Orders',
                    '${analytics['attributedConversions']} orders',
                    Icons.shopping_bag,
                    Colors.pinkAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Units Sold',
                    '${analytics['unitsSold']} units',
                    Icons.sell,
                    Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Sales Value (Gross)',
                    CurrencyUtils.formatPaise(analytics['salesValuePaise']),
                    Icons.attach_money,
                    Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Net Cash Paid (Demo)',
                    CurrencyUtils.formatPaise(analytics['netCashPaidPaise']),
                    Icons.payments,
                    Colors.lightBlueAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Engagement & Conversion Rates
            const Text(
              'Formula-Based KPIs',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildFormulaRow(
                    'Engagement Rate',
                    '${(analytics['engagementRate'] as double).toStringAsFixed(2)}%',
                    '(Likes [${analytics['likes']}] + Comments [${analytics['comments']}] + Shares [${analytics['shares']}]) / Views [${analytics['views']}] × 100',
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  _buildFormulaRow(
                    'Conversion Rate (orders/clicks)',
                    '${(analytics['conversionRate'] as double).toStringAsFixed(2)}%',
                    'Attributed Paid Orders [${analytics['attributedConversions']}] / Affiliate Clicks [${analytics['clicks']}] × 100 — Refunded orders excluded',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content Interaction Grid
            const Text(
              'Content Interaction Totals',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: [
                _buildSmallStatCard(
                  'Views',
                  '${analytics['views']}',
                  Icons.remove_red_eye,
                  Colors.blue,
                ),
                _buildSmallStatCard(
                  'Likes',
                  '${analytics['likes']}',
                  Icons.favorite,
                  Colors.redAccent,
                ),
                _buildSmallStatCard(
                  'Comments',
                  '${analytics['comments']}',
                  Icons.comment,
                  Colors.orange,
                ),
                _buildSmallStatCard(
                  'Shares',
                  '${analytics['shares']}',
                  Icons.share,
                  Colors.teal,
                ),
                _buildSmallStatCard(
                  'Clicks',
                  '${analytics['clicks']}',
                  Icons.ads_click,
                  Colors.purpleAccent,
                ),
                _buildSmallStatCard(
                  'Posts',
                  '${analytics['publishedPosts']}',
                  Icons.video_collection,
                  Colors.pink,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Product Earning Potential (Step 8 §17)
            const Text(
              'Product Earning Potential (Estimates)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'These are estimates based on current product price × commission rate. Not guaranteed earnings. Historical order commissions use snapshotted rates and are unaffected by price changes.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              itemBuilder: (ctx, idx) {
                final product = products[idx];
                if (!product.isAvailable) return const SizedBox.shrink();
                // Same calculation helper as order commission (rounded)
                final estimatedCommPaise =
                    (product.pricePaise * product.commissionRate).round();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${CurrencyUtils.formatPaise(product.pricePaise)} × ${(product.commissionRate * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Est. ${CurrencyUtils.formatPaise(estimatedCommPaise)}/unit',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            '(estimate)',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerRow(
    String label,
    String value,
    Color color, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaRow(
    String label,
    String value,
    String formulaExplanation,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formulaExplanation,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSmallStatCard(
    String label,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
