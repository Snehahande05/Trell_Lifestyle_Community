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
        body: Center(child: Text('Please select a user account.', style: TextStyle(color: Colors.white))),
      );
    }

    final analytics = provider.getCreatorAnalytics(user.id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: Text('${user.name} - Creator Analytics', style: const TextStyle(color: Colors.white, fontSize: 16)),
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
            // Historical Data Disclaimer Banner (Requirement #8)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.shade900.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purpleAccent),
              ),
              child: const Row(
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live Calculated Metrics (Seeded historical data labelled as demo history)',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top Quick Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Spendable Balance',
                    CurrencyUtils.formatPaise(analytics['spendableBalancePaise']),
                    Icons.account_balance_wallet,
                    Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Pending Commission',
                    CurrencyUtils.formatPaise(analytics['pendingCommissionPaise']),
                    Icons.pending_actions,
                    Colors.amberAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Paid-Out Earnings',
                    CurrencyUtils.formatPaise(analytics['paidOutCommissionPaise']),
                    Icons.payments,
                    Colors.lightBlueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Lifetime Earnings',
                    CurrencyUtils.formatPaise(analytics['lifetimeEarningsPaise']),
                    Icons.stars,
                    Colors.purpleAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Attributed Sales Value',
                    CurrencyUtils.formatPaise(analytics['salesValuePaise']),
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
            const SizedBox(height: 20),

            // Calculated Conversion & Engagement Rates Section (Requirement #8)
            const Text('Formula-Based Key Performance Indicators', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
                    'Formula: (Likes [${analytics['likes']}] + Comments [${analytics['comments']}] + Shares [${analytics['shares']}]) / Views [${analytics['views']}] × 100',
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  _buildFormulaRow(
                    'Conversion Rate',
                    '${(analytics['conversionRate'] as double).toStringAsFixed(2)}%',
                    'Formula: Attributed Purchases [${analytics['attributedPurchases']}] / Product Clicks [${analytics['clicks']}] × 100',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content Performance Metrics Grid
            const Text('Content Interaction Totals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
              children: [
                _buildSmallStatCard('Views', '${analytics['views']}', Icons.remove_red_eye, Colors.blue),
                _buildSmallStatCard('Likes', '${analytics['likes']}', Icons.favorite, Colors.redAccent),
                _buildSmallStatCard('Comments', '${analytics['comments']}', Icons.comment, Colors.orange),
                _buildSmallStatCard('Shares', '${analytics['shares']}', Icons.share, Colors.teal),
                _buildSmallStatCard('Clicks', '${analytics['clicks']}', Icons.ads_click, Colors.purpleAccent),
                _buildSmallStatCard('Posts', '${analytics['publishedPosts']}', Icons.video_collection, Colors.pink),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildFormulaRow(String label, String value, String formulaExplanation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(value, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 4),
        Text(formulaExplanation, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildSmallStatCard(String label, String count, IconData icon, Color color) {
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
          Text(count, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}
