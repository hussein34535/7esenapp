import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:hesen/utils/video_thumbnail_helper.dart';

class GoalsSection extends StatefulWidget {
  final Future<List<dynamic>> goalsArticles;
  final String? userName;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;

  const GoalsSection({
    super.key,
    required this.goalsArticles,
    required this.openVideo,
    this.userName,
  });

  @override
  State<GoalsSection> createState() => _GoalsSectionState();
}

class _GoalsSectionState extends State<GoalsSection> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: widget.goalsArticles,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          // Use CustomScrollView + SliverFillRemaining for centering + scrollability
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading goals',
                    textAlign: TextAlign.center, // Center text
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                )),
              ),
            ],
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Use CustomScrollView + SliverFillRemaining for centering + scrollability
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No goals available',
                    textAlign: TextAlign.center, // Center text
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                )),
              ),
            ],
          );
        }

        final goals = snapshot.data!;

        // Detect Windows platform
        final bool isWindows =
            defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

        if (isWindows) {
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 600, // Responsive 3-column layout
              childAspectRatio:
                  1.2, // Final balance: no 'grey space' and no overflows
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              return GoalBox(
                goal: goals[index],
                openVideo: widget.openVideo,
                loadThumbnail: index < 3, // Only load most recent 3
              );
            },
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          itemCount: goals.length,
          itemBuilder: (context, index) {
            return GoalBox(
              goal: goals[index],
              openVideo: widget.openVideo,
              loadThumbnail: index < 3, // Only load most recent 3
            );
          },
        );
      },
    );
  }
}

class GoalBox extends StatefulWidget {
  final dynamic goal;
  final Function(BuildContext, String, List<Map<String, dynamic>>, String,
      {int? contentId, bool isPremium}) openVideo;
  final bool loadThumbnail;

  const GoalBox({
    super.key,
    required this.goal,
    required this.openVideo,
    this.loadThumbnail = false,
  });

  @override
  State<GoalBox> createState() => _GoalBoxState();
}

class _GoalBoxState extends State<GoalBox> {
  bool _isHovered = false;
  bool _isPlayingInline = false;
  bool _isVideoReady = false;
  Player? _inlinePlayer;
  VideoController? _inlineController;
  double _videoAspectRatio = 16 / 9;

  @override
  void dispose() {
    _inlinePlayer?.dispose();
    _inlinePlayer = null;
    _inlineController = null;
    super.dispose();
  }

  Future<void> _startInlinePlayback(String url) async {
    if (!mounted) return;
    setState(() {
      _isPlayingInline = true;
      _isVideoReady = false;
    });

    try {
      _inlinePlayer = Player();
      _inlineController = VideoController(_inlinePlayer!);

      // Listen to video size changes for dynamic aspect ratio
      _inlinePlayer!.stream.width.listen((width) {
        if (!mounted) return;
        if (width != null && width > 0) {
          final height = _inlinePlayer!.state.height;
          if (height != null && height > 0) {
            setState(() => _videoAspectRatio = width / height);
          }
        }
      });

      _inlinePlayer!.stream.completed.listen((completed) {
        if (!mounted) return;
        if (completed) {
          setState(() => _isPlayingInline = false);
          _inlinePlayer!.seek(Duration.zero);
        }
      });

      await _inlinePlayer!.open(Media(url), play: true);
      await _inlinePlayer!.setVolume(100);

      if (mounted) {
        setState(() => _isVideoReady = true);
      }
    } catch (e) {
      debugPrint("Inline Playback Error: $e");
      if (mounted) {
        setState(() {
          _isPlayingInline = false;
          _isVideoReady = false;
        });
      }
    }
  }

  void _openFullscreenDialog() {
    if (_inlineController == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black,
      useSafeArea: false,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: MaterialVideoControlsTheme(
            normal: MaterialVideoControlsThemeData(
              bottomButtonBar: [
                const MaterialPositionIndicator(),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(
                    Icons.fullscreen_exit_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
              primaryButtonBar: const [
                MaterialPlayOrPauseButton(iconSize: 56),
              ],
              topButtonBar: const [],
              displaySeekBar: true,
              seekBarMargin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              bottomButtonBarMargin: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 8,
              ),
              seekBarThumbColor: Colors.white,
              seekBarPositionColor: Colors.red,
              seekBarBufferColor: Colors.white38,
              seekBarColor: Colors.white24,
              seekBarHeight: 4,
              seekBarThumbSize: 14,
            ),
            fullscreen: const MaterialVideoControlsThemeData(),
            child: Video(
              controller: _inlineController!,
              fill: Colors.black,
              controls: MaterialVideoControls,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.goal['title'] ?? '';
    final urlData = widget.goal['url'];
    final time = widget.goal['time'] ?? '';
    final bool isPremium = widget.goal['is_premium'] ?? false;

    // --- Image Extraction Logic ---
    final imageObj = widget.goal['image'];
    String? imageUrl;
    if (imageObj != null) {
      if (imageObj is String) {
        imageUrl = imageObj;
      } else if (imageObj is Map) {
        imageUrl = imageObj['url'];
      } else if (imageObj is List && imageObj.isNotEmpty) {
        imageUrl = imageObj[0]['url'];
      }
    }

    dynamic processedUrlData = urlData;
    if (processedUrlData is String && processedUrlData.trim().startsWith('[')) {
      try {
        processedUrlData = jsonDecode(processedUrlData);
      } catch (e) {
        debugPrint("Error decoding goal JSON: $e");
      }
    }

    List<Map<String, dynamic>> streamLinks = [];
    if (processedUrlData is String && processedUrlData.isNotEmpty) {
      streamLinks.add({'name': 'Watch', 'url': processedUrlData});
    } else if (processedUrlData is List) {
      for (var item in processedUrlData) {
        if (item is Map &&
            item['type'] == 'paragraph' &&
            item['children'] is List) {
          for (var child in item['children']) {
            if (child is Map &&
                child['type'] == 'link' &&
                child['url'] != null) {
              streamLinks.add({
                'name': child['children']?[0]['text'] ?? 'Link',
                'url': child['url'],
              });
            }
          }
        }
      }
    } else if (processedUrlData is Map && processedUrlData['url'] != null) {
      streamLinks.add({
        'name': 'Watch',
        'url': processedUrlData['url'],
      });
    }

    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.windows && !kIsWeb;

    void handleTap() {
      int? id = int.tryParse(widget.goal['id']?.toString() ?? '');
      String firstUrl = streamLinks.isNotEmpty ? streamLinks[0]['url'] : '';

      if (firstUrl.isNotEmpty) {
        if (_isPlayingInline) {
          // Stop playback and reset to show thumbnail
          _inlinePlayer?.pause();
          _inlinePlayer?.seek(Duration.zero);
          setState(() => _isPlayingInline = false);
        } else {
          _startInlinePlayback(firstUrl);
        }
      } else if (streamLinks.isNotEmpty || isPremium) {
        widget.openVideo(context, firstUrl, streamLinks, 'goals',
            contentId: id, isPremium: isPremium);
      }
    }

    return MouseRegion(
      onEnter: (_) => isDesktop ? setState(() => _isHovered = true) : null,
      onExit: (_) => isDesktop ? setState(() => _isHovered = false) : null,
      child: GestureDetector(
        // Only allow tap when NOT playing (Issue 5)
        onTap: _isPlayingInline ? null : handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // Issue 1: Remove fixed height, let content determine size
          // Issue 2: Remove horizontal margin for full width
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          transform: _isHovered
              ? Matrix4.diagonal3Values(1.02, 1.02, 1.0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
              if (_isHovered)
                BoxShadow(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Video Preview Area ---
              // Issue 1: Use AspectRatio for dynamic height
              AspectRatio(
                aspectRatio: _videoAspectRatio,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(25)),
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        child: Stack(
                          children: [
                            if (_inlineController != null && _isVideoReady)
                              Positioned.fill(
                                child: MaterialVideoControlsTheme(
                                  normal: MaterialVideoControlsThemeData(
                                    // Show position and custom fullscreen button (no rotation)
                                    bottomButtonBar: [
                                      const MaterialPositionIndicator(
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      Builder(
                                        builder: (ctx) => IconButton(
                                          iconSize: 28, // Increased size
                                          onPressed: _openFullscreenDialog,
                                          icon: const Icon(
                                            Icons.fullscreen_rounded,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                    // Only play/pause in center, no skip buttons
                                    primaryButtonBar: const [
                                      MaterialPlayOrPauseButton(iconSize: 48),
                                    ],
                                    // Remove top bar completely
                                    topButtonBar: const [],
                                    displaySeekBar: true,
                                    automaticallyImplySkipNextButton: false,
                                    automaticallyImplySkipPreviousButton: false,
                                    // Position controls properly
                                    seekBarMargin: const EdgeInsets.only(
                                      left: 12,
                                      right: 12,
                                      bottom: 4,
                                    ),
                                    // Raise button bar slightly above seek bar
                                    bottomButtonBarMargin:
                                        const EdgeInsets.only(
                                      left: 12,
                                      right: 12,
                                      bottom: 12,
                                    ),
                                    buttonBarHeight: 36,
                                    padding: EdgeInsets.zero,
                                    // Seek bar styling
                                    seekBarThumbColor: Colors.white,
                                    seekBarPositionColor: Colors.red,
                                    seekBarBufferColor: Colors.white38,
                                    seekBarColor: Colors.white24,
                                    seekBarHeight: 3,
                                    seekBarThumbSize: 10,
                                  ),
                                  // Not used - we use custom dialog for fullscreen
                                  fullscreen:
                                      const MaterialVideoControlsThemeData(),
                                  child: Video(
                                    controller: _inlineController!,
                                    fill: Colors.black,
                                    // Show controls only when playing
                                    controls: _isPlayingInline
                                        ? MaterialVideoControls
                                        : NoVideoControls,
                                  ),
                                ),
                              )
                            else
                              Positioned.fill(
                                child: Hero(
                                  tag: 'goal_img_${widget.goal['id']}',
                                  // Issue 1: Use BoxFit.cover and Positioned.fill to ensure alignment
                                  child: Builder(builder: (context) {
                                    if (imageUrl != null &&
                                        imageUrl.isNotEmpty) {
                                      return CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        alignment: Alignment.center,
                                        placeholder: (context, url) =>
                                            Container(
                                          color: Colors.black87,
                                          child: const Center(
                                              child:
                                                  CircularProgressIndicator()),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.error),
                                      );
                                    } else if (streamLinks.isNotEmpty &&
                                        widget.loadThumbnail) {
                                      return VideoThumbnail(
                                          url: streamLinks[0]['url']);
                                    } else {
                                      return Container(
                                        color: Colors.black26,
                                        child: const Icon(
                                            Icons.play_circle_outline,
                                            color: Colors.white24,
                                            size: 50),
                                      );
                                    }
                                  }),
                                ),
                              ),
                            // Loading Indicator when player is starting but video isn't ready yet
                            if (_isPlayingInline && !_isVideoReady)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black45,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Play Button Overlay - Simple & Clean
                    if (!_isPlayingInline)
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),

                    // Premium Badge
                    if (isPremium)
                      Positioned(
                        top: 15,
                        right: 15,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4)
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.diamond,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('مميز',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // --- Title and Time Area --- (Issue 3: Removed "عرض الفيديو")
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              time,
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        // Issue 3: Removed "عرض الفيديو" text
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoThumbnail extends StatefulWidget {
  final String url;
  const VideoThumbnail({super.key, required this.url});

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  Uint8List? _thumbnail;
  bool _isLoading = false;

  // Static queue to limit concurrent extractions (improves performance)
  static final List<_VideoThumbnailState> _queue = [];
  static bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _thumbnail = ThumbnailCache.get(widget.url);
    if (_thumbnail == null && widget.url.isNotEmpty) {
      _enqueueExtraction();
    }
  }

  void _enqueueExtraction() {
    if (!_queue.contains(this)) {
      _queue.add(this);
    }
    if (!_isProcessing) {
      _startQueueProcessing();
    }
  }

  static void _startQueueProcessing() {
    if (_isProcessing) return;
    _isProcessing = true;
    // Reduced initial delay to 1 second as promised
    // Snappier feel while still preventing peak load.
    Future.delayed(const Duration(seconds: 1), () {
      _processNextInQueue();
    });
  }

  static Future<void> _processNextInQueue() async {
    if (_queue.isEmpty) {
      _isProcessing = false;
      return;
    }

    final state = _queue.removeAt(0);
    if (state.mounted && state._thumbnail == null) {
      await state._extractThumbnail();
      // Delay between extractions for smoothness
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    // Process next item
    _processNextInQueue();
  }

  Future<void> _extractThumbnail() async {
    if (kIsWeb) return;

    if (!mounted || _isLoading || widget.url.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final uri = Uri.tryParse(widget.url);
      if (uri == null || !uri.hasScheme) {
        setState(() => _isLoading = false);
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        final Uint8List? thumbnail =
            await VideoThumbnailHelper.getThumbnail(widget.url);

        if (thumbnail != null && thumbnail.isNotEmpty) {
          ThumbnailCache.set(widget.url, thumbnail);
          if (mounted) {
            setState(() {
              _thumbnail = thumbnail;
              _isLoading = false;
            });
          }
          return;
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        Player? player;
        try {
          player = Player();
          await player.setVolume(0);
          await player.open(Media(widget.url), play: true);
          await Future.delayed(const Duration(seconds: 2));

          if (!mounted) {
            await player.dispose();
            return;
          }

          final screenshot = await player.screenshot();
          if (screenshot != null && screenshot.isNotEmpty) {
            ThumbnailCache.set(widget.url, screenshot);
            if (mounted) {
              setState(() {
                _thumbnail = screenshot;
                _isLoading = false;
              });
            }
            return;
          }
        } finally {
          await player?.dispose();
        }
      }
    } catch (e) {
      debugPrint("Thumbnail Extraction Error: $e");
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnail != null) {
      return Image.memory(
        _thumbnail!,
        fit: BoxFit.cover,
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: _isLoading
            ? const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white24,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class ThumbnailCache {
  static final Map<String, Uint8List> _cache = {};
  static Uint8List? get(String url) => _cache[url];
  static void set(String url, Uint8List data) => _cache[url] = data;
}
