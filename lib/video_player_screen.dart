import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';

enum VideoSize {
  small,
  medium,
  large,
  fullScreen,
}

class VideoPlayerScreen extends StatefulWidget {
  final String initialUrl;
  final List<Map<String, dynamic>> streamLinks;
  final Color progressBarColor;
  final Color progressBarBufferedColor;

  const VideoPlayerScreen({
    super.key,
    required this.initialUrl,
    required this.streamLinks,
    this.progressBarColor = Colors.red,
    this.progressBarBufferedColor = Colors.grey,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isControlsVisible = true;
  String? _currentUrl = ""; // Nullable String
  bool _isLive = false;
  int _selectedQualityIndex = 0;
  int _currentAspectRatioIndex = 0; // Track aspect ratio index
  Map<String, int> _cachedAspectRatioIndices = {};
  bool _wasPlaying = false;

  Timer? _hideControlsTimer;

  final List<double> aspectRatios = [16 / 9, 4 / 3, 18 / 9, 21 / 9];

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _selectedQualityIndex =
        widget.streamLinks.indexWhere((link) => link['url'] == _currentUrl);
    if (_selectedQualityIndex == -1) {
      _selectedQualityIndex = 0;
    }
    _initializePlayer(_currentUrl!);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacityAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);

    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startHideControlsTimer();
    _checkIfLive();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only re-initialize if the initial URL *actually* changes.
    if (widget.initialUrl != oldWidget.initialUrl) {
      print("didUpdateWidget: URL changed, re-initializing.");
      _changeStream(widget.initialUrl, 0);
    } else {
      print("didUpdateWidget: URL did not change.");
    }
  }

  @override
  void dispose() {
    print("dispose START");
    _hideControlsTimer?.cancel(); // Cancel timer FIRST
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _videoPlayerController?.pause(); // Pause video before dispose
    _videoPlayerController?.dispose();
    _chewieController?.pause(); // Pause Chewie too
    _chewieController?.dispose();
    _animationController.dispose();
    WakelockPlus.disable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
    print("dispose END");
    super.dispose();
  }

  void _checkIfLive() {
    _isLive = widget.streamLinks.any((link) =>
        link['url'] == _currentUrl &&
        link.containsKey('isLive') &&
        link['isLive'] == true);
  }

  Future<void> _initializePlayer(String url,
      {bool initializeAspectRatio = false}) async {
    if (!mounted) return;
    print("_initializePlayer: START - url: $url");

    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    // VERY IMPORTANT: Dispose of controllers *synchronously* at the start.
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();

    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoPlayerController!.addListener(_videoPlayerListener);

    try {
      await _videoPlayerController!.initialize();
      if (initializeAspectRatio) {
        final aspectRatio = _videoPlayerController!.value.aspectRatio;
        _currentAspectRatioIndex = _findClosestAspectRatioIndex(aspectRatio);
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: aspectRatios[_currentAspectRatioIndex],
        showControls: false,
        showOptions: false,
        errorBuilder: (context, errorMessage) =>
            _buildErrorWidget(errorMessage),
        autoInitialize: true,
      );
      _videoPlayerController!
          .addListener(_videoPlayerListener); // Listener AFTER Chewie

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("_initializePlayer: ERROR - $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
    print("_initializePlayer: END");
  }

  int _findClosestAspectRatioIndex(double aspectRatio) {
    double minDiff = double.infinity;
    int closestIndex = 0;
    for (int i = 0; i < aspectRatios.length; i++) {
      final diff = (aspectRatios[i] - aspectRatio).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  void _videoPlayerListener() {
    if (!mounted || _videoPlayerController == null) return;

    if (_videoPlayerController!.value.hasError) {
      setState(() {
        _hasError = true;
      });
    } else if (_videoPlayerController!.value.isBuffering != _isLoading) {
      setState(() {
        _isLoading = _videoPlayerController!.value.isBuffering;
      });
    }
  }

  void _changeStream(String url, int index) async {
    _currentAspectRatioIndex = 0;
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();

    _initializePlayer(url);
    _checkIfLive();
    _startHideControlsTimer();

    if (mounted) {
      setState(() {
        _selectedQualityIndex = index;
        _currentUrl = url;
      });
    }
  }

  void _startHideControlsTimer() {
    _setControlsVisibility(true);
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      _hideControls(animate: true);
    });
  }

  void _setControlsVisibility(bool visible) {
    if (mounted) {
      setState(() {
        _isControlsVisible = visible;
        if (visible) {
          _animationController.reverse();
        } else {
          _animationController.forward();
        }
      });
    }
  }

  void _hideControls({bool animate = true}) {
    if (animate) {
      _setControlsVisibility(false);
    } else {
      if (mounted) {
        setState(() {
          _isControlsVisible = false;
        });
      }
      _animationController.forward(); // Ensure opacity is 0
    }
  }

  void _onTap() {
    if (_isControlsVisible) {
      _hideControls(animate: true);
    } else {
      _startHideControlsTimer();
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildStreamSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(25),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: widget.streamLinks.asMap().entries.map<Widget>((entry) {
            final index = entry.key;
            final link = entry.value;
            final streamName = link['name'] ?? 'Unknown';
            final streamUrl = link['url'];
            final isActive = index == _selectedQualityIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                onTap: () {
                  if (streamUrl != null && streamUrl.isNotEmpty) {
                    _changeStream(streamUrl, index);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isActive
                        ? widget.progressBarColor
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: isActive
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Text(
                    streamName,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white70,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _initializePlayer(_currentUrl!),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white70,
              foregroundColor: Colors.black,
            ),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildAspectRatioButton() {
    return InkWell(
      onTap: () {
        if (!mounted) return;

        final wasPlaying = _videoPlayerController?.value.isPlaying ?? false;

        setState(() {
          _currentAspectRatioIndex =
              (_currentAspectRatioIndex + 1) % aspectRatios.length;
        });

        _chewieController?.dispose();
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: wasPlaying, // Use stored playing state
          looping: false,
          aspectRatio: aspectRatios[_currentAspectRatioIndex],
          showControls: false,
          showOptions: false,
          errorBuilder: (context, errorMessage) =>
              _buildErrorWidget(errorMessage),
          autoInitialize: true,
        );
        _startHideControlsTimer();
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset(
          'assets/maximize.png',
          width: 24,
          height: 24,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final video = _videoPlayerController;
    final isPlaying = video?.value.isPlaying ?? false;

    return FadeTransition(
      opacity: _opacityAnimation,
      child: IgnorePointer(
        ignoring: !_isControlsVisible,
        child: Stack(
          children: [
            // Background tint
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
            //Top Controls (Stream Selector)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: Center(child: _buildStreamSelector()),
            ),
            // Center Play/Pause Button
            Center(
              child: IconButton(
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 64,
                ),
                onPressed: () {
                  if (isPlaying) {
                    video?.pause();
                  } else {
                    video?.play();
                  }
                  _startHideControlsTimer();
                },
              ),
            ),

            // Bottom Controls (Seek Bar, Time, Rewind/Forward)
            _buildBottomControls(context), // <-- Extracted bottom controls
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    final video = _videoPlayerController;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              // Rewind Button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () {
                  final currentPosition =
                      _videoPlayerController?.value.position;
                  if (currentPosition != null) {
                    _videoPlayerController!
                        .seekTo(currentPosition - const Duration(seconds: 10));
                  }
                  _startHideControlsTimer();
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (mounted) {
                      setState(() {
                        _videoPlayerController!.value.isPlaying
                            ? _videoPlayerController!.pause()
                            : _videoPlayerController!.play();
                      });
                    }
                    _startHideControlsTimer(); // Restart timer on interaction
                  },
                  child: _isLive
                      ? const Center(
                          child: Text("LIVE",
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        )
                      : VideoProgressIndicator(
                          _videoPlayerController!,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: widget.progressBarColor,
                            bufferedColor: widget.progressBarBufferedColor,
                            backgroundColor: Colors.white30,
                          ),
                        ),
                ),
              ),
              // Forward Button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () {
                  final currentPosition =
                      _videoPlayerController?.value.position;
                  if (currentPosition != null) {
                    _videoPlayerController!
                        .seekTo(currentPosition + const Duration(seconds: 10));
                  }
                  _startHideControlsTimer();
                },
              ),
              _buildAspectRatioButton(),
            ]),
            if (!_isLive)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 46),
                    child: Text(
                      _formatDuration(_videoPlayerController?.value.position),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 46),
                    child: Text(
                      _formatDuration(_videoPlayerController?.value.duration),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    if (_hasError) {
      return _buildErrorWidget('Error loading video');
    }
    if (_chewieController == null) {
      // ADDED NULL CHECK HERE
      print(
          "_buildVideoPlayer: _chewieController is NULL, returning SizedBox.shrink()");
      return const SizedBox.shrink(); // Or a placeholder
    }

    return Chewie(
        key: ValueKey(_currentAspectRatioIndex),
        controller: _chewieController!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        child: Stack(
          fit: StackFit.expand, // Expand only in full screen
          alignment: Alignment.center,
          children: [
            _buildVideoPlayer(),
            _buildControls(context),
          ],
        ),
      ),
    );
  }
}
