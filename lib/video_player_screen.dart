import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:android_pip/android_pip.dart';

enum VideoSize {
  fullScreen, // Use device's full screen size
  ratio16_9, // 16:9 aspect ratio
  ratio18_9, // 18:9 aspect ratio (Wider)
  ratio4_3, // 4:3 aspect ratio
  ratio1_1, // 1:1 aspect ratio
}

class VideoPlayerScreen extends StatefulWidget {
  final String initialUrl;
  final List<Map<String, dynamic>> streamLinks;
  final Color progressBarColor;
  final Color progressBarBufferedColor;
  final Duration controlsHideDelay;
  final Duration playbackTimeoutDuration;
  final int maxRetries;
  final Duration streamSwitchDelay;
  // final InterstitialAd? interstitialAd; // Removed - Ad shown before navigation

  const VideoPlayerScreen({
    super.key,
    required this.initialUrl,
    required this.streamLinks,
    this.progressBarColor = Colors.red,
    this.progressBarBufferedColor = Colors.grey,
    this.controlsHideDelay = const Duration(seconds: 5),
    this.playbackTimeoutDuration = const Duration(seconds: 10),
    this.maxRetries = 5,
    this.streamSwitchDelay = const Duration(seconds: 3),
    // this.interstitialAd, // Removed
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
  String? _currentUrl = "";
  int _selectedQualityIndex = 0;
  bool _isTryingNextStream = false;
  VideoSize _currentVideoSize = VideoSize.ratio16_9; // Start with 16:9
  double? _initialAspectRatio; // Store initial aspect ratio

  Timer? _hideControlsTimer;
  Timer? _playbackTimeoutTimer;
  Timer? _bufferingTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Add instance for android_pip
  final AndroidPIP _androidPIP = AndroidPIP();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacityAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);

    if (widget.streamLinks.isNotEmpty) {
      _currentUrl = widget.streamLinks[0]['url'];
      _selectedQualityIndex = 0;
    } else {
      _currentUrl = widget.initialUrl;
      _selectedQualityIndex = _findInitialStreamIndex();
    }

    _enableFullscreenMode();
    _startHideControlsTimer();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);

    // Initialize player directly now
    _initializePlayerInternal(_currentUrl!);
  }

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != oldWidget.initialUrl ||
        widget.streamLinks != oldWidget.streamLinks) {
      // print("didUpdateWidget: URLs or stream links changed, re-initializing.");
      _cancelAllTimers();
      if (widget.streamLinks.isNotEmpty) {
        _currentUrl = widget.streamLinks[0]['url'];
        _selectedQualityIndex = 0;
      } else {
        _currentUrl = widget.initialUrl;
        _selectedQualityIndex = _findInitialStreamIndex();
      }
      _releaseControllers().then((_) {
        if (mounted) {
          _initializePlayerInternal(_currentUrl!);
        }
      });
    }
  }

  @override
  dispose() {
    // print("dispose: Disposing VideoPlayerScreenState");
    _cancelAllTimers();
    _connectivitySubscription?.cancel();
    _animationController.dispose();
    // Ensure controllers are released *before* super.dispose()
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    // Disable fullscreen and wakelock, allow all orientations
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(
        DeviceOrientation.values); // Allow all
    super.dispose();
  }

  // --- Ad Handling Removed ---

  // --- Player Initialization and Control ---

  Future<void> _initializePlayerInternal(String url) async {
    if (!mounted) return; // Add mounted check at the start
    // print("_initializePlayerInternal: START for url: $url");

    // Ensure loading state is set
    if (!_isLoading) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      } else {
        return; // Don't proceed if not mounted
      }
    }

    // Dispose previous controllers *before* creating new ones
    await _releaseControllers();
    if (!mounted) return; // Check again after potential disposal delay

    // Create new VideoPlayerController
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: {
          'Accept':
              'application/vnd.apple.mpegurl,application/x-mpegurl,video/mp4,application/mp4,video/MP2T,*/*',
          'User-Agent':
              'MyFlutterApp/1.0', // Consider making this more specific if needed
        },
      );

      _videoPlayerController!.addListener(_videoPlayerListener);
      await _videoPlayerController!.initialize();

      if (!mounted) {
        // Check again after await
        _videoPlayerController?.dispose();
        return;
      }

      _initialAspectRatio = _videoPlayerController!.value.aspectRatio;

      // Create new Chewie controller *after* VideoPlayerController is initialized
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _getAspectRatioForSize(_currentVideoSize),
        showControls: false, // Controls are handled by the custom overlay
        showOptions: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: widget.progressBarColor,
          // handleColor: widget.progressBarColor, // Removed invalid parameter
          bufferedColor: widget.progressBarBufferedColor,
          backgroundColor: Colors.white30,
        ),
        cupertinoProgressColors: ChewieProgressColors(
          // Match Material for consistency
          playedColor: widget.progressBarColor,
          // handleColor: widget.progressBarColor, // Removed invalid parameter
          bufferedColor: widget.progressBarBufferedColor,
          backgroundColor: Colors.white30,
        ),
        errorBuilder: (context, errorMessage) =>
            _buildErrorWidget(errorMessage),
        // autoInitialize: true, // Already initialized VideoPlayerController
      );

      _startPlaybackTimeoutTimer();
      _startBufferingTimer();

      if (mounted) {
        setState(() {
          _isLoading = false; // Update loading state
          _hasError = false; // Reset error state on successful init
        });
      }
      // print("_initializePlayerInternal: SUCCESS for url: $url");
    } catch (e) {
      // print("Error initializing player internal: $e for url: $url");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        _tryNextStream(); // Attempt next stream if init fails
      } else {
        // If not mounted, ensure the controller is disposed
        _videoPlayerController?.dispose();
      }
    }
  }

  Future<void> _releaseControllers() async {
    // print("_releaseControllers: Releasing controllers");
    final vpController = _videoPlayerController;
    final chController = _chewieController;

    _videoPlayerController = null;
    _chewieController = null;

    vpController?.removeListener(_videoPlayerListener);
    // dispose is synchronous, no need for await
    vpController?.dispose();
    try {
      chController?.dispose();
    } catch (e) {
      // print(
      //     "Error disposing ChewieController (might be expected if already disposed): $e");
    }
  }

  void _videoPlayerListener() {
    // Add mounted check at the very beginning
    if (!mounted ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) return;

    if (_videoPlayerController!.value.isPlaying) {
      _playbackTimeoutTimer?.cancel();
      _bufferingTimer?.cancel();
      _isTryingNextStream = false; // Reset retry flag when playing starts
    }

    // Check mounted again before accessing error state
    if (!mounted ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) return;
    if (_videoPlayerController!.value.hasError) {
      if (mounted && !_isTryingNextStream) {
        // print("VideoPlayerListener: Error detected, trying next stream.");
        setState(() {
          _isLoading = false;
        }); // Ensure loading indicator is off
        _tryNextStream();
      }
      return;
    }

    // Check mounted again before accessing buffering state
    if (!mounted ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) return;
    // Update loading state based on buffering, only if it changed
    final isBuffering = _videoPlayerController!.value.isBuffering;
    if (isBuffering != _isLoading && !_hasError) {
      // Don't show loading if error occurred
      if (mounted) {
        setState(() {
          _isLoading = isBuffering;
        });
      }
    }
  }

  // --- Stream Handling ---

  Future<void> _changeStream(String url, int index) async {
    // print("--- _changeStream START ---");
    // print("Attempting to change to: URL: $url, Index: $index");
    if (!mounted) {
      // print("_changeStream: Aborting - not mounted.");
      // print("--- _changeStream END (Aborted - Not Mounted) ---");
      return;
    }

    // Cancel timers and stop automatic retries immediately
    _playbackTimeoutTimer?.cancel();
    _bufferingTimer?.cancel();
    _isTryingNextStream = false;

    setState(() {
      _isLoading = true;
      _hasError = false; // Reset error state on user-initiated change
      _currentUrl = url; // Update current URL immediately
      _selectedQualityIndex = index;
      // print(
      //     "_changeStream: State updated - isLoading=true, index=$index, url=$url");
    });

    // Add a small delay before initialization
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) {
      // print("_changeStream: Aborting - not mounted after delay.");
      // print("--- _changeStream END (Aborted Post-Delay) ---");
      return; // Check again if mounted after delay
    }

    await _initializePlayerInternal(url);
    // print("--- _changeStream END (Finished Initialization Attempt) ---");
  }

  Future<void> _tryNextStream() async {
    if (!mounted || _isTryingNextStream) {
      if (_isTryingNextStream)
        // print("_tryNextStream: Already trying next stream, exiting");
        return;
    }
    _isTryingNextStream = true; // Set flag immediately

    // print(
    //     "_tryNextStream: Attempting to find next stream. Current index: $_selectedQualityIndex");
    final nextIndex = _findNextViableStreamIndex();

    if (nextIndex != -1) {
      // Found a different stream to try
      final nextUrl = widget.streamLinks[nextIndex]['url'];
      if (nextUrl != null && nextUrl.isNotEmpty) {
        // print(
        //     "_tryNextStream: Changing stream to index: $nextIndex, URL: $nextUrl after delay");
        await Future.delayed(widget.streamSwitchDelay);
        if (!mounted) {
          _isTryingNextStream = false; // Reset flag if unmounted during delay
          return;
        }
        await _changeStream(nextUrl, nextIndex); // Await the change
        // Reset flag *after* attempting the change, regardless of success/failure handled within _changeStream
        _isTryingNextStream = false;
      } else {
        // print(
        //     "_tryNextStream: Next stream URL is empty or null at index: $nextIndex");
        _handleNoMoreStreams(); // This sets error state
        _isTryingNextStream = false; // Corrected variable name
      }
    } else {
      // print("_tryNextStream: No other viable stream found after full loop.");
      _handleNoMoreStreams(); // This sets error state
      _isTryingNextStream = false; // Corrected variable name
    }
  }

  int _findNextViableStreamIndex() {
    // print(
    //     "_findNextViableStreamIndex: Searching from index: $_selectedQualityIndex");
    final int totalStreams = widget.streamLinks.length;
    if (totalStreams <= 1) return -1; // No other streams to try

    // 1. Search forward (excluding current index)
    for (int i = _selectedQualityIndex + 1; i < totalStreams; i++) {
      if (widget.streamLinks[i]['url'] != null &&
          widget.streamLinks[i]['url'].isNotEmpty) {
        // print(
        //     "_findNextViableStreamIndex: Found forward, index: $i, URL: ${widget.streamLinks[i]['url']}");
        return i;
      }
    }

    // 2. Search backward from the beginning (excluding current index)
    for (int i = 0; i < _selectedQualityIndex; i++) {
      if (widget.streamLinks[i]['url'] != null &&
          widget.streamLinks[i]['url'].isNotEmpty) {
        // print(
        //     "_findNextViableStreamIndex: Found looping back, index: $i, URL: ${widget.streamLinks[i]['url']}");
        return i;
      }
    }

    // print(
    //     "_findNextViableStreamIndex: No other viable stream found after full loop.");
    return -1; // No other viable stream found
  }

  void _handleNoMoreStreams() {
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      _showError("No other streams available.");
    }
  }

  // --- UI and Controls ---

  void _startHideControlsTimer() {
    _setControlsVisibility(true);
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(widget.controlsHideDelay, () {
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
      _animationController.forward();
    } else {
      _animationController.value = 1.0; // Hide immediately
    }
    if (mounted) {
      setState(() {
        _isControlsVisible = false;
      });
    }
  }

  void _onTap() {
    if (_isControlsVisible) {
      _hideControls();
    } else {
      _startHideControlsTimer();
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');

    if (duration.inHours > 0) {
      String twoDigitHours = twoDigits(duration.inHours);
      String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
      String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
      return "$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
      String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
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
            final streamName = link['name'] ?? 'Stream ${index + 1}';
            final streamUrl = link['url'];
            final isActive = index == _selectedQualityIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                onTap: () {
                  if (streamUrl != null && streamUrl.isNotEmpty && !isActive) {
                    // Prevent changing to the same stream
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
      child: SizedBox(
        width: 300,
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
              onPressed: () {
                if (mounted && _currentUrl != null) {
                  _initializePlayerInternal(
                      _currentUrl!); // Retry the current URL
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white70,
                foregroundColor: Colors.black,
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAspectRatioButton() {
    return InkWell(
      onTap: () {
        if (!mounted) return;

        final wasPlaying = _videoPlayerController?.value.isPlaying ?? false;

        setState(() {
          // Cycle through the available VideoSize options, updated order.
          switch (_currentVideoSize) {
            case VideoSize.fullScreen:
              _currentVideoSize = VideoSize.ratio16_9;
              break;
            case VideoSize.ratio16_9:
              _currentVideoSize = VideoSize.ratio18_9; // Next is 18:9
              break;
            case VideoSize.ratio18_9: // Added case for 18:9
              _currentVideoSize = VideoSize.ratio4_3;
              break;
            case VideoSize.ratio4_3:
              _currentVideoSize = VideoSize.ratio1_1;
              break;
            case VideoSize.ratio1_1:
              _currentVideoSize = VideoSize.fullScreen;
              break;
          }
        });

        _rebuildChewieController(wasPlaying); // Rebuild with new aspect ratio
      },
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/maximize.png', // Ensure this asset exists
              width: 24,
              height: 24,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              _getSizeName(_currentVideoSize), // Display size name
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // Refactored to ensure disposal happens cleanly before rebuild
  Future<void> _rebuildChewieController(bool wasPlaying) async {
    if (!mounted ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) return;

    // Store old controller and pause it
    final oldChewieController = _chewieController;
    oldChewieController?.pause();

    // Nullify the controller in the state immediately to remove it from the tree
    setState(() {
      _chewieController = null;
    });

    // Dispose the old controller asynchronously after a short delay
    // This allows the build cycle to remove the old Chewie widget first
    await Future.delayed(const Duration(milliseconds: 50)); // Small delay
    try {
      oldChewieController?.dispose();
    } catch (e) {
      // print("Error disposing old ChewieController (might be expected): $e");
    }

    // Check if still mounted before creating the new one
    if (!mounted ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) return;

    // Create the new controller
    final newChewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: wasPlaying, // Start playing if it was playing before
      looping: false,
      aspectRatio: _getAspectRatioForSize(_currentVideoSize),
      showControls: false,
      showOptions: false,
      materialProgressColors: ChewieProgressColors(
        // Added progress colors
        playedColor: widget.progressBarColor,
        // handleColor: widget.progressBarColor, // Removed invalid parameter
        bufferedColor: widget.progressBarBufferedColor,
        backgroundColor: Colors.white30,
      ),
      cupertinoProgressColors: ChewieProgressColors(
        // Added progress colors
        playedColor: widget.progressBarColor,
        // handleColor: widget.progressBarColor, // Removed invalid parameter
        bufferedColor: widget.progressBarBufferedColor,
        backgroundColor: Colors.white30,
      ),
      errorBuilder: (context, errorMessage) => _buildErrorWidget(errorMessage),
      autoInitialize: true, // Let Chewie handle initialization now
    );

    // Update state with the new controller if still mounted
    if (mounted) {
      setState(() {
        _chewieController = newChewieController;
      });
      _startHideControlsTimer();
    } else {
      // If not mounted anymore, dispose the newly created controller
      newChewieController.dispose();
    }
  }

  double? _getAspectRatioForSize(VideoSize size) {
    switch (size) {
      case VideoSize.fullScreen:
        // Avoid context access if not mounted, though less likely here
        if (!mounted) return 16 / 9; // Default if not mounted
        final mediaQuerySize = MediaQuery.of(context).size;
        return mediaQuerySize.width / mediaQuerySize.height;
      case VideoSize.ratio16_9:
        return 16 / 9;
      case VideoSize.ratio18_9: // Added case for 18:9
        return 18 / 9;
      case VideoSize.ratio4_3:
        return 4 / 3;
      case VideoSize.ratio1_1:
        return 1;
      default:
        return 16 / 9; // Default to 16:9
    }
  }

  String _getSizeName(VideoSize size) {
    switch (size) {
      case VideoSize.fullScreen:
        return "Full";
      case VideoSize.ratio16_9:
        return "16:9";
      case VideoSize.ratio18_9: // Added case for 18:9
        return "18:9";
      case VideoSize.ratio4_3:
        return "4:3";
      case VideoSize.ratio1_1:
        return "1:1";
      default:
        return "16:9"; // Default
    }
  }

  Widget _buildControls(BuildContext context) {
    return Stack(
      children: [
        FadeTransition(
          opacity: _opacityAnimation,
          child: IgnorePointer(
            ignoring: !_isControlsVisible,
            child: Stack(
              children: [
                // RESTORED: Top positioned stream selector
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildStreamSelector()),
                ),
                Center(
                  child: (_isLoading && !_hasError) ||
                          _videoPlayerController == null ||
                          !_videoPlayerController!.value.isInitialized
                      ? CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              widget.progressBarColor),
                        )
                      : IconButton(
                          icon: Icon(
                            _videoPlayerController?.value.isPlaying ?? false
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 64,
                          ),
                          onPressed: () {
                            if (!mounted) return;
                            if (_videoPlayerController?.value.isPlaying ??
                                false) {
                              _videoPlayerController?.pause();
                            } else {
                              _videoPlayerController?.play();
                            }
                            _startHideControlsTimer();
                          },
                        ),
                ),
                Positioned(
                  bottom: -10, // Trying -10 for a slight offset below the edge
                  left: 0,
                  right: 0,
                  // Removed Column, only bottom controls here
                  child: _buildBottomControls(context),
                ),
              ],
            ),
          ),
        ),
        // Error widget is now handled inside _buildVideoPlayer wrapper
        // if (_hasError)
        //   Positioned.fill(
        //     child: _buildErrorWidget("Error loading video"),
        //   ),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    // Use AnimatedBuilder to get the latest player values
    return AnimatedBuilder(
      animation: _videoPlayerController ??
          Listenable.merge([]), // Use dummy if controller is null
      builder: (context, child) {
        // Log the value of _isLive when building controls
        // print("_buildBottomControls: Building controls, _isLive = $_isLive"); // REMOVE print statement

        // Check controller validity inside builder
        final videoValue = _videoPlayerController?.value;
        final bool isInitialized = videoValue?.isInitialized ?? false;
        final Duration position = videoValue?.position ?? Duration.zero;
        final Duration duration = videoValue?.duration ?? Duration.zero;
        final double aspectRatio = videoValue?.aspectRatio ?? 16 / 9;

        // --- PiP Button (Android Only) ---
        Widget pipButton = const SizedBox.shrink();
        if (defaultTargetPlatform == TargetPlatform.android) {
          pipButton = IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
            tooltip: 'Picture-in-Picture',
            onPressed: !isInitialized
                ? null
                : () async {
                    // Disable if not initialized
                    if (!mounted) return;
                    try {
                      // print("Entering PiP mode (android_pip)...");
                      // Calculate aspect ratio for PiP
                      int num = 16; // Default
                      int den = 9; // Default
                      if (aspectRatio > 0 &&
                          !aspectRatio.isNaN &&
                          aspectRatio.isFinite) {
                        num = (aspectRatio * 100).round();
                        den = 100;
                        int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
                        int divisor = gcd(num, den);
                        num ~/= divisor;
                        den ~/= divisor;
                        // Clamp aspect ratio within Android limits (approx 1/2.39 to 2.39)
                        double decimalRatio = num / den;
                        if (decimalRatio > 2.39) {
                          num = 239;
                          den = 100;
                        } else if (decimalRatio < (1 / 2.39)) {
                          num = 100;
                          den = 239;
                        }
                      }

                      // print("PiP Aspect Ratio: $num/$den");
                      final success = await _androidPIP
                          .enterPipMode(aspectRatio: [num, den]);

                      if (success == true && mounted) {
                        // print("PiP mode entered successfully.");
                        // Optionally hide controls, though they might hide automatically
                        // _hideControls(animate: false);
                        // _hideControlsTimer?.cancel();
                      } else {
                        // print("Failed to enter PiP mode (returned $success).");
                        if (mounted)
                          _showError(
                              "Failed to enter Picture-in-Picture mode.");
                      }
                    } catch (e) {
                      // print("Error entering PiP mode: $e");
                      if (mounted) _showError("Error entering PiP mode: $e");
                    }
                  },
          );
        }

        // --- Logic to Determine Controls based on Duration ---
        // Check if duration indicates a live stream (duration is very small)
        final bool isEffectivelyLive = isInitialized &&
            duration.inMilliseconds <
                100; // Check if duration is less than 100ms
        // print(
        //     "_buildBottomControls: isInitialized = $isInitialized, duration = $duration (ms: ${duration.inMilliseconds}), isEffectivelyLive = $isEffectivelyLive");

        if (isEffectivelyLive) {
          // --- Live Controls Layout (with progress bar) ---
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0), // Keep bottom padding
            child: Container(
              // Changed Padding back to Container
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                // Re-added decoration
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent
                  ], // Lighter opacity
                  stops: const [0.0, 1.0],
                ),
              ),
              child: Row(
                children: [
                  // Live Indicator: Icon + Text in an oval transparent white container
                  Container(
                    // Re-introduce Container
                    margin: const EdgeInsets.only(right: 8.0), // Keep margin
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 4.0), // Adjust padding
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.25), // Transparent white background
                      borderRadius: BorderRadius.circular(
                          20.0), // High radius for oval/pill shape
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sensors,
                          color: const Color(0xFFE50914), // Keep icon red
                          size: 15.0,
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white, // Keep text white
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    // Progress Bar (Will likely show nothing or be full, but keep it)
                    child: GestureDetector(
                      onTap: () {
                        // Keep play/pause tap
                        if (!mounted ||
                            !isInitialized ||
                            _videoPlayerController == null) return;
                        if (_videoPlayerController!.value.isPlaying) {
                          _videoPlayerController!.pause();
                        } else {
                          _videoPlayerController!.play();
                        }
                        _startHideControlsTimer();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: VideoProgressIndicator(
                            _videoPlayerController!, // Still needed
                            allowScrubbing:
                                false, // Disable scrubbing for live?
                            padding:
                                const EdgeInsets.only(top: 5.0, bottom: 5.0),
                            colors: VideoProgressColors(
                              playedColor: widget.progressBarColor,
                              bufferedColor: widget.progressBarBufferedColor,
                              backgroundColor: Colors.white30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ), // REMOVE Total Duration Text Padding
                  // Keep PiP Button
                  pipButton,
                  const SizedBox(width: 4), // Spacer
                  // Keep Aspect Ratio Button
                  _buildAspectRatioButton(),
                ],
              ),
            ),
          );
        } else {
          // --- Non-Live Controls Layout ---
          return Padding(
            padding: const EdgeInsets.only(
                bottom: 10.0), // Add bottom padding to raise controls
            child: Container(
              // Changed Padding back to Container
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                // Re-added decoration
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent
                  ], // Lighter opacity
                  stops: const [0.0, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min, // Important for Column height
                children: [
                  Row(
                    children: [
                      // Current Position Text
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 10.0, right: 8.0), // Adjust padding as needed
                        child: Text(
                          _formatDuration(position),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Expanded(
                        // Progress Bar
                        child: GestureDetector(
                          onTap: () {
                            // Keep play/pause tap
                            if (!mounted ||
                                !isInitialized || // Added check
                                _videoPlayerController == null) return;
                            if (_videoPlayerController!.value.isPlaying) {
                              _videoPlayerController!.pause();
                            } else {
                              _videoPlayerController!.play();
                            }
                            _startHideControlsTimer();
                          },
                          child: isInitialized &&
                                  duration >
                                      Duration.zero // Condition already here
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4.0),
                                    child: VideoProgressIndicator(
                                      _videoPlayerController!,
                                      allowScrubbing: true,
                                      padding: const EdgeInsets.only(
                                          top: 5.0, bottom: 5.0),
                                      colors: VideoProgressColors(
                                        playedColor: widget.progressBarColor,
                                        bufferedColor:
                                            widget.progressBarBufferedColor,
                                        backgroundColor: Colors.white30,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      // PiP Button
                      pipButton,
                      const SizedBox(width: 4), // Spacer
                      // Aspect Ratio Button
                      _buildAspectRatioButton(),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildVideoPlayer() {
    // Crucial check: Only build Chewie if the controller exists and is initialized
    if (_chewieController == null ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      // print(
      //     "_buildVideoPlayer: Controller is null or not initialized, returning SizedBox");
      // Show loading indicator while Chewie is being rebuilt or initially loading
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(widget.progressBarColor),
        ),
      );
    }

    if (_hasError) {
      // print("_buildVideoPlayer: Error state, returning error widget");
      // Show error widget directly here if there's an error
      return _buildErrorWidget("Failed to load video");
    }

    // Don't show loading indicator here if Chewie controller exists,
    // Chewie might handle its own internal loading/buffering display
    // if (_isLoading) {
    //    return const Center(
    //     child: CircularProgressIndicator(
    //       valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
    //     ),
    //   );
    // }

    // print(
    //     "_buildVideoPlayer: Building Chewie with controller: $_chewieController");
    // Use a unique key to force rebuild when controller instance changes
    return Chewie(
      key: ValueKey(
          _chewieController.hashCode), // Use controller hashcode for key
      controller: _chewieController!,
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showNetworkError() {
    _showError("No internet connection. Please check your network settings.");
  }

  // --- Helper Methods --- (Moved from previous location)

  void _handleDoubleTap(TapDownDetails details) {
    if (!mounted ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized ||
        (_videoPlayerController!.value.duration <= Duration.zero))
      return; // Don't seek if duration unknown

    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.localPosition.dx;
    final Duration currentPosition = _videoPlayerController!.value.position;
    final Duration totalDuration = _videoPlayerController!.value.duration;
    const seekDuration = Duration(seconds: 10);

    Duration newPosition;
    if (tapPosition < screenWidth / 3) {
      // Seek backward (left third)
      newPosition =
          (currentPosition - seekDuration).clamp(Duration.zero, totalDuration);
      // print("Double tap left: Seeking back to $newPosition");
    } else if (tapPosition > screenWidth * 2 / 3) {
      // Seek forward (right third)
      newPosition =
          (currentPosition + seekDuration).clamp(Duration.zero, totalDuration);
      // print("Double tap right: Seeking forward to $newPosition");
    } else {
      // Middle third tapped, do nothing or maybe toggle play/pause?
      // For now, do nothing related to seeking.
      _onTap(); // Treat middle double tap as single tap (show/hide controls)
      return;
    }

    _videoPlayerController!.seekTo(newPosition);
    // Optionally add visual feedback here (e.g., show a quick icon)
    _startHideControlsTimer(); // Reset hide timer on seek
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (!mounted) return;

    if (result == ConnectivityResult.none) {
      _showNetworkError();
      _chewieController?.pause(); // Pause, don't dispose
    } else {
      // Connection restored. Try to re-initialize if needed.
      if (_videoPlayerController == null ||
          !_videoPlayerController!.value.isInitialized) {
        if (mounted && _currentUrl != null) {
          // print("Connectivity restored, re-initializing player.");
          _initializePlayerInternal(_currentUrl!);
        }
      } else if (!(_videoPlayerController!.value.isPlaying ||
          _videoPlayerController!.value.isBuffering)) {
        // If player exists but wasn't playing/buffering, try playing again
        if (mounted) {
          _videoPlayerController?.play();
        }
      }
    }
  }

  void _startPlaybackTimeoutTimer() {
    _playbackTimeoutTimer?.cancel();
    _playbackTimeoutTimer = Timer(widget.playbackTimeoutDuration, () {
      if (!mounted) return;
      if (_videoPlayerController != null &&
          _videoPlayerController!.value.isInitialized && // Check initialization
          !_videoPlayerController!.value.isPlaying &&
          !_videoPlayerController!.value.isBuffering &&
          _videoPlayerController!.value.position <= Duration.zero) {
        // Use <= zero
        // print("Playback timeout timer triggered retry");
        _tryNextStream();
      }
    });
  }

  void _startBufferingTimer() {
    _bufferingTimer?.cancel();
    _bufferingTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!mounted) return;
      if (_videoPlayerController?.value.isBuffering ?? false) {
        // print("Buffering timer triggered retry");
        _tryNextStream();
      }
    });
  }

  void _cancelAllTimers() {
    _hideControlsTimer?.cancel();
    _playbackTimeoutTimer?.cancel();
    _bufferingTimer?.cancel();
  }

  int _findInitialStreamIndex() {
    final index = widget.streamLinks
        .indexWhere((link) => link['url'] == widget.initialUrl);
    return index != -1 ? index : 0;
  }

  void _enableFullscreenMode() {
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Force landscape only when entering the player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Removed _disableFullscreenMode method as logic moved directly into dispose

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        onDoubleTapDown: _handleDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            _buildVideoPlayer(), // Builds Chewie or SizedBox/Loading/Error
            _buildControls(context), // Overlay controls
          ],
        ),
      ),
    );
  }
}

// Helper extension for Duration clamp (since it doesn't exist natively)
extension DurationClamp on Duration {
  Duration clamp(Duration lowerLimit, Duration upperLimit) {
    if (this < lowerLimit) return lowerLimit;
    if (this > upperLimit) return upperLimit;
    return this;
  }
}

// --- AdaptiveVideoPlayer Widget ---

class AdaptiveVideoPlayer extends StatelessWidget {
  final VideoPlayerController videoController;
  final VideoSize size;
  final ChewieController? chewieController;

  const AdaptiveVideoPlayer({
    Key? key,
    required this.videoController,
    this.chewieController,
    this.size = VideoSize.ratio16_9,
  }) : super(key: key);

  double _getAspectRatio() {
    switch (size) {
      case VideoSize.fullScreen:
        // Handle this case manually in build
        return 0;
      case VideoSize.ratio16_9:
        return 16 / 9;
      case VideoSize.ratio18_9: // Added missing case
        return 18 / 9;
      case VideoSize.ratio4_3:
        return 4 / 3;
      case VideoSize.ratio1_1:
        return 1 / 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;

    if (size == VideoSize.fullScreen) {
      return SizedBox(
        width: mq.size.width,
        height: mq.size.height,
        child: _buildPlayer(),
      );
    }

    final aspect = _getAspectRatio();
    // Avoid division by zero if aspect ratio is somehow 0
    final height = aspect > 0 ? width / aspect : mq.size.height;

    return SizedBox(
      width: width,
      height: height,
      child: _buildPlayer(),
    );
  }

  Widget _buildPlayer() {
    if (chewieController != null) {
      return Chewie(controller: chewieController!);
    } else {
      return VideoPlayer(videoController);
    }
  }
}
