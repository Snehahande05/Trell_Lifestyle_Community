import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../models/product.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../utils/currency_utils.dart';
import '../services/attribution_service.dart';
import 'product_detail_screen.dart';
import '../widgets/short_video_player_item.dart';

class ExploreSearchScreen extends StatefulWidget {
  const ExploreSearchScreen({super.key});

  @override
  State<ExploreSearchScreen> createState() => _ExploreSearchScreenState();
}

class _ExploreSearchScreenState extends State<ExploreSearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _showImportReferralDialog(BuildContext context, AppStateProvider provider) {
    final linkController = TextEditingController(
      text: 'https://trell.app/ref?productId=p_2&creatorId=u_creator1&postId=post_1',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Row(
          children: [
            Icon(Icons.link, color: Colors.amber),
            SizedBox(width: 8),
            Text('Import Referral Link', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste or edit an affiliate referral link to open with creator attribution:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: linkController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'https://trell.app/ref?productId=...&creatorId=...&postId=...',
                hintStyle: TextStyle(color: Colors.white38),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Attribution Service validates Product, Creator, and Post tagging before routing.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () {
              final rawUrl = linkController.text.trim();
              final parsed = AttributionService.parseReferralUrl(rawUrl);

              if (parsed == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Malformed referral URL. Must include productId, creatorId, and postId.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              bool isValid = AttributionService.validateAttribution(
                provider.repository,
                productId: parsed.productId,
                creatorId: parsed.creatorId,
                postId: parsed.postId,
              );

              if (!isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Invalid Referral Link: Product, creator, or tagged post relationship validation failed. Attribution rejected.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              final product = provider.repository.getProductById(parsed.productId);
              if (product == null) return;

              // Record valid click and navigate
              provider.recordProductClick(parsed.postId, parsed.productId);
              Navigator.pop(ctx);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(
                    product: product,
                    referrerCreatorId: parsed.creatorId,
                    referrerPostId: parsed.postId,
                  ),
                ),
              );
            },
            child: const Text('Open & Validate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final query = _searchQuery.trim().toLowerCase();

    final filteredProducts = provider.allProducts.where((p) {
      return p.name.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query);
    }).toList();

    final filteredPosts = provider.feedPosts.where((p) {
      return p.caption.toLowerCase().contains(query) ||
          p.creatorName.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);
    }).toList();

    final filteredCreators = provider.allUsers.where((u) {
      return u.role == UserRole.creator &&
          (u.name.toLowerCase().contains(query) || u.username.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search products, creators & posts...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.pinkAccent),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link, color: Colors.amber),
            tooltip: 'Import Affiliate Referral Link',
            onPressed: () => _showImportReferralDialog(context, provider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Posts'),
            Tab(text: 'Creators'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Products Grid
          filteredProducts.isEmpty
              ? const Center(
                  child: Text('No products found', style: TextStyle(color: Colors.white54)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (ctx, idx) {
                    final product = filteredProducts[idx];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(product: product),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    const BorderRadius.vertical(top: Radius.circular(12)),
                                child: Image.network(
                                  product.imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade800,
                                    child: const Icon(Icons.shopping_bag, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        CurrencyUtils.formatPaise(product.pricePaise),
                                        style: const TextStyle(
                                          color: Colors.pinkAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade900,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${(product.commissionRate * 100).toInt()}% Comm',
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // 2. Posts List
          filteredPosts.isEmpty
              ? const Center(
                  child: Text('No posts found', style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredPosts.length,
                  itemBuilder: (ctx, idx) {
                    final post = filteredPosts[idx];
                    return Card(
                      color: Colors.grey.shade900,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(post.creatorAvatarUrl),
                        ),
                        title: Text(
                          post.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '@${post.creatorName} • ${post.category}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.play_circle_fill, color: Colors.pinkAccent),
                        onTap: () {
                          // Preview post in bottom sheet video player
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.black,
                            builder: (_) => SizedBox(
                              height: MediaQuery.of(context).size.height * 0.9,
                              child: ShortVideoPlayerItem(post: post, isSelected: true),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

          // 3. Creators List
          filteredCreators.isEmpty
              ? const Center(
                  child: Text('No creators found', style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredCreators.length,
                  itemBuilder: (ctx, idx) {
                    final creator = filteredCreators[idx];
                    final isFollowing = provider.isFollowing(creator.id);
                    return Card(
                      color: Colors.grey.shade900,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(creator.avatarUrl),
                        ),
                        title: Row(
                          children: [
                            Text(
                              creator.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (creator.isVerifiedCreator) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '@${creator.username} • ${creator.followerCount} followers\n${creator.bio ?? ""}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isFollowing ? Colors.grey.shade800 : Colors.pinkAccent,
                          ),
                          onPressed: () {
                            provider.toggleFollow(creator.id);
                          },
                          child: Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
