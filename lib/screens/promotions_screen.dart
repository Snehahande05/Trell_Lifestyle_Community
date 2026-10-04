import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/promotion.dart';
import '../utils/currency_utils.dart';

/// DEMO PROMOTION SCREEN — Step 10
///
/// Package: ₹499 for 7 days featured placement (documented in PromotionRecord).
/// Clearly labelled: "Demo promotion payment — no real money is charged."
/// Does not promise guaranteed views, followers, sales, or reach.
///
/// TEST-ONLY shortcut for expiry: pass a Duration override via the
/// [testExpiryDurationOverride] constructor arg. This shortcut is NOT
/// accessible from the normal user flow and does NOT change the advertised
/// ₹499 / 7-day package shown to users.
class PromotionsScreen extends StatefulWidget {
  /// TEST-ONLY: override promotion duration for rapid expiry checks.
  /// In the normal user flow this is always null.
  final Duration? testExpiryDurationOverride;

  const PromotionsScreen({super.key, this.testExpiryDurationOverride});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen>
    with SingleTickerProviderStateMixin {
  // ₹499 fixed package terms (stored in precise paise)
  static const int _packagePricePaise = 49900;
  static const int _packageDurationDays = 7;
  static const String _packageLabel = '7-Day Featured Placement';

  String? _selectedPostId;
  bool _isProcessing = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

    final myPosts = provider.feedPosts.where((p) => p.creatorId == user.id).toList();
    final myPromotions = provider.currentCreatorPromotions;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Promote Featured Posts', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Promote'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPromoteTab(context, provider, myPosts),
          _buildHistoryTab(myPromotions),
        ],
      ),
    );
  }

  Widget _buildPromoteTab(BuildContext context, AppStateProvider provider, List posts) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Package info card ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.amber, Colors.deepOrange]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text('Entry Promotion Package', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Price: ${CurrencyUtils.formatPaise(_packagePricePaise)} for $_packageDurationDays Days Featured Placement',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Demo promotion payment — no real money is charged.\n'
                  'Featured posts appear above non-promoted posts in All and category feeds.\n'
                  'No guarantee of views, followers, sales, or reach.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Post selector ───────────────────────────────────────────────────
          const Text('Select Your Post to Promote:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          posts.isEmpty
              ? const Text('You have not published any posts yet.', style: TextStyle(color: Colors.white54))
              : Column(
                  children: (posts as List).map((post) {
                    final now = DateTime.now().toUtc();
                    final isActive = post.isPromoted &&
                        post.promotionExpiry != null &&
                        post.promotionExpiry!.isAfter(now);
                    final isSelected = _selectedPostId == post.id;
                    return Card(
                      color: isSelected ? Colors.purple.shade900 : Colors.grey.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isSelected ? Colors.pinkAccent : Colors.transparent),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          post.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Category: ${post.category} • Views: ${post.viewsCount}\n'
                          '${isActive ? "🔥 Promoted — expires ${_formatExpiry(post.promotionExpiry!)}" : "Not promoted"}',
                          style: TextStyle(color: isActive ? Colors.amber : Colors.white54, fontSize: 12),
                        ),
                        trailing: Radio<String>(
                          value: post.id,
                          groupValue: _selectedPostId,
                          activeColor: Colors.pinkAccent,
                          onChanged: (val) => setState(() => _selectedPostId = val),
                        ),
                        onTap: () => setState(() => _selectedPostId = post.id),
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 24),

          // ── CTA ─────────────────────────────────────────────────────────────
          if (_selectedPostId != null) _buildCta(context, provider),
        ],
      ),
    );
  }

  Widget _buildCta(BuildContext context, AppStateProvider provider) {
    final post = provider.feedPosts.firstWhere(
      (p) => p.id == _selectedPostId,
      orElse: () => provider.feedPosts.first,
    );
    final now = DateTime.now().toUtc();
    final isActivePromotion = post.isPromoted &&
        post.promotionExpiry != null &&
        post.promotionExpiry!.isAfter(now);

    if (isActivePromotion) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade900.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber),
        ),
        child: Row(
          children: [
            const Icon(Icons.info, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This post is currently promoted and expires '
                '${_formatExpiry(post.promotionExpiry!)}. '
                'A new promotion can be purchased after expiry.',
                style: const TextStyle(color: Colors.amber, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
        onPressed: _isProcessing ? null : () => _handlePromotionPayment(context, provider),
        icon: _isProcessing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.flash_on, color: Colors.white),
        label: Text(
          _isProcessing ? 'Processing...' : 'Pay ${CurrencyUtils.formatPaise(_packagePricePaise)} & Promote',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _handlePromotionPayment(BuildContext context, AppStateProvider provider) async {
    if (_selectedPostId == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Generate a stable idempotency key for this payment attempt
      final attemptKey = 'promo_${_selectedPostId}_${DateTime.now().millisecondsSinceEpoch}';

      // Show demo outcome dialog
      if (!mounted) return;
      final outcome = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Simulated Promotion Payment', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Package: $_packageLabel', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text(
                'Cost: ${CurrencyUtils.formatPaise(_packagePricePaise)}',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Demo promotion payment — no real money is charged.',
                style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 4),
              const Text(
                'No guarantee of views, followers, or sales.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, 'cancel'),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
              onPressed: () => Navigator.pop(dialogCtx, 'fail'),
              child: const Text('Simulate Failure', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(dialogCtx, 'success'),
              child: const Text('Simulate Success', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (outcome == null || outcome == 'cancel') {
        // Cancellation: record a cancelled attempt, preserve post selection
        await provider.createPromotionAttempt(
          paymentAttemptId: attemptKey,
          postId: _selectedPostId!,
          simulateSuccess: false,
          failureReason: null, // null = cancelled (not failed)
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Promotion payment cancelled. Post was not promoted.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (outcome == 'fail') {
        await provider.createPromotionAttempt(
          paymentAttemptId: attemptKey,
          postId: _selectedPostId!,
          simulateSuccess: false,
          failureReason: 'Simulated payment failure',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment failed. Post was not promoted. You may try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Success
      await provider.createPromotionAttempt(
        paymentAttemptId: attemptKey,
        postId: _selectedPostId!,
        simulateSuccess: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Demo Promotion Successful! Post featured for $_packageDurationDays days.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _selectedPostId = null);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildHistoryTab(List<PromotionRecord> promotions) {
    if (promotions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.white38),
            SizedBox(height: 12),
            Text('No promotion history yet.', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    final now = DateTime.now().toUtc();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: promotions.length,
      itemBuilder: (ctx, idx) {
        final promo = promotions[idx];
        final isActive = promo.isActive(now: now);
        final isExpired = promo.isExpired(now: now);

        Color statusColor;
        String statusLabel;
        switch (promo.paymentStatus) {
          case PromotionPaymentStatus.success:
            if (isActive) {
              statusColor = Colors.greenAccent;
              statusLabel = 'Active';
            } else if (isExpired) {
              statusColor = Colors.white54;
              statusLabel = 'Expired';
            } else {
              statusColor = Colors.amber;
              statusLabel = 'Paid';
            }
          case PromotionPaymentStatus.pending:
            statusColor = Colors.amber;
            statusLabel = 'Pending';
          case PromotionPaymentStatus.failed:
            statusColor = Colors.redAccent;
            statusLabel = 'Failed';
          case PromotionPaymentStatus.cancelled:
            statusColor = Colors.orange;
            statusLabel = 'Cancelled';
        }

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
                      '${CurrencyUtils.formatPaise(promo.packagePricePaise)} — ${promo.durationDays}-Day Package',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Post ID: ${promo.postId}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                Text(
                  'Attempted: ${promo.createdAt.toLocal().toString().substring(0, 16)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                if (promo.activationTime != null)
                  Text(
                    'Activated: ${promo.activationTime!.toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                if (promo.expiryTime != null) ...[ 
                  Text(
                    isActive
                        ? 'Expires: ${promo.expiryTime!.toLocal().toString().substring(0, 16)} '
                            '(${_remainingDuration(now, promo.expiryTime!)} remaining)'
                        : 'Expired: ${promo.expiryTime!.toLocal().toString().substring(0, 16)}',
                    style: TextStyle(
                      color: isActive ? Colors.greenAccent : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (promo.failureReason != null)
                  Text(
                    'Reason: ${promo.failureReason}',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                const SizedBox(height: 4),
                // Distinguish payment state from promotion state clearly
                if (promo.paymentStatus == PromotionPaymentStatus.success && isExpired)
                  const Text(
                    'Payment was successful — promotion window has since expired.',
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatExpiry(DateTime expiry) {
    final local = expiry.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _remainingDuration(DateTime now, DateTime expiry) {
    final diff = expiry.difference(now);
    if (diff.inHours >= 24) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inMinutes >= 60) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }
}
