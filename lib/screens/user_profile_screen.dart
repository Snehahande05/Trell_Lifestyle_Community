import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../utils/currency_utils.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'creator_verification_screen.dart';

import '../utils/image_utils.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final user = provider.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'User not logged in',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final revShares = provider.currentCreatorRevShares;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text('My Profile', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () {
              provider.logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 46,
              backgroundImage: getAdaptiveImageProvider(user.avatarUrl),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                if (user.isVerifiedCreator) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                ],
              ],
            ),
            Text(
              '@${user.username} • Role: ${user.role.name.toUpperCase()}',
              style: const TextStyle(
                color: Colors.pinkAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (user.bio != null) ...[
              const SizedBox(height: 6),
              Text(
                user.bio!,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),

            // Profile Actions List
            Card(
              color: Colors.grey.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.shopping_cart,
                      color: Colors.pinkAccent,
                    ),
                    title: const Text(
                      'My Shopping Cart',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      '${provider.cartItemCount} items',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.receipt_long,
                      color: Colors.amber,
                    ),
                    title: const Text(
                      'My Orders & History',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrdersScreen()),
                      );
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.verified_user,
                      color: Colors.blueAccent,
                    ),
                    title: const Text(
                      'Creator Verification Badge Status',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreatorVerificationScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      provider.logout();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Verified Creator Revenue Share Statement (Requirement #11)
            if (revShares.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Verified Creator Revenue Share Records',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: revShares.length,
                itemBuilder: (ctx, idx) {
                  final r = revShares[idx];
                  return Card(
                    color: Colors.grey.shade900,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        'Earned Share: ${CurrencyUtils.formatPaise(r.calculatedSharePaise)}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Platform Budget: ${CurrencyUtils.formatPaise(r.sourceAmountPaise)} @ ${(r.shareRate * 100).toInt()}%\n${r.note}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
