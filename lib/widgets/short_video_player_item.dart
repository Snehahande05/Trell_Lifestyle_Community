import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';
import '../models/product.dart';
import '../providers/app_state_provider.dart';
import '../utils/currency_utils.dart';
import '../screens/product_detail_screen.dart';

class ShortVideoPlayerItem extends StatefulWidget {
  final Post post;
  final bool isSelected;

  const ShortVideoPlayerItem({
    super.key,
    required this.post,
    required this.isSelected,
  });

  @override
  State<ShortVideoPlayerItem> createState() => _ShortVideoPlayerItemState();
}

class _ShortVideoPlayerItemState extends State<ShortVideoPlayerItem>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = false;
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed &&
        widget.isSelected &&
        !_userPaused) {
      _controller?.play();
    }
  }

  Future<void> _initializePlayer() async {
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _hasError = false;

    try {
      final path = widget.post.videoPath;
      if (path.startsWith('assets/')) {
        _controller = VideoPlayerController.asset(path);
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        final file = File(path);
        if (file.existsSync()) {
          _controller = VideoPlayerController.file(file);
        } else {
          _controller = VideoPlayerController.asset(
            'assets/videos/fashion_trend.mp4',
          );
        }
      }
      await _controller!.initialize();
      _controller!.setLooping(true);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.isSelected && !_userPaused) {
          _controller!.play();
          _triggerViewCount();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _triggerViewCount() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppStateProvider>().registerPostView(widget.post.id);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ShortVideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.videoPath != widget.post.videoPath) {
      _userPaused = false;
      _initializePlayer();
      return;
    }

    if (_controller != null && _isInitialized) {
      if (widget.isSelected && !_userPaused) {
        _controller!.play();
        if (!oldWidget.isSelected) {
          _triggerViewCount();
        }
      } else {
        _controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller != null && _isInitialized) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
          _userPaused = true;
        } else {
          _controller!.play();
          _userPaused = false;
        }
      });
    }
  }

  void _toggleMute() {
    if (_controller != null && _isInitialized) {
      setState(() {
        _isMuted = !_isMuted;
        _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      });
    }
  }

  Widget _buildVideoPlayerWithFilter() {
    Widget playerWidget = SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );

    final filter = widget.post.filterName;
    if (filter == 'B&W Mono') {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: playerWidget,
      );
    } else if (filter == 'Vintage Warm') {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.amber.withValues(alpha: 0.25),
          BlendMode.colorBurn,
        ),
        child: playerWidget,
      );
    } else if (filter == 'Soft Glow') {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.pink.withValues(alpha: 0.20),
          BlendMode.colorBurn,
        ),
        child: playerWidget,
      );
    } else if (filter == 'Vibrant Summer') {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.orange.withValues(alpha: 0.20),
          BlendMode.colorBurn,
        ),
        child: playerWidget,
      );
    }
    return playerWidget;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final currentUser = provider.currentUser;
    final isLiked =
        currentUser != null &&
        widget.post.likedUserIds.contains(currentUser.id);
    final isFollowing = provider.isFollowing(widget.post.creatorId);

    // Tagged Products
    final taggedProducts = widget.post.taggedProductIds
        .map(
          (id) => provider.allProducts.firstWhere(
            (p) => p.id == id,
            orElse: () => Product(
              id: id,
              name: 'Product $id',
              imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=400',
              description: '',
              category: 'General',
              pricePaise: 99900,
              commissionRate: 0.10,
            ),
          ),
        )
        .toList();

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Video or Placeholder/Error
          _hasError
              ? Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Playback Failure',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _isInitialized = false;
                            });
                            _initializePlayer();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _isInitialized && _controller != null
              ? _buildVideoPlayerWithFilter()
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.pinkAccent),
                  ),
                ),

          // Play/Pause Overlay indicator when paused
          if (_isInitialized &&
              _controller != null &&
              !_controller!.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 72,
                color: Colors.white70,
              ),
            ),

          // Mute Button (Top Right)
          Positioned(
            top: 50,
            right: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                ),
                onPressed: _toggleMute,
              ),
            ),
          ),

          // Promoted Badge (Top Left)
          if (widget.post.isPromoted)
            Positioned(
              top: 50,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.amber, Colors.deepOrange],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Promoted',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right Side Action Buttons (Like, Comment, Share, Creator Profile)
          Positioned(
            right: 12,
            bottom: 120,
            child: Column(
              children: [
                // Creator Avatar with Follow Button
                Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(
                        widget.post.creatorAvatarUrl,
                      ),
                    ),
                    if (currentUser?.id != widget.post.creatorId)
                      Positioned(
                        bottom: -8,
                        child: GestureDetector(
                          onTap: () {
                            provider.toggleFollow(widget.post.creatorId);
                          },
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: isFollowing
                                ? Colors.grey
                                : Colors.pinkAccent,
                            child: Icon(
                              isFollowing ? Icons.check : Icons.add,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Like Button
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.redAccent : Colors.white,
                    size: 32,
                  ),
                  onPressed: () {
                    provider.togglePostLike(widget.post.id);
                  },
                ),
                Text(
                  '${widget.post.likedUserIds.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Comment Button
                IconButton(
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () {
                    _showCommentsModal(context, provider);
                  },
                ),
                Text(
                  '${widget.post.comments.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Share Button
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 30),
                  onPressed: () {
                    provider.incrementShare(widget.post.id);
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Check out this video by ${widget.post.creatorName} on Trell! ${widget.post.caption}',
                      ),
                    );
                  },
                ),
                Text(
                  '${widget.post.sharesCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Details & Tagged Product Cards Overlay
          Positioned(
            left: 12,
            right: 80,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Creator Name & Verification Badge (Dynamic Creator Verification Lookup)
                Row(
                  children: [
                    Text(
                      '@${widget.post.creatorName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (provider
                            .getUserById(widget.post.creatorId)
                            ?.isVerifiedCreator ??
                        widget.post.isVerifiedCreator) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        color: Colors.blueAccent,
                        size: 16,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Caption & Category
                Text(
                  widget.post.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),

                // Music/Filter metadata if present
                if (widget.post.musicTitle != null ||
                    widget.post.filterName != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.music_note,
                        color: Colors.amber,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.post.musicTitle ?? "Original Sound"} ${widget.post.filterName != null ? "• ${widget.post.filterName}" : ""}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),

                // Tagged Product Quick Cards
                if (taggedProducts.isNotEmpty)
                  SizedBox(
                    height: 65,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: taggedProducts.length,
                      itemBuilder: (ctx, idx) {
                        final product = taggedProducts[idx];
                        return GestureDetector(
                          onTap: () {
                            // Record click and navigate with creator referral context
                            provider.recordProductClick(
                              widget.post.id,
                              product.id,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                  product: product,
                                  referrerCreatorId: widget.post.creatorId,
                                  referrerPostId: widget.post.id,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.pinkAccent.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    product.imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey.shade800,
                                      child: const Icon(
                                        Icons.shopping_bag,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      CurrencyUtils.formatPaise(
                                        product.pricePaise,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.pinkAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentsModal(BuildContext context, AppStateProvider provider) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final postComments = widget.post.comments;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: SizedBox(
                height: 400,
                child: Column(
                  children: [
                    Text(
                      'Comments (${postComments.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: postComments.isEmpty
                          ? const Center(
                              child: Text(
                                'No comments yet. Be the first!',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: postComments.length,
                              itemBuilder: (context, index) {
                                final c = postComments[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.pinkAccent,
                                    child: Text(
                                      c.userName.isNotEmpty
                                          ? c.userName[0]
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    c.userName,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    c.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.black26,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.pinkAccent,
                          ),
                          onPressed: () {
                            if (commentController.text.trim().isNotEmpty) {
                              provider.addComment(
                                widget.post.id,
                                commentController.text,
                              );
                              commentController.clear();
                              setModalState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
