import 'dart:ui';
import 'dart:io'; // Platform check
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:android_pip/android_pip.dart';
import 'package:hesen/okru_stream_extractor.dart';
import 'dart:convert'; // Added for jsonDecode
import 'package:media_kit/media_kit.dart'; // MediaKit Player
import 'package:media_kit_video/media_kit_video.dart'; // MediaKit Video Widget
import 'package:window_manager/window_manager.dart'; // Window control for fullscreen

import 'player_utils/hesentv_handler.dart';
import 'player_utils/okru_playlist_parser.dart';
import 'player_utils/youtube_handler.dart';
import 'player_utils/vidstack_player_widget.dart'; // Added for Vidstack Web Player
import 'package:hesen/services/web_proxy_service.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/screens/login_screen.dart';

const String _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36';

enum VideoSize {
  fitWidth, // Default, fits width and maintains aspect ratio
  cover, // Fills the entire screen, might crop video
  ratio16_9,
  ratio18_9,
  ratio4_3,
}

class VideoPlayerScreen extends StatefulWidget {
  final String initialUrl;
  final List<Map<String, dynamic>> streamLinks;
  final Color progressBarColor;
  final bool isLocked;
  final int? contentId;
  final String? category;

  const VideoPlayerScreen({
    Key? key,
    required this.initialUrl,
    required this.streamLinks,
    this.progressBarColor = Colors.red,
    this.isLocked = false,
    this.contentId,
    this.category,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ... existing variables ...
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  UniqueKey _playerKey = UniqueKey();

  // State variables
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _validStreamLinks = [];
  bool _isControlsVisible = false;
  bool _isFullScreen = false; // Track window fullscreen state (Desktop)

  // MediaKit (Desktop Only)
  Player? _mediaKitPlayer;
  VideoController? _mediaKitController;

  String? _currentStreamUrl;
  int _selectedStreamIndex = 0;
  bool _isCurrentStreamApi = false;
  bool _isCurrentlyInPip = false;
  late AndroidPIP _androidPIP;
  int _autoRetryAttempt = 0;
  bool _isAutoRetrying = false; // Track if we are in a retry loop

  List<Map<String, dynamic>> _fetchedApiQualities = [];
  int _selectedApiQualityIndex = -1;

  VideoSize _currentVideoSize =
      VideoSize.fitWidth; // **MODIFIED:** New default aspect ratio

  Timer? _hideControlsTimer;
  Timer? _bufferingRetryTimer; // ADDED: To handle buffering timeouts
  Duration? _lastPosition; // ADDED: To store position before a retry
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    if (widget.isLocked && widget.contentId != null) {
      _isLoading = true;
      _unlockAndPlay();
    } else {
      _isLoading = true;
      _validStreamLinks = List<Map<String, dynamic>>.from(widget.streamLinks);
      _currentStreamUrl = widget.initialUrl;
      _initializePlayerInternal(_currentStreamUrl!);
    }

    _androidPIP = AndroidPIP(
      onPipEntered: () {
        if (!mounted) { return; }
        setState(() => _isCurrentlyInPip = true);
        _hideControls(animate: false);
      },
      onPipExited: () {
        if (!mounted) { return; }
        setState(() => _isCurrentlyInPip = false);
        if (_videoPlayerController != null &&
            !_videoPlayerController!.value.isPlaying) {
          _videoPlayerController!.play();
        }
      },
      onPipAction: (action) {
        if (!mounted || _videoPlayerController == null) { return; }
        final actionStr = action.toString();
        if (actionStr.contains('play')) {
          _videoPlayerController!.play();
        } else if (actionStr.contains('pause')) {
          _videoPlayerController!.pause();
        }
      },
    );
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _opacityAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    // Check access immediately
    _fetchUserDataAndCheckAccess();
  }

  Map<String, dynamic>? _userData;

  Future<void> _fetchUserDataAndCheckAccess() async {
    final authService = AuthService();
    _userData = await authService.getUserData();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final authService = AuthService();
    final isSubscribed = await authService.checkSubscription();

    // If passed externally as locked
    if (widget.isLocked) {
      if (!mounted) { return; }

      if (isSubscribed) {
        // User is subscribed, attempt to unlock via API
        _unlockAndPlay();
      } else {
        // Not subscribed, show Block/Trial dialog
        _showPremiumDialog();
      }
      return;
    }

    // --- Legacy Check (Backwards compatibility) ---
    // If not explicitly "locked" by parent, but we might want to check for empty links

    bool hasPlayableLinks = widget.streamLinks.any(
        (link) => link['url'] != null && link['url'].toString().isNotEmpty);

    if (!hasPlayableLinks) {
      if (!mounted) { return; }
      // Not premium (isLocked checked above), just broken/empty.
      _showError('عفواً، لا توجد روابط تشغيل متاحة لهذا المحتوى حالياً.');
    } else {
      // User is subscribed OR has free links, proceed
      _initializeScreen();
    }
  }

  Future<void> _showPremiumDialog() async {
    final bool trialUsed = _userData?['trialUsed'] == true;
    final user = AuthService().currentUser;

    // Show Dialog
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium,
                  color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('محتوى بريميوم',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'هذا المحتوى متاح فقط للمشتركين في الباقات المميزة.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Option 1: Trial (If available)
            if (user != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: Text(trialUsed
                    ? 'تم استخدام التجربة المجانية'
                    : 'بدء تجربة 24 ساعة مجاناً'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: trialUsed ? null : () => Navigator.pop(ctx, 1),
              ),
            const SizedBox(height: 12),
            // Option 2: Subscribe
            ElevatedButton.icon(
              icon: const Icon(Icons.star, size: 18),
              label: const Text('اشترك الآن لتفعيل البريميوم'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF673ab7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, 2),
            ),
            const SizedBox(height: 12),
            // Option 3: Free Quality (SD)
            OutlinedButton.icon(
              icon: const Icon(Icons.tv, size: 18),
              label: const Text('مشاهدة الجودات المجانية (SD)'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade700),
                foregroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, 3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (result == 1) {
      // Start Trial
      final success = await AuthService().startTrial();
      if (success) {
        if (!mounted) { return; }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تفعيل التجربة المجانية لمدة 24 ساعة!')),
        );
        _unlockAndPlay();
      } else {
        if (!mounted) { return; }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذراً، لا يمكن تفعيل التجربة حالياً.')),
        );
        _showPremiumDialog(); // Re-show to allow other options
      }
    } else if (result == 2) {
      // Subscribe (Navigate to Login/Profile)
      if (!mounted) { return; }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      _fetchUserDataAndCheckAccess();
    } else if (result == 3) {
      // Free Quality
      if (!mounted) { return; }
      // For now, if no free quality is found in streamLinks, show msg
      bool hasFree = widget.streamLinks.any((l) =>
          l['name']?.toString().toLowerCase().contains('free') == true ||
          l['name']?.toString().toLowerCase().contains('sd') == true);
      if (hasFree) {
        _initializeScreen();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('عذراً، الجودة المجانية غير متاحة لهذا الحدث حالياً.')),
        );
        _showPremiumDialog();
      }
    } else {
      // Close
      if (!mounted) { return; }
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _bufferingRetryTimer?.cancel(); // MODIFIED: Cancel buffering timer
    _connectivitySubscription?.cancel();
    _animationController.dispose();
    _releaseControllers().then((_) {
      WakelockPlus.disable();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    });
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.isInitialized) { return; }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (controller.value.isPlaying && !_isCurrentlyInPip) { controller.pause(); }
    } else if (state == AppLifecycleState.resumed) {
      if (!controller.value.isPlaying) { controller.play(); }
    }
  }

  Future<void> _unlockAndPlay() async {
    if (!mounted || widget.contentId == null || widget.category == null) { return; }

    try {
      final authService = AuthService();
      final unlockedData = await authService.unlockPremiumContent(
        type: widget.category!,
        id: widget.contentId!,
      );

      if (!mounted) { return; }

      if (unlockedData != null) {
        List<dynamic> newLinksJson = unlockedData['stream_link'] ?? [];
        List<Map<String, dynamic>> newStreamLinks = [];

        if (unlockedData['link'] != null && unlockedData['link'] is String) {
          newStreamLinks.add({'name': 'Watch', 'url': unlockedData['link']});
        } else if (unlockedData['url'] != null &&
            unlockedData['url'] is String) {
          newStreamLinks.add({'name': 'Watch', 'url': unlockedData['url']});
        }

        for (var link in newLinksJson) {
          if (link is Map) {
            newStreamLinks.add(Map<String, dynamic>.from(link));
          }
        }

        if (newStreamLinks.isNotEmpty) {
          setState(() {
            _validStreamLinks = newStreamLinks;
            _currentStreamUrl = newStreamLinks[0]['url']?.toString();
          });

          if (_currentStreamUrl != null) {
            _initializePlayerInternal(_currentStreamUrl!);
          }
          return;
        }
      }

      // If we reach here, unlock failed or produced no links
      setState(() {
        _hasError = true; // Show error or locked UI
      });
    } catch (e) {
      debugPrint("Internal Unlock Error: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  Future<void> _initializeScreen() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) { return; }

    if (widget.initialUrl.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("عذراً، لا يوجد بث متاح حالياً لهذه القناة.")),
        );
        Navigator.pop(context);
      }
      return;
    }

    _prepareAndInitializePlayer();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != oldWidget.initialUrl ||
        !listEquals(widget.streamLinks, oldWidget.streamLinks)) {
      _cancelAllTimers();
      _releaseControllers().then((_) {
        if (mounted) {
          _prepareAndInitializePlayer();
          _showControls();
        }
      });
    }
  }

  void _prepareAndInitializePlayer() {
    _validStreamLinks = widget.streamLinks.where((link) {
      final name = link['name']?.toString();
      final url = link['url']?.toString();

      // Basic validation: must have a URL and a non-empty name
      if (name == null ||
          name.trim().isEmpty ||
          url == null ||
          url.isEmpty ||
          name.trim().toLowerCase() == 'stream') {
        return false;
      }

      // Advanced validation: check for empty JSON rich text names like [{"text":""}]
      if (name.trim().startsWith('[') && name.trim().endsWith(']')) {
        try {
          final List<dynamic> nameParts = jsonDecode(name);
          if (nameParts.isNotEmpty) {
            bool allPartsEmpty = nameParts.every((part) {
              if (part is Map && part.containsKey('text')) {
                final text = part['text']?.toString();
                return text == null || text.trim().isEmpty;
              }
              return false; // Invalid part structure, treat as empty
            });
            if (allPartsEmpty) {
              return false; // It's an empty rich text, ignore it.
            }
          }
        } catch (e) {
          // Not valid JSON, so it's a regular name. Let it pass.
        }
      }

      return true; // The link is valid
    }).toList();

    String? urlToPlay;
    _selectedStreamIndex = -1;

    if (_validStreamLinks.isEmpty) {
      if (widget.initialUrl.isNotEmpty) { urlToPlay = widget.initialUrl; }
    } else {
      // 🆕 ALWAYS choose the first link as default if available
      _selectedStreamIndex = 0;
      urlToPlay = _validStreamLinks[0]['url']?.toString();
    }

    if (urlToPlay == null || urlToPlay.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    _currentStreamUrl = urlToPlay;
    _isCurrentStreamApi =
        _currentStreamUrl!.startsWith('https://7esentv-match.vercel.app') ||
            _currentStreamUrl!.startsWith('https://okru-api.vercel.app/api') ||
            _currentStreamUrl!.contains('ok.ru/video/') ||
            _currentStreamUrl!.contains('ok.ru/live/') ||
            _currentStreamUrl!.contains('youtube.com') ||
            _currentStreamUrl!.contains('youtu.be') ||
            (_currentStreamUrl!.contains('okcdn.ru') &&
                _currentStreamUrl!.split('?')[0].endsWith('.m3u8'));

    _fetchedApiQualities = [];
    _selectedApiQualityIndex = -1;

    if (mounted) {
      setState(() {});
      _initializePlayerInternal(_currentStreamUrl!);
    }
  }

  Future<void> _initializePlayerInternal(String sourceUrl,
      {String? specificQualityUrl, Duration? startAt}) async {
    if (!mounted) { return; }

    // Enable WakeLock to keep screen on during playback (Mobile & Web)
    WakelockPlus.enable();

    debugPrint('[HESEN PLAYER] Initializing player with sourceUrl: $sourceUrl');
    await _releaseControllers();
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) { return; }
    if (!_isLoading) { setState(() { _isLoading = true; }); }

    String? videoUrlToLoad;
    final String urlToProcess = specificQualityUrl ?? sourceUrl;
    Map<String, String> httpHeaders = {
      'User-Agent': _userAgent,
      'Referer': 'https://7esentv.com/',
    };

    try {
      if (kIsWeb) {
        // ✅ WEB OPTIMIZATION: Minimal parsing + Proxy
        if (urlToProcess.contains('youtube.com') ||
            urlToProcess.contains('youtu.be')) {
          // Vidstack handles YouTube natively - NO PROXY NEEDED
          debugPrint('[WEB] YouTube detected - using Vidstack directly');
          if (mounted) {
            setState(() {
              _currentStreamUrl = urlToProcess; // ❌ لا تستخدم Proxy لـ YouTube
              _isLoading = false;
              _hasError = false;
            });
            _showControls();
          }
          return;
        } else if (urlToProcess.contains('ok.ru/')) {
          // Ok.ru - Extract ID then use direct embed (no API call needed on web)
          String? videoId;
          if (urlToProcess.contains('/video/')) {
            videoId = urlToProcess.split('/video/').last.split('?').first;
          } else if (urlToProcess.contains('/live/')) {
            videoId = urlToProcess.split('/live/').last.split('?').first;
          }

          if (videoId != null && videoId.isNotEmpty) {
            // ✅ استخدم رابط Embed مباشر (Vidstack يدعمه)
            videoUrlToLoad = 'https://ok.ru/videoembed/$videoId';
            debugPrint('[WEB] Ok.ru embed URL: $videoUrlToLoad');
          } else {
            // ✅ إذا فشل، استخدم الرابط الخام مع Proxy
            videoUrlToLoad = WebProxyService.proxiedUrl(urlToProcess);
          }
        } else {
          // ✅ لأي رابط آخر (M3U8, MP4, إلخ) استخدم Proxy
          videoUrlToLoad = WebProxyService.proxiedUrl(urlToProcess);
          debugPrint('[WEB] Using proxied URL: $videoUrlToLoad');
        }

        // Update state and show Vidstack player
        if (mounted) {
          setState(() {
            _currentStreamUrl = videoUrlToLoad;
            _isLoading = false;
            _hasError = false;
          });
          _showControls();
        }
        return; // Skip native player initialization
      }

      // ========== MOBILE/DESKTOP LOGIC ==========
      if (urlToProcess.contains('youtube.com') ||
          urlToProcess.contains('youtu.be')) {
        debugPrint(
            '[MOBILE] URL identified as YouTube. Processing in background...');
        final streamDetails = await compute(handleYoutubeStream, urlToProcess);
        videoUrlToLoad = streamDetails.videoUrlToLoad;
        if (mounted) {
          setState(() {
            _fetchedApiQualities = streamDetails.fetchedQualities;
            _selectedApiQualityIndex = streamDetails.selectedQualityIndex;
          });
        }
      } else if (urlToProcess.contains('ok.ru/')) {
        String? videoId;
        if (urlToProcess.contains('/video/')) {
          videoId = urlToProcess.split('/video/').last.split('?').first;
        } else if (urlToProcess.contains('/live/')) {
          videoId = urlToProcess.split('/live/').last.split('?').first;
        }

        if (videoId != null && videoId.isNotEmpty) {
          final streamUrl = await getOkruStreamUrl(videoId);
          if (streamUrl != null && streamUrl.isNotEmpty) {
            videoUrlToLoad = streamUrl;
            if (videoUrlToLoad.toLowerCase().contains('.m3u8')) {
              final qualities = await parseOkruQualities(videoUrlToLoad);
              if (mounted && qualities.isNotEmpty) {
                setState(() {
                  _fetchedApiQualities = qualities;
                  _selectedApiQualityIndex = 0;
                });
              }
            }
          } else {
            throw Exception('Could not extract a playable URL from ok.ru');
          }
        } else {
          videoUrlToLoad =
              urlToProcess; // Not a recognized ok.ru format, play raw
        }
      } else if (urlToProcess.contains('okcdn.ru') &&
          urlToProcess.toLowerCase().contains('.m3u8')) {
        videoUrlToLoad = urlToProcess;
        final qualities = await parseOkruQualities(videoUrlToLoad);
        if (mounted && qualities.isNotEmpty) {
          setState(() {
            _fetchedApiQualities = qualities;
            _selectedApiQualityIndex = 0;
          });
        }
      } else if (urlToProcess.startsWith('https://7esentv-match.vercel.app')) {
        final streamDetails = await handleHesenTvStream(urlToProcess);
        videoUrlToLoad = streamDetails.videoUrlToLoad;
        if (mounted) {
          setState(() {
            _fetchedApiQualities = streamDetails.fetchedQualities;
            _selectedApiQualityIndex = streamDetails.selectedQualityIndex;
          });
        }
      } else {
        debugPrint(
            '[HESEN PLAYER] URL did not match any handler. Playing raw URL.');
        String urlToPlay = urlToProcess;
        videoUrlToLoad = urlToPlay;

        // ✅ WEB OPTIMIZATION: For generic links on Web, use Vidstack directly
        if (kIsWeb) {
          debugPrint('[WEB] Generic URL detected - using Vidstack directly');
          if (mounted) {
            setState(() {
              _currentStreamUrl = videoUrlToLoad;
              _isLoading = false;
              _hasError = false;
            });
            _showControls();
          }
          return;
        }
      }

      if (videoUrlToLoad == null || videoUrlToLoad.isEmpty) {
        throw Exception('videoUrlToLoad could not be determined.');
      }

      VideoFormat? formatHint;
      if (videoUrlToLoad.startsWith('data:application/dash+xml')) {
        formatHint = VideoFormat.dash;
      } else if (videoUrlToLoad.toLowerCase().contains('.m3u8')) {
        formatHint = VideoFormat.hls;
      }

      // ====== DESKTOP: Use MediaKit (MPV Backend) ======
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        debugPrint('[HESEN PLAYER] Desktop detected - Using MediaKit');
        try {
          // Create Player if needed
          _mediaKitPlayer ??= Player();
          _mediaKitController ??= VideoController(_mediaKitPlayer!);

          // Listen for errors to trigger failover/retry
          _mediaKitPlayer!.stream.error.listen((error) {
            debugPrint('[MEDIAKIT ERROR] $error');
            if (mounted && !_isAutoRetrying) {
              _retryMediaKitPlayback(videoUrlToLoad!, httpHeaders);
            }
          });

          // Attempt to open
          await _mediaKitPlayer!.open(
            Media(videoUrlToLoad, httpHeaders: httpHeaders),
            play: true,
          );

          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = false;
              _isAutoRetrying = false;
            });
            _showControls();
          }
        } catch (e) {
          debugPrint('[MEDIAKIT INIT ERROR] $e');
          if (mounted && !_isAutoRetrying) {
            _retryMediaKitPlayback(videoUrlToLoad, httpHeaders);
          }
        }
        return; // Skip VideoPlayer initialization for Desktop
      }

      // ====== MOBILE: Use VideoPlayer + Chewie ======
      _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(videoUrlToLoad),
          httpHeaders: httpHeaders,
          formatHint: formatHint);
      _videoPlayerController!.addListener(_videoPlayerListener);
      await _videoPlayerController!.initialize();
      await _videoPlayerController!.setLooping(false);

      if (!mounted) {
        _videoPlayerController?.dispose();
        return;
      }

      final aspectRatio = _videoPlayerController!.value.aspectRatio;
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        startAt: startAt,
        aspectRatio:
            (aspectRatio <= 0 || aspectRatio.isNaN) ? 16 / 9 : aspectRatio,
        showControls: false,
        errorBuilder: (context, errorMessage) =>
            _buildErrorWidget(errorMessage),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
        _autoRetryAttempt = 0; // Reset counter on successful initialization
        _showControls();
      }
    } catch (e) {
      debugPrint('[HESEN PLAYER] ERROR in _initializePlayerInternal: $e');
      if (mounted) {
        if (_autoRetryAttempt < 1) {
          _autoRetryAttempt++;
          debugPrint(
              '[HESEN PLAYER] Retrying same stream (attempt ${_autoRetryAttempt + 1})');
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) {
            _initializePlayerInternal(sourceUrl,
                specificQualityUrl: specificQualityUrl, startAt: startAt);
          }
        } else {
          if (_validStreamLinks.length > 1) {
            _tryNextStream();
          } else {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          }
        }
      }
    }
  }

  Future<void> _retryMediaKitPlayback(
      String url, Map<String, String> headers) async {
    if (!mounted || _isAutoRetrying) { return; }

    _autoRetryAttempt++;
    if (_autoRetryAttempt > 2) {
      debugPrint('[HESEN PLAYER] MediaKit persistent failure after retries.');
      _autoRetryAttempt = 0;
      _isAutoRetrying = false;
      if (mounted) { _tryNextStream(); }
      return;
    }

    _isAutoRetrying = true;
    debugPrint(
        '[HESEN PLAYER] MediaKit retry attempt $_autoRetryAttempt for: $url');

    // Wait 1.5s before retry (Vercel cold start or network burp)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted && _mediaKitPlayer != null) {
      try {
        await _mediaKitPlayer!
            .open(Media(url, httpHeaders: headers), play: true);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = false;
            _isAutoRetrying = false;
          });
        }
      } catch (e) {
        debugPrint('[HESEN PLAYER] Retry $_autoRetryAttempt failed: $e');
        _isAutoRetrying = false;
        _retryMediaKitPlayback(url, headers);
      }
    } else {
      _isAutoRetrying = false;
    }
  }

  Future<void> _releaseControllers() async {
    _bufferingRetryTimer?.cancel(); // MODIFIED: Cancel buffering timer
    final chewie = _chewieController;
    final video = _videoPlayerController;
    _chewieController = null;
    _videoPlayerController = null;
    chewie?.dispose();
    if (video != null) {
      video.removeListener(_videoPlayerListener);
      video.dispose();
    }

    // MediaKit Cleanup (Desktop)
    if (_mediaKitPlayer != null) {
      await _mediaKitPlayer!.dispose();
      _mediaKitPlayer = null;
      _mediaKitController = null;
    }
  }

  void _videoPlayerListener() {
    if (!mounted ||
        _videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) return;
    if (_videoPlayerController!.value.hasError) {
      if (!_hasError) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        _tryNextStream(); // Try next stream if an error occurs mid-play
      }
      return;
    }

    final value = _videoPlayerController!.value;
    final isBuffering = value.isBuffering;

    // Handle buffering timeout
    if (isBuffering && !value.isPlaying) {
      // If buffering starts, and we don't already have a timer, start one.
      if (_bufferingRetryTimer == null || !_bufferingRetryTimer!.isActive) {
        _bufferingRetryTimer =
            Timer(const Duration(seconds: 15), _handleBufferingTimeout);
      }
    } else {
      // If buffering stops (or video is playing), cancel the timer.
      _bufferingRetryTimer?.cancel();
    }

    if (isBuffering != _isLoading && !_hasError) {
      if (mounted) { setState(() { _isLoading = isBuffering; }); }
    }
  }

  void _handleBufferingTimeout() {
    if (!mounted || _currentStreamUrl == null) { return; }

    // Check if the player is still buffering and not playing
    final isStuck = _videoPlayerController?.value.isBuffering == true &&
        _videoPlayerController?.value.isPlaying == false;

    if (isStuck) {
      debugPrint(
          '[HESEN PLAYER] Buffering timed out. Retrying the same stream.');
      _showError('البث ضعيف، جاري محاولة إعادة الاتصال...');

      // Store the last known position
      _lastPosition = _videoPlayerController?.value.position;

      // Re-initialize the player with the same URL
      _initializePlayerInternal(_currentStreamUrl!, startAt: _lastPosition);
    }
  }

  Future<void> _tryNextStream() async {
    if (!mounted || _validStreamLinks.length <= 1) { return; }
    _autoRetryAttempt = 0; // Reset for the new stream
    final int nextIndex = (_selectedStreamIndex + 1) % _validStreamLinks.length;
    // Shortened delay
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      // _showError('البث الحالي لا يعمل، جاري محاولة البث التالي...'); // MODIFIED: Removed the toast message
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) { _changeStream(nextIndex, isAutoRetry: true); }
    }
  }

  Future<void> _changeStream(int newStreamIndex,
      {bool isAutoRetry = false}) async {
    if (!mounted ||
        newStreamIndex == _selectedStreamIndex ||
        newStreamIndex < 0 ||
        newStreamIndex >= _validStreamLinks.length) return;

    final Duration? startAt = _videoPlayerController?.value.position;
    if (!isAutoRetry) {
      _autoRetryAttempt = 0;
    }
    _cancelAllTimers();

    final newStreamData = _validStreamLinks[newStreamIndex];
    final newStreamUrl = newStreamData['url']?.toString();

    if (newStreamUrl == null || newStreamUrl.isEmpty) {
      _showError("Selected stream has no valid URL.");
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _selectedStreamIndex = newStreamIndex;
      _currentStreamUrl = newStreamUrl;
      _playerKey = UniqueKey();
      _isCurrentStreamApi = _currentStreamUrl!
              .startsWith('https://7esentv-match.vercel.app') ||
          _currentStreamUrl!.startsWith('https://okru-api.vercel.app/api') ||
          _currentStreamUrl!.contains('ok.ru/video/') ||
          _currentStreamUrl!.contains('ok.ru/live/') ||
          _currentStreamUrl!.contains('youtube.com') ||
          _currentStreamUrl!.contains('youtu.be') ||
          (_currentStreamUrl!.contains('okcdn.ru') &&
              _currentStreamUrl!.split('?')[0].endsWith('.m3u8'));
      _fetchedApiQualities = [];
      _selectedApiQualityIndex = -1;
    });

    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) { return; }

    // ✅ على الويب: تحديث الرابط مباشرة بدون إعادة تهيئة كاملة
    if (kIsWeb) {
      String urlToUse = newStreamUrl;

      // Apply proxy if needed
      if (!newStreamUrl.contains('youtube.com') &&
          !newStreamUrl.contains('youtu.be')) {
        if (newStreamUrl.contains('ok.ru/')) {
          String? videoId;
          if (newStreamUrl.contains('/video/')) {
            videoId = newStreamUrl.split('/video/').last.split('?').first;
          } else if (newStreamUrl.contains('/live/')) {
            videoId = newStreamUrl.split('/live/').last.split('?').first;
          }
          if (videoId != null && videoId.isNotEmpty) {
            urlToUse = 'https://ok.ru/videoembed/$videoId';
          } else {
            urlToUse = WebProxyService.proxiedUrl(newStreamUrl);
          }
        } else {
          urlToUse = WebProxyService.proxiedUrl(newStreamUrl);
        }
      }

      setState(() {
        _currentStreamUrl = urlToUse;
        _isLoading = false;
        _hasError = false;
      });
      _showControls();
      return;
    }

    // Mobile: Full initialization
    await _initializePlayerInternal(_currentStreamUrl!, startAt: startAt);
  }

  Future<void> _changeApiQuality(int newQualityIndex) async {
    if (!mounted ||
        !_isCurrentStreamApi ||
        newQualityIndex == _selectedApiQualityIndex ||
        newQualityIndex < 0 ||
        newQualityIndex >= _fetchedApiQualities.length) return;
    final Duration? startAt = _videoPlayerController?.value.position;
    final newQualityData = _fetchedApiQualities[newQualityIndex];
    final specificQualityUrl = newQualityData['url']?.toString();
    if (specificQualityUrl == null || specificQualityUrl.isEmpty) {
      _showError("Selected quality has no valid URL.");
      return;
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
      _selectedApiQualityIndex = newQualityIndex;
      _playerKey = UniqueKey();
    });
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) { return; }
    await _initializePlayerInternal(_currentStreamUrl!,
        specificQualityUrl: specificQualityUrl, startAt: startAt);
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer =
        Timer(const Duration(seconds: 4), () => _hideControls(animate: true));
  }

  void _hideControls({required bool animate}) {
    if (!mounted || !_isControlsVisible) { return; }
    if (animate)
      _animationController.reverse();
    else
      _animationController.value = 0.0;
    _setControlsVisibility(false);
  }

  void _toggleControlsVisibility() {
    if (_isControlsVisible)
      _hideControls(animate: true);
    else
      _showControls();
  }

  void _showControls() {
    if (!mounted || _isControlsVisible) { return; }
    _animationController.forward();
    _setControlsVisibility(true);
    _startHideControlsTimer();
  }

  void _setControlsVisibility(bool isVisible) {
    // MODIFIED: Don't check _isControlsVisible here to allow forcing a state update
    if (mounted) { setState(() { _isControlsVisible = isVisible; }); }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) { return "00:00"; }
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (duration.inHours > 0)
      return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
    else
      return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (mounted && _currentStreamUrl != null) {
                setState(() {
                  _hasError = false;
                  _isLoading = true;
                });
                _initializePlayerInternal(_currentStreamUrl!);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white70, foregroundColor: Colors.black),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamSelector() {
    // MODIFIED: Show even if there is only one link, as long as the list is not empty.
    if (_validStreamLinks.isEmpty) { return const SizedBox.shrink(); }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(25)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _validStreamLinks.asMap().entries.map<Widget>((entry) {
            final index = entry.key;
            final streamName = entry.value['name']!.toString();
            final isActive = index == _selectedStreamIndex;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                onTap: isActive ? null : () => _changeStream(index),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                      color: isActive
                          ? widget.progressBarColor
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: isActive
                          ? Border.all(color: Colors.white, width: 2)
                          : null),
                  child: Text(streamName,
                      style: TextStyle(
                          color: isActive ? Colors.white : Colors.white70,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showQualitySelectionDialog(BuildContext context) {
    if (!_isCurrentStreamApi || _fetchedApiQualities.isEmpty) { return; }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: Text('اختر الجودة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold))),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _fetchedApiQualities.asMap().entries.map((entry) {
                      final qualityKey = entry.key;
                      final qualityName =
                          entry.value['name']?.toString() ?? 'Unknown';
                      final bool isSelected =
                          qualityKey == _selectedApiQualityIndex;
                      return ListTile(
                        title: Text(qualityName,
                            style: TextStyle(
                                color: isSelected
                                    ? widget.progressBarColor
                                    : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        trailing: isSelected
                            ? Icon(Icons.check, color: widget.progressBarColor)
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          if (!isSelected) { _changeApiQuality(qualityKey); }
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message), duration: const Duration(seconds: 5)));
  }

  void _handleDoubleTap(TapDownDetails details) {
    if (!mounted ||
        (_videoPlayerController?.value.duration ?? Duration.zero) <=
            Duration.zero) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.localPosition.dx;
    final currentPosition = _videoPlayerController!.value.position;
    final totalDuration = _videoPlayerController!.value.duration;
    const seekDuration = Duration(seconds: 10);
    Duration newPosition;
    if (tapPosition < screenWidth / 3)
      newPosition =
          (currentPosition - seekDuration).clamp(Duration.zero, totalDuration);
    else if (tapPosition > screenWidth * 2 / 3)
      newPosition =
          (currentPosition + seekDuration).clamp(Duration.zero, totalDuration);
    else {
      _toggleControlsVisibility();
      return;
    }
    _chewieController?.seekTo(newPosition);
    _cancelAllTimers(); // MODIFIED: Cancel timers on interaction
    _showControls();
  }

  void _cancelAllTimers() {
    _hideControlsTimer?.cancel();
    _bufferingRetryTimer?.cancel(); // MODIFIED: Cancel buffering timer
  }

  // =======================================================================
  // ==================== UI / BUILD METHODS - MAJOR CHANGES ================
  // =======================================================================

  Widget _buildControls(BuildContext context) {
    if (kIsWeb) {
      // WEB: Controls (including Stream Links) are now inside the Vidstack Overlay.
      // So we return empty here to hide the "Old" external buttons.
      return const SizedBox.shrink();
    }

    // MODIFIED: This entire widget is now controlled by FadeTransition and IgnorePointer.
    // The logic to hide it during loading has been removed from here and is handled in the main build method stack.
    return FadeTransition(
      opacity: _opacityAnimation,
      child: IgnorePointer(
        ignoring: !_isControlsVisible,
        child: Stack(
          children: [
            // Back Button (Top Left)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () async {
                    // Desktop: Exit fullscreen first if active
                    if (!kIsWeb &&
                        (Platform.isWindows ||
                            Platform.isLinux ||
                            Platform.isMacOS)) {
                      if (_isFullScreen) {
                        await windowManager.setFullScreen(false);
                        _isFullScreen = false;
                      }
                    }
                    if (mounted) { Navigator.of(context).pop(); }
                  },
                ),
              ),
            ),

            // Top Stream Selector (Center)
            // MODIFIED: Show if there is at least one valid link.

            if (_validStreamLinks.isNotEmpty)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 60, // Offset for back button
                right: 0,
                child: Center(child: _buildStreamSelector()),
              ),

            // Center play/pause button
            Center(
              child: (_isLoading && !_hasError)
                  ? const SizedBox
                      .shrink() // Loading indicator is at root stack
                  : Builder(builder: (context) {
                      // Desktop: MediaKit
                      final bool isDesktop = !kIsWeb &&
                          (Platform.isWindows ||
                              Platform.isLinux ||
                              Platform.isMacOS);
                      if (isDesktop) {
                        if (_mediaKitController == null)
                          return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () {
                            if (_mediaKitPlayer != null) {
                              if (_mediaKitPlayer!.state.playing) {
                                _mediaKitPlayer!.pause();
                              } else {
                                _mediaKitPlayer!.play();
                              }
                            }
                            _cancelAllTimers();
                            _startHideControlsTimer();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              (_mediaKitPlayer?.state.playing ?? false)
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        );
                      }
                      // Mobile: VideoPlayerController
                      if (_videoPlayerController == null ||
                          !_videoPlayerController!.value.isInitialized) {
                        return const SizedBox.shrink();
                      }
                      return ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: _videoPlayerController!,
                        builder: (context, value, child) {
                          return GestureDetector(
                            onTap: () {
                              if (value.isPlaying)
                                _videoPlayerController!.pause();
                              else
                                _videoPlayerController!.play();
                              _cancelAllTimers();
                              _startHideControlsTimer();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          );
                        },
                      );
                    }),
            ),

            // Bottom controls bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    final controller = _videoPlayerController;

    // Desktop: MediaKit doesn't expose position/duration the same way,
    // so we detect live streams by URL pattern and show simplified controls.
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return AnimatedBuilder(
      animation: controller ?? kAlwaysCompleteAnimation,
      builder: (context, child) {
        // Desktop uses MediaKit, Mobile uses VideoPlayerController
        final bool isInitialized = isDesktop
            ? (_mediaKitController != null)
            : (controller?.value.isInitialized ?? false);

        // On Desktop, detect live by URL pattern:
        // - m3u8 streams are typically live
        // - 7esenlink API streams are live IPTV
        final bool isLiveUrl =
            (_currentStreamUrl?.toLowerCase().contains('.m3u8') ?? false) ||
                (_currentStreamUrl
                        ?.contains('7esenlink.vercel.app/api/stream') ??
                    false);

        final position = isDesktop
            ? Duration
                .zero // MediaKit position tracking would need stream.position.listen
            : (controller?.value.isInitialized == true
                ? controller!.value.position
                : Duration.zero);
        final duration = isDesktop
            ? Duration.zero // Live streams have no duration
            : (controller?.value.isInitialized == true
                ? controller!.value.duration
                : Duration.zero);

        // --- Buttons ---
        Widget qualityButton = const SizedBox.shrink();
        if (_isCurrentStreamApi && _fetchedApiQualities.length > 1) {
          String name = 'Auto';
          if (_selectedApiQualityIndex >= 0 &&
              _selectedApiQualityIndex < _fetchedApiQualities.length) {
            name = _fetchedApiQualities[_selectedApiQualityIndex]['name']
                    ?.toString() ??
                'Auto';
          }
          qualityButton = TextButton(
            onPressed: () {
              _showQualitySelectionDialog(context);
              _startHideControlsTimer();
            },
            child: Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          );
        }

        Widget pipButton = const SizedBox.shrink();
        if (defaultTargetPlatform == TargetPlatform.android) {
          pipButton = IconButton(
            icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
            onPressed: !isInitialized
                ? null
                : () async {
                    if (!mounted) { return; }
                    try {
                      final asp = controller!.value.aspectRatio;
                      int n = 16, d = 9;
                      if (asp > 0 && asp.isFinite) {
                        n = (asp * 100).round();
                        d = 100;
                      }
                      await _androidPIP.enterPipMode(aspectRatio: [n, d]);
                    } catch (e) {
                      if (mounted) { _showError("Error: $e"); }
                    }
                  },
          );
        }

        // --- Progress Bar Items ---
        // Desktop: use URL pattern to detect live (m3u8 = live), Mobile: duration == 0 = live
        final bool isLive = isDesktop
            ? isLiveUrl
            : (isInitialized && duration.inMilliseconds == 0);
        final double durationMs =
            (isInitialized && !isLive && duration.inMilliseconds > 0)
                ? duration.inMilliseconds.toDouble()
                : 1.0;
        final double positionMs = (isInitialized && !isLive)
            ? position.inMilliseconds.clamp(0.0, durationMs).toDouble()
            : 0.0;
        double bufferedMs = 0.0;
        // Only get buffer info on Mobile (Desktop MediaKit handles buffering differently)
        if (!isDesktop &&
            isInitialized &&
            !isLive &&
            controller!.value.buffered.isNotEmpty) {
          bufferedMs = controller.value.buffered.last.end.inMilliseconds
              .clamp(0.0, durationMs)
              .toDouble();
        }

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black87],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
          ),
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
          child: Row(
            children: [
              if (isLive) ...[
                const Text('● LIVE',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
              ] else ...[
                Text(_formatDuration(position),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.0,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14.0),
                      activeTrackColor: widget.progressBarColor,
                      inactiveTrackColor: Colors.white30,
                      thumbColor: Colors.white,
                      overlayColor:
                          widget.progressBarColor.withValues(alpha: 0.3),
                    ),
                    child: Slider(
                      value: positionMs,
                      min: 0.0,
                      max: durationMs,
                      secondaryTrackValue: bufferedMs,
                      onChanged: !isInitialized
                          ? null
                          : (value) => _chewieController
                              ?.seekTo(Duration(milliseconds: value.round())),
                      onChangeStart:
                          !isInitialized ? null : (_) => _cancelAllTimers(),
                      onChangeEnd: !isInitialized
                          ? null
                          : (_) => _startHideControlsTimer(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(_formatDuration(duration),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
              qualityButton,
              pipButton,
              IconButton(
                icon: const Icon(Icons.aspect_ratio, color: Colors.white),
                onPressed: () {
                  if (!mounted) { return; }
                  setState(() {
                    _currentVideoSize = VideoSize.values[
                        (_currentVideoSize.index + 1) %
                            VideoSize.values.length];
                  });
                  _startHideControlsTimer();
                },
              ),
              // Fullscreen Toggle (Desktop only)
              if (isDesktop)
                IconButton(
                  icon: Icon(
                    _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  onPressed: () async {
                    _isFullScreen = !_isFullScreen;
                    await windowManager.setFullScreen(_isFullScreen);
                    if (mounted) setState(() {});
                    _startHideControlsTimer();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer() {
    if (kIsWeb) {
      if (_currentStreamUrl != null) {
        return SizedBox.expand(
          child: VidstackPlayerWidget(
            url: _currentStreamUrl!,
            streamLinks: _validStreamLinks,
          ),
        );
      }
      return Container(color: Colors.black);
    }

    // DESKTOP: Use MediaKit Video widget
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (_mediaKitController != null) {
        // Cover mode: Fill entire screen (may crop video edges)
        if (_currentVideoSize == VideoSize.cover) {
          return SizedBox.expand(
            child: Video(
              controller: _mediaKitController!,
              controls: null,
              fit: BoxFit.cover, // Fill entire space
            ),
          );
        }

        // Other modes: Use aspect ratio
        final videoWidth = _mediaKitPlayer?.state.width ?? 16;
        final videoHeight = _mediaKitPlayer?.state.height ?? 9;
        final videoAspectRatio = videoWidth > 0 && videoHeight > 0
            ? videoWidth / videoHeight
            : 16 / 9;

        return Center(
          child: AspectRatio(
            aspectRatio:
                _getAspectRatioForSize(_currentVideoSize, videoAspectRatio),
            child: Video(
              controller: _mediaKitController!,
              controls: null,
              fit: BoxFit.contain, // Fit within bounds
            ),
          ),
        );
      }
      return Container(color: Colors.black);
    }

    // MOBILE: Use Chewie
    final chewie = _chewieController;
    if (chewie == null || !chewie.videoPlayerController.value.isInitialized) {
      return Container(color: Colors.black);
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _getAspectRatioForSize(
          _currentVideoSize,
          chewie.videoPlayerController.value.aspectRatio,
        ),
        child: Chewie(
          key: _playerKey,
          controller: chewie,
        ),
      ),
    );
  }

  double _getAspectRatioForSize(VideoSize size, double videoAspectRatio) {
    if (videoAspectRatio <= 0) return 16 / 9; // Fallback
    switch (size) {
      case VideoSize.fitWidth:
        return videoAspectRatio;
      case VideoSize.cover:
        final screenRatio = MediaQuery.of(context).size.aspectRatio;
        return screenRatio; // This will fill the screen
      case VideoSize.ratio16_9:
        return 16 / 9;
      case VideoSize.ratio18_9:
        return 18 / 9;
      case VideoSize.ratio4_3:
        return 4 / 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    // WEB/PWA: Handle Back Button to Ensure Video Closes properly
    return PopScope(
      canPop: false, // Handle manually
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) { return; }
        // Logic: Just pop the navigator which will trigger dispose() and stop video
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControlsVisibility,
          onDoubleTapDown: _handleDoubleTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildVideoPlayer(),
              // MODIFIED: The custom controls are now always in the stack,
              // allowing the GestureDetector to toggle their visibility at any time.
              // Their actual visibility is handled internally by _isControlsVisible and the FadeTransition.
              _buildControls(context),
              if (_isLoading && !_hasError)
                CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(widget.progressBarColor)),
              if (_hasError) _buildErrorWidget("حدث خطأ أثناء تشغيل الفيديو."),
            ],
          ),
        ),
      ),
    );
  }
}

extension DurationClamp on Duration {
  Duration clamp(Duration lowerLimit, Duration upperLimit) {
    if (this < lowerLimit) { return lowerLimit; }
    if (this > upperLimit) { return upperLimit; }
    return this;
  }
}
