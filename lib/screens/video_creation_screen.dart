import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/app_state_provider.dart';
import '../models/post.dart';
import '../models/product.dart';

class VideoCreationScreen extends StatefulWidget {
  const VideoCreationScreen({super.key});

  @override
  State<VideoCreationScreen> createState() => _VideoCreationScreenState();
}

class _VideoCreationScreenState extends State<VideoCreationScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedMedia;
  VideoPlayerController? _previewController;

  final TextEditingController _captionController = TextEditingController();
  String _selectedCategory = 'Fashion';
  final List<String> _categories = ['Fashion', 'Beauty', 'Travel', 'Food', 'DIY'];

  // Editing state options
  String _selectedFilter = 'None';
  final List<String> _filters = ['None', 'Vintage Warm', 'Soft Glow', 'Vibrant Summer', 'B&W Mono'];

  String _selectedMusic = 'None';
  final List<String> _musicOptions = [
    'None',
    'Lo-Fi Chill Beats',
    'Upbeat Pop Vibes',
    'Acoustic Travel',
    'Bossa Nova Cafe'
  ];
  double _musicVolume = 0.5;

  double _trimStart = 0.0;
  double _trimEnd = 1.0;

  final List<String> _selectedProductIds = [];
  bool _isExporting = false;
  double _exportProgress = 0.0;

  @override
  void dispose() {
    _previewController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
      if (file != null) {
        _selectedMedia = file;
        _initPreviewController(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Media pick failed or denied permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _useSampleDemoVideo(String assetPath) {
    setState(() {
      _selectedMedia = XFile(assetPath);
      _initPreviewController(assetPath, isAsset: true);
    });
  }

  Future<void> _initPreviewController(String path, {bool isAsset = false}) async {
    _previewController?.dispose();
    if (isAsset || path.startsWith('assets/')) {
      _previewController = VideoPlayerController.asset(path);
    } else {
      _previewController = VideoPlayerController.file(File(path));
    }
    await _previewController!.initialize();
    _previewController!.setLooping(true);
    _previewController!.play();
    setState(() {});
  }

  Future<void> _exportAndPublishVideo(AppStateProvider provider) async {
    if (_selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or record a video first.')),
      );
      return;
    }
    if (_captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a caption.')),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) {
        setState(() {
          _exportProgress = i / 10.0;
        });
      }
    }

    final user = provider.currentUser;
    if (user == null) return;

    // Save video into durable app storage
    String durablePath = _selectedMedia!.path;
    try {
      if (!durablePath.startsWith('assets/')) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileExt = durablePath.contains('.') ? durablePath.split('.').last : 'mp4';
        final destPath = '${appDir.path}/trell_export_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final sourceFile = File(durablePath);
        if (await sourceFile.exists()) {
          await sourceFile.copy(destPath);
          durablePath = destPath;
        }
      }
    } catch (e) {
      // Fallback to original path if copy fails
    }

    double totalDuration = _previewController?.value.duration.inMilliseconds.toDouble() ?? 10000;
    double startSeconds = (_trimStart * totalDuration) / 1000.0;
    double endSeconds = (_trimEnd * totalDuration) / 1000.0;

    final newPost = Post(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      creatorId: user.id,
      creatorName: user.name,
      creatorAvatarUrl: user.avatarUrl,
      isVerifiedCreator: user.isVerifiedCreator,
      videoPath: durablePath,
      caption: _captionController.text.trim(),
      category: _selectedCategory,
      taggedProductIds: List<String>.from(_selectedProductIds),
      filterName: _selectedFilter != 'None' ? _selectedFilter : null,
      musicTitle: _selectedMusic != 'None' ? _selectedMusic : null,
      musicVolume: _selectedMusic != 'None' ? _musicVolume : null,
      trimStartSeconds: startSeconds,
      trimEndSeconds: endSeconds,
      createdAt: DateTime.now(),
    );

    await provider.addPost(newPost);

    if (mounted) {
      setState(() {
        _isExporting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Video exported & published to Trell Community!'),
          backgroundColor: Colors.green,
        ),
      );
      // Reset form safely
      setState(() {
        _selectedMedia = null;
        _previewController?.dispose();
        _previewController = null;
        _captionController.clear();
        _selectedProductIds.clear();
        _selectedFilter = 'None';
        _selectedMusic = 'None';
        _trimStart = 0.0;
        _trimEnd = 1.0;
      });
    }
  }

  Widget _buildPreviewVideoWithFilter() {
    Widget playerWidget = AspectRatio(
      aspectRatio: _previewController!.value.aspectRatio,
      child: VideoPlayer(_previewController!),
    );

    if (_selectedFilter == 'B&W Mono') {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: playerWidget,
      );
    } else if (_selectedFilter == 'Vintage Warm') {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.amber.withValues(alpha: 0.25), BlendMode.colorBurn),
        child: playerWidget,
      );
    } else if (_selectedFilter == 'Soft Glow') {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.pink.withValues(alpha: 0.20), BlendMode.colorBurn),
        child: playerWidget,
      );
    } else if (_selectedFilter == 'Vibrant Summer') {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.orange.withValues(alpha: 0.20), BlendMode.colorBurn),
        child: playerWidget,
      );
    }
    return playerWidget;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final products = provider.allProducts;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Create & Edit Short Video', style: TextStyle(color: Colors.white)),
        actions: [
          if (_selectedMedia != null)
            TextButton.icon(
              onPressed: _isExporting ? null : () => _exportAndPublishVideo(provider),
              icon: const Icon(Icons.send, color: Colors.pinkAccent),
              label: const Text('Publish', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Selection Section
            if (_selectedMedia == null) ...[
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.video_call, size: 54, color: Colors.pinkAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'Select Video for Community Post',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                          onPressed: () => _pickVideo(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, color: Colors.white),
                          label: const Text('Gallery', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                          onPressed: () => _pickVideo(ImageSource.camera),
                          icon: const Icon(Icons.videocam, color: Colors.white),
                          label: const Text('Camera', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('OR use bundled demo asset:', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('Fashion MP4', style: TextStyle(fontSize: 11)),
                          onPressed: () => _useSampleDemoVideo('assets/videos/fashion_trend.mp4'),
                        ),
                        ActionChip(
                          label: const Text('Beauty MP4', style: TextStyle(fontSize: 11)),
                          onPressed: () => _useSampleDemoVideo('assets/videos/beauty_routine.mp4'),
                        ),
                        ActionChip(
                          label: const Text('Travel MP4', style: TextStyle(fontSize: 11)),
                          onPressed: () => _useSampleDemoVideo('assets/videos/travel_vlog.mp4'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Video Preview & Filter Effect Container
              Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.pinkAccent),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _previewController != null && _previewController!.value.isInitialized
                          ? _buildPreviewVideoWithFilter()
                          : const CircularProgressIndicator(color: Colors.pinkAccent),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _selectedMedia = null;
                                _previewController?.dispose();
                                _previewController = null;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Export Progress Bar
              if (_isExporting) ...[
                LinearProgressIndicator(value: _exportProgress, color: Colors.pinkAccent),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Rendering & Exporting Video... ${(_exportProgress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Editor Controls Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Video Editor & Effects', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // Trim Slider
                    const Text('Trim Video Start / End:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    RangeSlider(
                      values: RangeValues(_trimStart, _trimEnd),
                      activeColor: Colors.pinkAccent,
                      onChanged: (RangeValues vals) {
                        setState(() {
                          _trimStart = vals.start;
                          _trimEnd = vals.end;
                        });
                      },
                    ),

                    // Filter Selection
                    Row(
                      children: [
                        const Text('Visual Filter: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedFilter,
                          dropdownColor: Colors.grey.shade900,
                          style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                          items: _filters.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedFilter = val);
                          },
                        ),
                      ],
                    ),

                    // Royalty Free Music Selection
                    Row(
                      children: [
                        const Text('Background Music: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _selectedMusic,
                          dropdownColor: Colors.grey.shade900,
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                          items: _musicOptions.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMusic = val);
                          },
                        ),
                      ],
                    ),
                    if (_selectedMusic != 'None')
                      Row(
                        children: [
                          const Icon(Icons.volume_up, color: Colors.white70, size: 18),
                          Expanded(
                            child: Slider(
                              value: _musicVolume,
                              activeColor: Colors.amber,
                              onChanged: (v) => setState(() => _musicVolume = v),
                            ),
                          ),
                          Text('${(_musicVolume * 100).toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Caption & Category
              TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Caption & Hashtags',
                  labelStyle: TextStyle(color: Colors.white70),
                  hintText: 'Share details about your lifestyle recommendation...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Category: ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: Colors.grey.shade900,
                    style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 15),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tag Products Section (Requirement #5)
              const Text('Tag Products (Earn Commission on Sales)', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (ctx, idx) {
                    final product = products[idx];
                    final isTagged = _selectedProductIds.contains(product.id);
                    return CheckboxListTile(
                      activeColor: Colors.pinkAccent,
                      title: Text(product.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: Text(
                        '${product.category} • Price: ₹${(product.pricePaise / 100).toInt()} • Rate: ${(product.commissionRate * 100).toInt()}% • Est: ₹${((product.pricePaise * product.commissionRate) / 100.0).toStringAsFixed(2)} / sale',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      value: isTagged,
                      onChanged: (bool? val) {
                        setState(() {
                          if (val == true) {
                            _selectedProductIds.add(product.id);
                          } else {
                            _selectedProductIds.remove(product.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                  onPressed: _isExporting ? null : () => _exportAndPublishVideo(provider),
                  icon: const Icon(Icons.cloud_upload, color: Colors.white),
                  label: const Text('Publish to Trell Community', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
