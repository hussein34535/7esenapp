import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:android_pip/android_pip.dart';
import 'dart:convert'; // Added for jsonDecode
import 'package:http/http.dart' as http; // Added for HTTP requests

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  // State variables
  bool _isLoading = true;
  bool _hasError = false;
  bool _isControlsVisible = true;
  String? _currentStreamUrl; // URL of the currently selected stream source
  int _selectedStreamIndex = 0; // Index in widget.streamLinks
  bool _isCurrentStreamApi = false; // Is the current stream source an API link?
  bool _isCurrentlyInPip = false; // New: Track if currently in PiP mode

  // API specific state
  List<Map<String, dynamic>> _fetchedApiQualities =
      []; // Qualities fetched for the current API stream
  int _selectedApiQualityIndex =
      -1; // Index in _fetchedApiQualities, -1 if none selected/applicable

  VideoSize _currentVideoSize = VideoSize.ratio16_9;

  Timer? _hideControlsTimer;
  Timer? _playbackTimeoutTimer;
  Timer? _bufferingTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  late final AndroidPIP
      _androidPIP; // Modified: late final to init in initState

  List<Map<String, dynamic>> _validStreamLinks = [];

  @override
  void initState() {
    super.initState();
    // print("initState: START");
    WidgetsBinding.instance.addObserver(this); // Add observer

    // Initialize _androidPIP with callbacks
    _androidPIP = AndroidPIP(
      onPipEntered: () {
        if (mounted) {
          setState(() {
            _isCurrentlyInPip = true;
          });
          // print("PIP Entered: _isCurrentlyInPip = true");
        }
      },
      onPipExited: () {
        if (mounted) {
          setState(() {
            _isCurrentlyInPip = false;
          });
          // print("PIP Exited: _isCurrentlyInPip = false");
        }
        // When exiting PIP, if video was playing, resume it.
        if (_videoPlayerController != null &&
            !_videoPlayerController!.value.isPlaying) {
          _videoPlayerController!.play();
        }
      },
      onPipMaximised: () {
        if (mounted) {
          // When maximized, we are no longer in the mini window, but full app.
          // Treat it as exiting PIP for lifecycle purposes, as the app returns to full screen.
          setState(() {
            _isCurrentlyInPip = false;
          });
          // print("PIP Maximized: _isCurrentlyInPip set to false");
        }
        // Always attempt to play when maximized if not already playing.
        if (_videoPlayerController != null &&
            !_videoPlayerController!.value.isPlaying) {
          _videoPlayerController!.play();
        }
      },
    );

    // Enable automatic PiP mode when the app is minimized (Android only, API 31+)
    // _initializeAutoPipMode(); // Call an async helper function

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacityAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);

    _prepareAndInitializePlayer();

    _enableFullscreenMode();
    _startHideControlsTimer();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
    // print("initState: END");
  }

  Future<void> _initializeAutoPipMode() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _androidPIP.setAutoPipMode();
        // print("Enabled automatic PiP mode.");
      } on PlatformException catch (e) {
        // Handle PlatformException specifically, e.g., log it or show a message
        // print("Failed to enable automatic PiP mode due to PlatformException: $e");
        // You can add more specific handling here if needed, e.g., based on e.code
      } catch (e) {
        // Catch any other exceptions during auto PiP setup
        // print("An unexpected error occurred during auto PiP setup: $e");
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != oldWidget.initialUrl ||
        !listEquals(widget.streamLinks, oldWidget.streamLinks)) {
      // print("didUpdateWidget: URLs or stream links changed, re-preparing.");
      _cancelAllTimers();
      _releaseControllers().then((_) {
        if (mounted) {
          _prepareAndInitializePlayer(); // Re-initialize with new data
          _startHideControlsTimer();
        }
      });
    }
  }

  void _prepareAndInitializePlayer() {
    // 1. قم بتنقية قائمة السيرفرات أولاً
    _validStreamLinks = widget.streamLinks.where((link) {
      final name = link['name']?.toString();
      final url = link['url']?.toString();
      // السيرفر صالح فقط إذا كان الاسم والرابط موجودين وغير فارغين
      return name != null && name.isNotEmpty && url != null && url.isNotEmpty;
    }).toList();

    // 2. استخدم القائمة النقية (_validStreamLinks) في كل المنطق التالي
    // print("_prepareAndInitializePlayer: START");
    // 1. Determine initial stream index based on initialUrl or first link
    _selectedStreamIndex = _findUrlIndexInList(
        widget.initialUrl, _validStreamLinks); // استخدم القائمة الجديدة
    if (_selectedStreamIndex == -1 && _validStreamLinks.isNotEmpty) {
      // استخدم القائمة الجديدة
      _selectedStreamIndex =
          0; // Fallback to the first stream if initialUrl not found
    } else if (_validStreamLinks.isEmpty) {
      // استخدم القائمة الجديدة
      // Handle case with no stream links (perhaps only initialUrl?)
      // print("_prepareAndInitializePlayer: No stream links provided.");
      // If initialUrl is the only source, treat it as a single stream link
      // This logic might need adjustment based on how you handle single URLs
      // If initialUrl is empty too, we have a problem
      if (widget.initialUrl.isEmpty) {
        // print("_prepareAndInitializePlayer: ERROR - No initial URL or stream links.");
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        return; // Cannot initialize
      }
    }

    // 2. Get the current stream URL and determine if it's an API link
    if (_selectedStreamIndex >= 0 &&
        _selectedStreamIndex < _validStreamLinks.length) {
      // استخدم القائمة الجديدة
      _currentStreamUrl = _validStreamLinks[_selectedStreamIndex]['url']
          ?.toString(); // استخدم القائمة الجديدة
      if (_currentStreamUrl != null) {
        _isCurrentStreamApi =
            _currentStreamUrl!.startsWith('https://7esentv-match.vercel.app');
      } else {
        // Handle null URL case for the selected stream
        // print("_prepareAndInitializePlayer: ERROR - Selected stream has null URL at index $_selectedStreamIndex");
        _isCurrentStreamApi = false;
        _currentStreamUrl = null; // Ensure it's null
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        return;
      }
    } else {
      // Handle invalid index (should not happen with the logic above, but good practice)
      // print("_prepareAndInitializePlayer: ERROR - Invalid selected stream index: $_selectedStreamIndex");
      _currentStreamUrl = null;
      _isCurrentStreamApi = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    // 3. Reset API-specific state
    _fetchedApiQualities = [];
    _selectedApiQualityIndex = -1;

    // print("_prepareAndInitializePlayer: Prepared state - Index: $_selectedStreamIndex, URL: $_currentStreamUrl, IsAPI: $_isCurrentStreamApi");

    // 4. Update state and initialize player
    if (mounted) {
      setState(() {}); // Update UI with the initial selected stream etc.
      if (_currentStreamUrl != null) {
        _initializePlayerInternal(_currentStreamUrl!);
      }
    }
    // print("_prepareAndInitializePlayer: END - Calling initializePlayerInternal");
  }

  // Helper to find index, returns -1 if not found
  int _findUrlIndexInList(String url, List<Map<String, dynamic>> list) {
    if (url.isEmpty) return -1;
    return list.indexWhere((item) => item['url'] == url);
  }

  @override
  dispose() {
    // print("dispose: Disposing VideoPlayerScreenState");
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _cancelAllTimers();
    _connectivitySubscription?.cancel();
    _animationController.dispose();
    // Ensure controllers are released *before* super.dispose()
    _releaseControllers(); // Call this directly now
    // Disable fullscreen and wakelock, allow all orientations
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(
        DeviceOrientation.values); // Allow all
    super.dispose();
  }

  // --- App Lifecycle Handling ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // print("App Lifecycle State Changed: $state");
    // Ensure controller exists and is initialized before trying to pause/play
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      // print("App Lifecycle: Controller not ready, ignoring state change.");
      return;
    }

    // Only pause if the app is fully backgrounded (paused/detached) AND not in PiP mode.
    // If it's just 'inactive' (e.g., notification shade pulled down), we don't want to pause.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_videoPlayerController!.value.isPlaying && !_isCurrentlyInPip) {
        // print("App Lifecycle: Pausing video due to state: $state and NOT in PiP.");
        _videoPlayerController!.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      // If we resume, attempt to play the video unless it's already playing.
      if (!_videoPlayerController!.value.isPlaying) {
        // print("App Lifecycle: Resumed. Attempting to play video.");
        _videoPlayerController!.play();
      }
    }
  }

  // --- Player Initialization and Control ---

  // Initializes based on a SOURCE stream URL. Handles API fetching if necessary.
  Future<void> _initializePlayerInternal(String sourceUrl,
      {String? specificQualityUrl}) async {
    // print("_initializePlayerInternal: START - Source: $sourceUrl, Quality: $specificQualityUrl");
    if (!mounted) return;

    // Ensure loading state is set
    if (!_isLoading) {
      if (mounted)
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      else
        return;
    }

    // Dispose previous controllers
    await _releaseControllers();
    if (!mounted) return;

    String videoUrlToLoad;
    Map<String, String> httpHeaders = {
      'User-Agent': '7eSenTV_App_v1_SecretKey_987xyz',
      'Accept':
          'application/vnd.apple.mpegurl,application/x-mpegurl,video/mp4,application/mp4,video/MP2T,*/*',
    };
    bool fetchedApiThisRun =
        false; // Flag to update state only if API was fetched

    // Determine the actual URL to load
    if (specificQualityUrl != null) {
      // print("_initializePlayerInternal: Using specific quality URL: $specificQualityUrl");
      // Loading a specific quality URL selected by the user
      videoUrlToLoad = specificQualityUrl;
      // Use API User-Agent if the original source was API
      // httpHeaders['User-Agent'] = _isCurrentStreamApi
      //     ? 'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.106 Mobile Safari/537.36'
      //     : 'MyFlutterApp/1.0';
    } else if (_isCurrentStreamApi) {
      // print("_initializePlayerInternal: Current stream is API, fetching qualities from: $sourceUrl");
      // Initial load for an API stream source, need to fetch qualities
      List<Map<String, dynamic>> currentFetchedQualities = [];
      int currentSelectedApiQualityIndex = -1;

      try {
        final response = await http.get(Uri.parse(sourceUrl));
        fetchedApiThisRun = true; // Mark that we attempted fetch
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          String? selectedQualityUrl; // The URL we will load now
          List<Map<String, dynamic>> apiQualitiesForDisplay =
              []; // List for UI selector

          const qualityOrder = ['720', '480', '380', '1080'];
          Map<String, String> qualityUrlMap = {};

          data.forEach((key, value) {
            if (value != null && value.toString().isNotEmpty) {
              qualityUrlMap[key] = value.toString();
              if (qualityOrder.contains(key)) {
                apiQualitiesForDisplay
                    .add({'name': '${key}p', 'url': value.toString()});
              }
            }
          });

          apiQualitiesForDisplay.sort((a, b) {
            int indexA = qualityOrder.indexOf(a['name']!.replaceAll('p', ''));
            int indexB = qualityOrder.indexOf(b['name']!.replaceAll('p', ''));
            return indexA.compareTo(indexB);
          });

          // Select the URL to play based on preference
          for (String qualityKey in qualityOrder) {
            if (qualityUrlMap.containsKey(qualityKey)) {
              selectedQualityUrl = qualityUrlMap[qualityKey];
              break;
            }
          }
          // Fallback if no preferred quality found
          if (selectedQualityUrl == null && qualityUrlMap.isNotEmpty) {
            selectedQualityUrl = qualityUrlMap.values.first;
          }

          if (selectedQualityUrl != null) {
            videoUrlToLoad = selectedQualityUrl;
            currentFetchedQualities = apiQualitiesForDisplay;
            currentSelectedApiQualityIndex =
                _findUrlIndexInList(videoUrlToLoad, currentFetchedQualities);
            // print("_initializePlayerInternal: API fetch success. Playing: $videoUrlToLoad. Fetched: $currentFetchedQualities. Selected Index: $currentSelectedApiQualityIndex");
          } else {
            // print("_initializePlayerInternal: API fetch success but NO qualities found. Using source URL: $sourceUrl");
            videoUrlToLoad =
                sourceUrl; // Fallback to the API URL itself (likely won't work)
            currentFetchedQualities = [];
            currentSelectedApiQualityIndex = -1;
          }
          // Always use API User-Agent when interacting with the API source
          // httpHeaders['User-Agent'] =
          //     'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.106 Mobile Safari/537.36';
        } else {
          // print("_initializePlayerInternal: API fetch failed (${response.statusCode}). Using source URL: $sourceUrl");
          videoUrlToLoad = sourceUrl; // Fallback
          currentFetchedQualities = [];
          currentSelectedApiQualityIndex = -1;
        }
      } catch (e) {
        // print("_initializePlayerInternal: API fetch error ($e). Using source URL: $sourceUrl");
        videoUrlToLoad = sourceUrl; // Fallback
        currentFetchedQualities = [];
        currentSelectedApiQualityIndex = -1;
      }

      // Update the API state if we fetched this run
      if (mounted && fetchedApiThisRun) {
        // print("_initializePlayerInternal: Updating API state post-fetch.");
        setState(() {
          _fetchedApiQualities = currentFetchedQualities;
          _selectedApiQualityIndex = currentSelectedApiQualityIndex;
        });
      }
    } else {
      // print("_initializePlayerInternal: Not an API stream. Using source URL: $sourceUrl");
      // Not an API stream, just use the source URL directly
      videoUrlToLoad = sourceUrl;
      // httpHeaders['User-Agent'] = 'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.106 Mobile Safari/537.36'; // Always use standard agent
      // Ensure API state is clear if we switched from an API stream
      if (_fetchedApiQualities.isNotEmpty || _selectedApiQualityIndex != -1) {
        // print("_initializePlayerInternal: Clearing stale API state.");
        if (mounted) {
          setState(() {
            _fetchedApiQualities = [];
            _selectedApiQualityIndex = -1;
          });
        }
      }
    }

    // print("_initializePlayerInternal: Final URL to load: $videoUrlToLoad");
    // print("_initializePlayerInternal: Final Headers: $httpHeaders");

    // Create VideoPlayerController
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrlToLoad),
        httpHeaders: httpHeaders,
      );

      _videoPlayerController!.addListener(_videoPlayerListener);
      await _videoPlayerController!.initialize();

      if (!mounted) {
        _videoPlayerController?.dispose();
        return;
      }

      // Create Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _getAspectRatioForSize(_currentVideoSize),
        showControls: false, // Custom controls overlay
        showOptions: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: widget.progressBarColor,
          bufferedColor: widget.progressBarBufferedColor,
          backgroundColor: Colors.white30,
        ),
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: widget.progressBarColor,
          bufferedColor: widget.progressBarBufferedColor,
          backgroundColor: Colors.white30,
        ),
        errorBuilder: (context, errorMessage) =>
            _buildErrorWidget(errorMessage),
      );

      _startPlaybackTimeoutTimer();
      _startBufferingTimer();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
      // print("_initializePlayerInternal: SUCCESS for URL: $videoUrlToLoad");
    } catch (e) {
      // print("Error initializing player: $e for URL: $videoUrlToLoad");
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        // Don't automatically try next stream here, error is handled by errorBuilder or listener
      } else {
        _videoPlayerController?.dispose();
      }
    }
    // print("_initializePlayerInternal: END");
  }

  Future<void> _releaseControllers() async {
    // print("_releaseControllers: Releasing controllers");
    final vpController = _videoPlayerController;
    final chController = _chewieController;

    _videoPlayerController = null; // Nullify first
    _chewieController = null;

    vpController?.removeListener(_videoPlayerListener);
    await vpController?.dispose(); // Await disposal if needed
    try {
      chController?.dispose();
    } catch (e) {
      // print("Error disposing ChewieController: $e");
    }
  }

  void _videoPlayerListener() {
    if (!mounted ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) return;

    if (_videoPlayerController!.value.isPlaying) {
      _playbackTimeoutTimer?.cancel();
      _bufferingTimer?.cancel();
      // _isTryingNextStream = false; // Removed, retry logic is simpler now
    }

    if (_videoPlayerController!.value.hasError) {
      if (mounted /*&& !_isTryingNextStream*/) {
        // print("VideoPlayerListener: Error detected. State: $_hasError");
        // Error is now primarily handled by the Chewie errorBuilder
        // We might not need to aggressively try next stream here anymore
        // Just ensure the UI reflects the error state
        if (!_hasError) {
          // Only set state if not already set
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
      }
      return;
    }

    final isBuffering = _videoPlayerController!.value.isBuffering;
    if (isBuffering != _isLoading && !_hasError) {
      if (mounted) {
        setState(() {
          _isLoading = isBuffering;
        });
      }
    }
  }

  // --- Stream and Quality Handling ---

  // Called when selecting a SOURCE stream from the top bar
  Future<void> _changeStream(int newStreamIndex) async {
    // print("_changeStream: START - New Index: $newStreamIndex");
    if (!mounted || newStreamIndex == _selectedStreamIndex) {
      // print("_changeStream: Aborting - Not mounted or same index ($newStreamIndex)");
      return;
    }
    if (newStreamIndex < 0 || newStreamIndex >= _validStreamLinks.length) {
      // print("_changeStream: Aborting - Invalid index ($newStreamIndex)");
      return;
    }

    _cancelAllTimers();

    // Update state for the new stream source
    final newStreamData = _validStreamLinks[newStreamIndex];
    final newStreamUrl = newStreamData['url']?.toString();

    if (newStreamUrl == null || newStreamUrl.isEmpty) {
      // print("_changeStream: Aborting - URL is null or empty for index $newStreamIndex");
      _showError("Selected stream has no valid URL.");
      return;
    }

    setState(() {
      _isLoading = true; // Show loading immediately
      _hasError = false; // Reset error
      _selectedStreamIndex = newStreamIndex;
      _currentStreamUrl = newStreamUrl;
      _isCurrentStreamApi =
          _currentStreamUrl!.startsWith('https://7esentv-match.vercel.app');
      // Reset API specific state, it will be re-fetched if needed by initialize
      _fetchedApiQualities = [];
      _selectedApiQualityIndex = -1;
      // print("_changeStream: State updated - Index: $_selectedStreamIndex, URL: $_currentStreamUrl, IsAPI: $_isCurrentStreamApi");
    });

    await Future.delayed(
        const Duration(milliseconds: 50)); // Small delay for UI update

    if (!mounted) {
      // print("_changeStream: Aborting - Not mounted after delay.");
      return;
    }

    // Initialize player with the new SOURCE URL
    await _initializePlayerInternal(_currentStreamUrl!);
    // print("_changeStream: END - Finished initialization attempt.");
  }

  // Called when selecting a specific QUALITY from the bottom sheet for an API stream
  Future<void> _changeApiQuality(int newQualityIndex) async {
    // print("_changeApiQuality: START - New Index: $newQualityIndex");
    if (!mounted ||
        !_isCurrentStreamApi ||
        newQualityIndex == _selectedApiQualityIndex) {
      // print("_changeApiQuality: Aborting - Not mounted, not API stream, or same index ($newQualityIndex)");
      return;
    }
    if (newQualityIndex < 0 || newQualityIndex >= _fetchedApiQualities.length) {
      // print("_changeApiQuality: Aborting - Invalid index ($newQualityIndex) for fetched qualities ($_fetchedApiQualities)");
      return;
    }

    final newQualityData = _fetchedApiQualities[newQualityIndex];
    final specificQualityUrl = newQualityData['url']?.toString();

    if (specificQualityUrl == null || specificQualityUrl.isEmpty) {
      // print("_changeApiQuality: Aborting - URL is null or empty for index $newQualityIndex");
      _showError("Selected quality has no valid URL.");
      return;
    }

    // Update the selected API quality index immediately
    setState(() {
      _isLoading = true; // Show loading
      _hasError = false;
      _selectedApiQualityIndex = newQualityIndex;
      // print("_changeApiQuality: State updated - API Quality Index: $_selectedApiQualityIndex");
    });

    await Future.delayed(
        const Duration(milliseconds: 50)); // Small delay for UI update

    if (!mounted) {
      // print("_changeApiQuality: Aborting - Not mounted after delay.");
      return;
    }

    // Initialize player with the SPECIFIC quality URL
    // Pass the original sourceUrl just for context if needed, but use specificQualityUrl for loading
    await _initializePlayerInternal(_currentStreamUrl!,
        specificQualityUrl: specificQualityUrl);
    // print("_changeApiQuality: END - Finished initialization attempt.");
  }

  // --- Retry Logic (Simplified - Consider removing or refining) ---
  Future<void> _tryNextStream() async {
    // This logic needs review. Do we try the next SOURCE stream, or the next API quality?
    // For now, let's disable aggressive retries and rely on the error builder and manual retry.
    // print("_tryNextStream: Called (Currently Disabled/Needs Review)");

    /* // OLD/DISABLED RETRY LOGIC
    if (!mounted || _isTryingNextStream) {
      if (_isTryingNextStream) print("_tryNextStream: Already trying next stream, exiting");
      return;
    }
     _isTryingNextStream = true; // Set flag immediately

     print("_tryNextStream: Attempting to find next stream. Current index: $_selectedStreamIndex");
     final nextIndex = _findNextViableStreamIndex();

     if (nextIndex != -1) {
       final nextUrl = widget.streamLinks[nextIndex]['url'];
       if (nextUrl != null && nextUrl.isNotEmpty) {
         print("_tryNextStream: Changing stream to index: $nextIndex, URL: $nextUrl after delay");
         await Future.delayed(widget.streamSwitchDelay);
         if (!mounted) { _isTryingNextStream = false; return; }
         await _changeStream(nextIndex); // Pass index to _changeStream
         _isTryingNextStream = false;
       } else {
         print("_tryNextStream: Next stream URL is empty or null at index: $nextIndex");
         _handleNoMoreStreams();
         _isTryingStream = false;
       }
     } else {
       print("_tryNextStream: No other viable stream found after full loop.");
       _handleNoMoreStreams();
       _isTryingStream = false;
     }
     */
  }

  int _findNextViableStreamIndex() {
    // >>-- تعديل: استخدم القائمة الجديدة
    final int totalStreams = _validStreamLinks.length;
    if (totalStreams <= 1) return -1;

    // بما أن القائمة تحتوي فقط على سيرفرات صالحة، لم نعد بحاجة للتحقق من الرابط
    // لكن للإبقاء على المنطق، سنغير اسم المتغير فقط
    for (int i = _selectedStreamIndex + 1; i < totalStreams; i++) {
      return i;
    }
    for (int i = 0; i < _selectedStreamIndex; i++) {
      return i;
    }
    return -1;
  }

  void _handleNoMoreStreams() {
    // print("_handleNoMoreStreams: Setting error state.");
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
      _showError(
          "No other streams available or failed to load current stream.");
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

  // Builds the top stream selector based on widget.streamLinks
  Widget _buildStreamSelector() {
    // print("_buildStreamSelector: Building for ${_selectedStreamIndex}");
    // Always appears if more than one stream link exists
    // >>-- تعديل: استخدم القائمة الجديدة
    if (_validStreamLinks.length <= 1) {
      return const SizedBox.shrink();
    }

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
          // >>-- تعديل: استخدم القائمة الجديدة
          children: _validStreamLinks.asMap().entries.map<Widget>((entry) {
            final index = entry.key;
            final link = entry.value;
            // >>-- تعديل: أزل الاسم الافتراضي. نحن نضمن وجود اسم الآن
            final streamName = link['name']!.toString();
            final streamUrl = link['url']?.toString();
            // Highlight based on _selectedStreamIndex
            final isActive = index == _selectedStreamIndex;

            final bool canTap = streamUrl != null && streamUrl.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                // Disable tap if not tappable or already active
                onTap: !canTap || isActive
                    ? null
                    : () {
                        // print("StreamSelector tapped: Index $index");
                        _changeStream(
                            index); // Call _changeStream with the index
                      },
                borderRadius: BorderRadius.circular(20),
                child: Opacity(
                  opacity: canTap ? 1.0 : 0.5,
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
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    // print("_buildErrorWidget: Displaying error: $message");
    return Center(
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (mounted && _currentStreamUrl != null) {
                  // print("_buildErrorWidget: Retry button pressed. Re-initializing with: $_currentStreamUrl");
                  // Reset error state and retry initialization
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                  });
                  _initializePlayerInternal(_currentStreamUrl!);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white70,
                  foregroundColor: Colors.black),
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
    // print("_buildControls: Building. isVisible: $_isControlsVisible, isAPI: $_isCurrentStreamApi");
    return Stack(
      children: [
        FadeTransition(
          opacity: _opacityAnimation,
          child: IgnorePointer(
            ignoring: !_isControlsVisible,
            child: Stack(
              children: [
                // Always show stream selector if multiple streams exist
                // Visibility is handled inside _buildStreamSelector based on widget.streamLinks.length
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
                              size: 64),
                          onPressed: () {
                            if (!mounted || _videoPlayerController == null)
                              return;
                            if (_videoPlayerController!.value.isPlaying) {
                              _videoPlayerController!.pause();
                            } else {
                              _videoPlayerController!.play();
                            }
                            _startHideControlsTimer();
                          },
                        ),
                ),
                Positioned(
                  bottom: -10,
                  left: 0,
                  right: 0,
                  child: _buildBottomControls(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return AnimatedBuilder(
      animation: _videoPlayerController ?? Listenable.merge([]),
      builder: (context, child) {
        // print("_buildBottomControls: Building. isAPI: $_isCurrentStreamApi, fetchedQualities: ${_fetchedApiQualities.length}, selectedQualityIndex: $_selectedApiQualityIndex");

        final videoValue = _videoPlayerController?.value;
        final bool isInitialized = videoValue?.isInitialized ?? false;
        final Duration position = videoValue?.position ?? Duration.zero;
        final Duration duration = videoValue?.duration ?? Duration.zero;
        final double aspectRatio = videoValue?.aspectRatio ?? 16 / 9;

        // --- Quality Selection Button (Conditional) ---
        Widget qualityButton = const SizedBox.shrink();
        // Show if current stream is API AND we have fetched more than one quality
        if (_isCurrentStreamApi && _fetchedApiQualities.length > 1) {
          String currentQualityName = 'Auto'; // Default/fallback
          if (_selectedApiQualityIndex >= 0 &&
              _selectedApiQualityIndex < _fetchedApiQualities.length) {
            currentQualityName = _fetchedApiQualities[_selectedApiQualityIndex]
                        ['name']
                    ?.toString() ??
                'Auto';
          }
          // print("_buildBottomControls: Quality button visible. Current Name: $currentQualityName");

          qualityButton = InkWell(
            onTap: () {
              if (!mounted) return;
              // print("_buildBottomControls: Quality button tapped.");
              _showQualitySelectionDialog(context);
              _startHideControlsTimer(); // Reset hide timer
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              margin: const EdgeInsets.only(right: 8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    currentQualityName,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        } else {
          // print("_buildBottomControls: Quality button hidden.");
        }

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
                    if (!mounted) return;
                    try {
                      // ... (existing PiP aspect ratio calculation logic) ...
                      int num = 16, den = 9;
                      if (aspectRatio > 0 &&
                          !aspectRatio.isNaN &&
                          aspectRatio.isFinite) {
                        // ... (calculate num/den based on aspectRatio) ...
                        num = (aspectRatio * 100).round();
                        den = 100;
                        int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
                        int divisor = gcd(num, den);
                        num ~/= divisor;
                        den ~/= divisor;
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
        final bool isEffectivelyLive =
            isInitialized && duration.inMilliseconds < 100;

        if (isEffectivelyLive) {
          // --- Live Controls Layout ---
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      /* ... */ colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 1.0])),
              child: Row(
                children: [
                  // Live Indicator
                  Container(
                    margin: const EdgeInsets.only(right: 8.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20.0)),
                    child: const Row(/* ... */ children: [
                      Icon(Icons.sensors, color: Color(0xFFE50914), size: 15.0),
                      SizedBox(width: 5),
                      Text('LIVE',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5))
                    ]),
                  ),
                  Expanded(
                    // Progress Bar (Placeholder for live)
                    child: GestureDetector(
                      onTap: () {
                        /* Play/Pause */ if (!mounted ||
                            !isInitialized ||
                            _videoPlayerController == null) return;
                        if (_videoPlayerController!.value.isPlaying)
                          _videoPlayerController!.pause();
                        else
                          _videoPlayerController!.play();
                        _startHideControlsTimer();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(4.0),
                            child: VideoProgressIndicator(
                                _videoPlayerController!,
                                allowScrubbing: false,
                                padding: const EdgeInsets.only(
                                    top: 5.0, bottom: 5.0),
                                colors: VideoProgressColors(
                                    playedColor: widget.progressBarColor,
                                    bufferedColor:
                                        widget.progressBarBufferedColor,
                                    backgroundColor: Colors.white30))),
                      ),
                    ),
                  ),
                  qualityButton, // Add quality button
                  pipButton, // Add PiP button
                  const SizedBox(width: 4),
                  _buildAspectRatioButton(),
                ],
              ),
            ),
          );
        } else {
          // --- Non-Live Controls Layout ---
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      /* ... */ colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 1.0])),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Current Position Text
                      Padding(
                          padding:
                              const EdgeInsets.only(left: 10.0, right: 8.0),
                          child: Text(_formatDuration(position),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14))),
                      Expanded(
                        // Progress Bar
                        child: GestureDetector(
                          onTap: () {
                            /* Play/Pause */ if (!mounted ||
                                !isInitialized ||
                                _videoPlayerController == null) return;
                            if (_videoPlayerController!.value.isPlaying)
                              _videoPlayerController!.pause();
                            else
                              _videoPlayerController!.play();
                            _startHideControlsTimer();
                          },
                          child: isInitialized && duration > Duration.zero
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
                                              playedColor:
                                                  widget.progressBarColor,
                                              bufferedColor: widget
                                                  .progressBarBufferedColor,
                                              backgroundColor:
                                                  Colors.white30))),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      qualityButton, // Add quality button
                      pipButton, // Add PiP button
                      const SizedBox(width: 4),
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

  // --- Function to show Quality Selection Dialog/Sheet ---
  void _showQualitySelectionDialog(BuildContext context) {
    // print("_showQualitySelectionDialog: Showing dialog. Qualities: $_fetchedApiQualities");
    // Ensure we have qualities to show and the stream is API type
    if (!_isCurrentStreamApi || _fetchedApiQualities.isEmpty) {
      // print("_showQualitySelectionDialog: Aborting - Not API or no fetched qualities.");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(15.0))),
      builder: (BuildContext bc) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Wrap(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text("Select Quality",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
                Divider(color: Colors.grey[700], height: 1),
                // Generate ListTiles using _fetchedApiQualities
                ..._fetchedApiQualities.asMap().entries.map((entry) {
                  int idx = entry.key;
                  Map<String, dynamic> quality = entry.value;
                  String qualityName = quality['name']?.toString() ?? 'Unknown';
                  // String qualityUrl = quality['url']?.toString() ?? ''; // Url not needed directly here
                  // Highlight based on _selectedApiQualityIndex
                  bool isSelected = idx == _selectedApiQualityIndex;

                  return ListTile(
                    title: Text(qualityName,
                        style: TextStyle(
                            color: isSelected
                                ? widget.progressBarColor
                                : Colors.white)),
                    trailing: isSelected
                        ? Icon(Icons.check, color: widget.progressBarColor)
                        : null,
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                      if (!isSelected) {
                        // print("_showQualitySelectionDialog: Quality selected - Index: $idx");
                        _changeApiQuality(
                            idx); // Call function to change quality
                      } else {
                        // print("_showQualitySelectionDialog: Same quality selected - Index: $idx");
                      }
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer() {
    // ... (No significant changes needed here, relies on _chewieController) ...
    if (_chewieController == null ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) {
      // print("_buildVideoPlayer: Controller is null or not initialized, returning loading indicator");
      return Center(
          child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(widget.progressBarColor)));
    }
    if (_hasError) {
      // print("_buildVideoPlayer: Error state, returning error widget");
      return _buildErrorWidget("Failed to load video");
    }
    // print("_buildVideoPlayer: Building Chewie.");
    return Chewie(
        key: ValueKey(_chewieController.hashCode),
        controller: _chewieController!);
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

  // --- Helper Methods ---

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

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (!mounted) return;

    final result = results.first; // Get the first (and usually only) result

    if (result == ConnectivityResult.none) {
      _showNetworkError();
      _chewieController?.pause(); // Pause, don't dispose
    } else {
      // Connection restored. Try to re-initialize if needed.
      if (_videoPlayerController == null ||
          !_videoPlayerController!.value.isInitialized) {
        if (mounted && _currentStreamUrl != null) {
          // print("Connectivity restored, re-initializing player.");
          _initializePlayerInternal(_currentStreamUrl!);
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

  void _enableFullscreenMode() {
    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Force landscape only when entering the player
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // print("Build: Building VideoPlayerScreen Scaffold.");
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
            _buildVideoPlayer(),
            _buildControls(context),
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
