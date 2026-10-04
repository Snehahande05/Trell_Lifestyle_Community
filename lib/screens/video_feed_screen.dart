import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../models/post.dart';
import '../widgets/short_video_player_item.dart';
import '../widgets/demo_account_switcher.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<String> _categories = [
    'All',
    'Fashion',
    'Beauty',
    'Travel',
    'Food',
    'DIY',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final posts = provider.feedPosts;
    final selectedCategory = provider.selectedCategory;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Demo Account Switcher
            const DemoAccountSwitcherBar(),

            // Category Selector Filter Chips
            Container(
              height: 46,
              color: Colors.black,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                      backgroundColor: Colors.grey.shade900,
                      selectedColor: Colors.pinkAccent,
                      onSelected: (bool selected) {
                        provider.setCategory(cat);
                        if (_pageController.hasClients) {
                          _pageController.jumpToPage(0);
                        }
                        setState(() {
                          _currentIndex = 0;
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            // Video Feed ViewPager / Empty State / Loading State
            Expanded(
              child: provider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pinkAccent,
                      ),
                    )
                  : posts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.video_library_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No posts available in "$selectedCategory"',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              provider.setCategory('All');
                              if (_pageController.hasClients) {
                                _pageController.jumpToPage(0);
                              }
                              setState(() {
                                _currentIndex = 0;
                              });
                            },
                            child: const Text('Show All Categories'),
                          ),
                        ],
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final now = DateTime.now().toUtc();
                        // Centralized active-promotion rule (Step 10 §10):
                        // Active = isPromoted && promotionExpiry != null && expiryTime > now.
                        // promotionExpiry == null alone does NOT count as active.
                        // Deterministic ordering: active promoted first (newest first),
                        // then non-promoted (newest first).
                        bool isPostActivelyPromoted(Post p) =>
                            p.isPromoted &&
                            p.promotionExpiry != null &&
                            p.promotionExpiry!.toUtc().isAfter(now);

                        final sortedPosts = List<Post>.from(posts)
                          ..sort((a, b) {
                            final aPromoted = isPostActivelyPromoted(a);
                            final bPromoted = isPostActivelyPromoted(b);
                            if (aPromoted && !bPromoted) return -1;
                            if (!aPromoted && bPromoted) return 1;
                            // Same bucket: newest first (deterministic)
                            return b.createdAt.compareTo(a.createdAt);
                          });

                        return PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          itemCount: sortedPosts.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final post = sortedPosts[index];
                            return ShortVideoPlayerItem(
                              key: ValueKey(post.id),
                              post: post,
                              isSelected: index == _currentIndex,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
