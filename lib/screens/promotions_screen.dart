import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/post.dart';
import '../utils/currency_utils.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  static const int packagePricePaise = 49900; // Entry package starting at ₹499 (Requirement #10)
  static const int packageDurationDays = 7; // Project assumption: 7 days featured placement

  String? _selectedPostId;

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

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Promote Featured Posts', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Promotion Entry Package Info Card (Requirement #10)
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
                    'Price: ${CurrencyUtils.formatPaise(packagePricePaise)} for $packageDurationDays Days Featured Placement',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Project Assumption: Package duration is set to 7 days as duration is unspecified in the exam brief.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('Select Post to Promote:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            myPosts.isEmpty
                ? const Text('You have not published any posts yet.', style: TextStyle(color: Colors.white54))
                : Column(
                    children: myPosts.map((post) {
                      final isSelected = _selectedPostId == post.id;
                      return Card(
                        color: isSelected ? Colors.purple.shade900 : Colors.grey.shade900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: isSelected ? Colors.pinkAccent : Colors.transparent),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(post.caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Category: ${post.category} • Views: ${post.viewsCount}\n${post.isPromoted ? "🔥 Promoted until: ${post.promotionExpiry?.toString().substring(0, 10)}" : "Not Promoted"}',
                            style: TextStyle(color: post.isPromoted ? Colors.amber : Colors.white54, fontSize: 12),
                          ),
                          trailing: Radio<String>(
                            value: post.id,
                            groupValue: _selectedPostId,
                            activeColor: Colors.pinkAccent,
                            onChanged: (val) {
                              setState(() {
                                _selectedPostId = val;
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              _selectedPostId = post.id;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 24),

            if (_selectedPostId != null) ...[
              Builder(builder: (ctx) {
                final selectedPost = myPosts.firstWhere((p) => p.id == _selectedPostId);
                final isAlreadyActive = selectedPost.isPromoted &&
                    selectedPost.promotionExpiry != null &&
                    selectedPost.promotionExpiry!.isAfter(DateTime.now());

                if (isAlreadyActive) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This post is currently actively promoted. Duplicate promotions are disabled until expiry.',
                            style: TextStyle(color: Colors.amber, fontSize: 13),
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
                    onPressed: () async {
                      bool confirm = await showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              backgroundColor: Colors.grey.shade900,
                              title: const Text('Simulated Promotion Payment', style: TextStyle(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Package: ${packageDurationDays}-Day Featured Placement',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Cost: ${CurrencyUtils.formatPaise(packagePricePaise)}',
                                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Demo payment — no real money charged.',
                                    style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx, false),
                                  child: const Text('Cancel / Fail', style: TextStyle(color: Colors.redAccent)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  onPressed: () => Navigator.pop(dialogCtx, true),
                                  child: const Text('Simulate Success', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (!confirm) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Promotion payment cancelled or failed. Post was not promoted.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                        return;
                      }

                      await provider.promotePost(_selectedPostId!, packageDurationDays);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 Demo Promotion Checkout Successful! Post is now Promoted for 7 days.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.flash_on, color: Colors.white),
                    label: Text(
                      'Pay ${CurrencyUtils.formatPaise(packagePricePaise)} & Promote',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
