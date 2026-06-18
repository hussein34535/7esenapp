import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:hesen/utils/pip_helper.dart';
import 'package:hesen/services/auth_service.dart';
import 'package:hesen/player_utils/player_stream_resolver.dart';
import 'package:hesen/player_utils/stream_details.dart';
import 'package:hesen/player_utils/dash_helper.dart';
import 'package:hesen/player_utils/video_player_creator.dart';

Future<String?> _downloadAudioToTemp(String audioUrl, Map<String, String> headers) async {
  try {
    debugPrint('[HESEN PLAYER] Downloading audio track with headers to temp file...');
    final response = await http.get(Uri.parse(audioUrl), headers: headers).timeout(
      const Duration(seconds: 30),
    );
    if (response.statusCode != 200) {
      debugPrint('[HESEN PLAYER] Audio download failed: HTTP ${response.statusCode}');
      return null;
    }
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/hesen_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    debugPrint('[HESEN PLAYER] Audio downloaded to: ${file.path} (${response.bodyBytes.length} bytes)');
    return file.path;
  } catch (e) {
    debugPrint('[HESEN PLAYER] Audio download error: $e');
    return null;
  }
}

class HesenPlayerController extends ChangeNotifier {
  final String initialUrl;
  final List<Map<String, dynamic>> streamLinks;
  final bool isLocked;
  final int? contentId;
  final String? category;
  final String userAgent;
  final VoidCallback onErrorCallback;

  // Controllers
  VideoPlayerController? videoPlayerController;
  ChewieController? chewieController;
  Player? mediaKitPlayer;
  VideoController? mediaKitController;

  // State flags
  bool isLoading = true;
  bool hasError = false;
  bool isAccessBlocked = false; // Tells UI to show premium dialog
  List<Map<String, dynamic>> validStreamLinks = [];
  String? currentStreamUrl;
  int selectedStreamIndex = -1;
  bool isCurrentStreamApi = false;
  List<Map<String, dynamic>> fetchedApiQualities = [];
  int selectedApiQualityIndex = -1;
  bool isAutoRetrying = false;
  bool isPlayerInitializing = false;

  // Timers and Subscriptions
  Timer? hideControlsTimer;
  Timer? bufferingRetryTimer;
  Duration? lastPosition;
  int autoRetryAttempt = 0;
  StreamSubscription? mediaKitErrorSub;
  StreamSubscription<Duration>? mediaKitPositionSub;
  StreamSubscription<List<ConnectivityResult>>? connectivitySubscription;

  HesenPlayerController({
    required this.initialUrl,
    required this.streamLinks,
    required this.isLocked,
    required this.contentId,
    required this.category,
    required this.userAgent,
    required this.onErrorCallback,
  }) {
    if (isLocked && contentId != null) {
      isLoading = true;
      unlockAndPlay();
    } else {
      isLoading = true;
      validStreamLinks = List<Map<String, dynamic>>.from(streamLinks);
      currentStreamUrl = initialUrl;
      // Defer player init to let page transition animation complete
      Future.delayed(const Duration(milliseconds: 400), () {
        if (currentStreamUrl != null) {
          initializePlayerInternal(currentStreamUrl!);
        }
      });
    }
    fetchUserDataAndCheckAccess();
  }

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? get userData => _userData;

  Future<void> fetchUserDataAndCheckAccess() async {
    final authService = AuthService();
    _userData = await authService.getUserData();
    checkAccess();
  }

  Future<void> checkAccess() async {
    final authService = AuthService();
    final isSubscribed = await authService.checkSubscription();

    // If passed externally as locked
    if (isLocked) {
      if (isSubscribed) {
        unlockAndPlay();
      } else {
        isAccessBlocked = true;
        notifyListeners();
      }
      return;
    }

    bool hasPlayableLinks = streamLinks.any(
        (link) => link['url'] != null && link['url'].toString().isNotEmpty);

    if (!hasPlayableLinks) {
      hasError = true;
      isLoading = false;
      notifyListeners();
      onErrorCallback();
    } else {
      initializeScreen();
    }
  }

  Future<void> unlockAndPlay() async {
    if (contentId == null || category == null) {
      return;
    }

    try {
      final authService = AuthService();
      final unlockedData = await authService.unlockPremiumContent(
        type: category!,
        id: contentId!,
      );

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
          validStreamLinks = newStreamLinks;
          currentStreamUrl = newStreamLinks[0]['url']?.toString();
          isAccessBlocked = false;
          notifyListeners();

          if (currentStreamUrl != null) {
            initializePlayerInternal(currentStreamUrl!);
          }
          return;
        }
      }

      // If we reach here, unlock failed or produced no links
      hasError = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Internal Unlock Error: $e");
      hasError = true;
      notifyListeners();
    }
  }

  Future<void> initializeScreen() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (initialUrl.trim().isEmpty) {
      onErrorCallback();
      return;
    }
    prepareAndInitializePlayer();
  }

  void prepareAndInitializePlayer() {
    validStreamLinks = PlayerStreamResolver.validateStreamLinks(streamLinks);

    String? urlToPlay;
    selectedStreamIndex = -1;

    if (validStreamLinks.isEmpty) {
      if (initialUrl.isNotEmpty) {
        urlToPlay = initialUrl;
      }
    } else {
      selectedStreamIndex = 0;
      urlToPlay = validStreamLinks[0]['url']?.toString();
    }

    if (urlToPlay == null || urlToPlay.isEmpty) {
      isLoading = false;
      hasError = true;
      notifyListeners();
      return;
    }

    currentStreamUrl = urlToPlay;
    isCurrentStreamApi =
        currentStreamUrl!.startsWith('https://7esentv-match.vercel.app') ||
            currentStreamUrl!.startsWith('https://okru-api.vercel.app/api') ||
            currentStreamUrl!.contains('ok.ru/video/') ||
            currentStreamUrl!.contains('ok.ru/live/') ||
            currentStreamUrl!.contains('youtube.com') ||
            currentStreamUrl!.contains('youtu.be') ||
            (currentStreamUrl!.contains('okcdn.ru') &&
                currentStreamUrl!.split('?')[0].endsWith('.m3u8'));

    fetchedApiQualities = [];
    selectedApiQualityIndex = -1;

    if (!kIsWeb) {
      notifyListeners();
    }
    initializePlayerInternal(currentStreamUrl!);
  }

  Future<void> initializePlayerInternal(String sourceUrl,
      {String? specificQualityUrl, String? specificAudioUrl, int? specificQualityIndex, Duration? startAt}) async {
    if (isPlayerInitializing) {
      debugPrint('[HESEN PLAYER] ⚠️ Already initializing, skipping duplicate call for: $sourceUrl');
      return;
    }
    isPlayerInitializing = true;


    if (!kIsWeb) {
      WakelockPlus.enable();
    }

    debugPrint('[HESEN PLAYER] Initializing player with sourceUrl: $sourceUrl');
    await releaseControllers();
    await Future.delayed(const Duration(milliseconds: 250));

    if (!isLoading) {
      isLoading = true;
      notifyListeners();
    }

    final String urlToProcess = specificQualityUrl ?? sourceUrl;
    Map<String, String> httpHeaders = {
      'User-Agent': userAgent,
      'Referer': 'https://7esentv.com/',
    };

    try {
      StreamDetails streamDetails;
      if (specificQualityUrl != null) {
        streamDetails = StreamDetails(
          videoUrlToLoad: specificQualityUrl,
          audioUrlToLoad: specificAudioUrl,
          fetchedQualities: fetchedApiQualities,
          selectedQualityIndex: specificQualityIndex ?? selectedApiQualityIndex,
        );
      } else {
        streamDetails = await PlayerStreamResolver.resolve(urlToProcess, isWeb: kIsWeb);
      }

      var videoUrlToLoad = streamDetails.videoUrlToLoad;
      var audioUrlToLoad = streamDetails.audioUrlToLoad;

      if (videoUrlToLoad == null || videoUrlToLoad.isEmpty) {
        isLoading = false;
        hasError = true;
        isPlayerInitializing = false;
        notifyListeners();
        return;
      }

      // Write manifest data URL to temp file for native platforms
      if (!kIsWeb && videoUrlToLoad.startsWith('data:application/dash+xml;base64,')) {
        videoUrlToLoad = await writeDashManifestToTemp(videoUrlToLoad);
      }

      final String finalVideoUrl = videoUrlToLoad;

      // Google Video URLs might reject requests with incorrect Referer
      if (finalVideoUrl.contains('googlevideo.com')) {
        httpHeaders['Referer'] = 'https://www.youtube.com/';
        // We keep User-Agent because Google servers require it
      }

      fetchedApiQualities = streamDetails.fetchedQualities;
      selectedApiQualityIndex = streamDetails.selectedQualityIndex;

      if (kIsWeb) {
        currentStreamUrl = finalVideoUrl;
        isLoading = false;
        hasError = false;
        isPlayerInitializing = false;
        notifyListeners();
        return;
      }

      VideoFormat? formatHint;
      if (finalVideoUrl.startsWith('data:application/dash+xml')) {
        formatHint = VideoFormat.dash;
      } else if (finalVideoUrl.toLowerCase().contains('.m3u8')) {
        formatHint = VideoFormat.hls;
      }

      // ====== DESKTOP: Use MediaKit (MPV Backend) ======
      if (!kIsWeb &&
          ((!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ||
              (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) ||
              (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS))) {
        debugPrint('[HESEN PLAYER] Desktop detected - Using MediaKit');
        try {
          mediaKitPlayer ??= Player();
          mediaKitController ??= VideoController(mediaKitPlayer!);

          mediaKitErrorSub?.cancel();
          mediaKitErrorSub = mediaKitPlayer!.stream.error.listen((error) {
            debugPrint('[MEDIAKIT ERROR] $error');
            if (!_isDisposed && !isAutoRetrying) {
              retryMediaKitPlayback(finalVideoUrl, httpHeaders);
            }
          });

          mediaKitPositionSub?.cancel();
          mediaKitPositionSub = mediaKitPlayer!.stream.position.listen((pos) {
            if (!_isDisposed) {
              notifyListeners();
            }
          });

          await mediaKitPlayer!.open(
            Media(finalVideoUrl, httpHeaders: httpHeaders),
            play: true,
          );

          if (audioUrlToLoad != null && audioUrlToLoad.isNotEmpty) {
            debugPrint('[HESEN PLAYER] Setting external audio track: $audioUrlToLoad');
            mediaKitErrorSub?.cancel();

            String? audioPath;
            if (audioUrlToLoad.startsWith('http')) {
              audioPath = await _downloadAudioToTemp(audioUrlToLoad, httpHeaders);
            } else {
              audioPath = audioUrlToLoad;
            }

            if (audioPath != null) {
              try {
                await mediaKitPlayer!.setAudioTrack(
                  AudioTrack.uri(audioPath),
                );
                debugPrint('[HESEN PLAYER] Audio track set successfully.');
              } catch (e) {
                debugPrint('[HESEN PLAYER] Audio track failed (non-fatal): $e');
              }
            } else {
              debugPrint('[HESEN PLAYER] Audio download failed, continuing without external audio.');
            }

            await Future.delayed(const Duration(seconds: 3));
            if (!_isDisposed) {
              mediaKitErrorSub?.cancel();
              mediaKitErrorSub = mediaKitPlayer!.stream.error.listen((error) {
                debugPrint('[MEDIAKIT ERROR] $error');
                if (!_isDisposed && !isAutoRetrying) {
                  retryMediaKitPlayback(finalVideoUrl, httpHeaders);
                }
              });
            }
          }

          isLoading = false;
          hasError = false;
          isAutoRetrying = false;
          isPlayerInitializing = false;
          notifyListeners();
        } catch (e) {
          debugPrint('[MEDIAKIT INIT ERROR] $e');
          if (!isAutoRetrying) {
            retryMediaKitPlayback(finalVideoUrl, httpHeaders);
          }
        }
        return;
      }

      // ====== MOBILE: Use VideoPlayer + Chewie ======
      videoPlayerController = createVideoPlayerController(
          finalVideoUrl,
          httpHeaders: httpHeaders,
          formatHint: formatHint);
      videoPlayerController!.addListener(videoPlayerListener);
      await videoPlayerController!.initialize();
      await videoPlayerController!.setLooping(false);

      final aspectRatio = videoPlayerController!.value.aspectRatio;
      chewieController = ChewieController(
        videoPlayerController: videoPlayerController!,
        autoPlay: true,
        looping: false,
        startAt: startAt,
        aspectRatio:
            (aspectRatio <= 0 || aspectRatio.isNaN) ? 16 / 9 : aspectRatio,
        showControls: false,
        errorBuilder: (context, errorMessage) => Center(
          child: Text(errorMessage, style: const TextStyle(color: Colors.white)),
        ),
      );

      isLoading = false;
      hasError = false;
      autoRetryAttempt = 0;
      isPlayerInitializing = false;
      notifyListeners();
    } catch (e) {
      isPlayerInitializing = false;
      debugPrint('[HESEN PLAYER] ERROR in initializePlayerInternal: $e');
      if (autoRetryAttempt < 1) {
        autoRetryAttempt++;
        debugPrint('[HESEN PLAYER] Retrying same stream (attempt ${autoRetryAttempt + 1})');
        await Future.delayed(const Duration(milliseconds: 1000));
        initializePlayerInternal(sourceUrl,
            specificQualityUrl: specificQualityUrl, specificAudioUrl: specificAudioUrl, specificQualityIndex: specificQualityIndex, startAt: startAt);
      } else {
        if (validStreamLinks.length > 1) {
          tryNextStream();
        } else {
          hasError = true;
          isLoading = false;
          notifyListeners();
        }
      }
    }
  }

  Future<void> retryMediaKitPlayback(
      String url, Map<String, String> headers) async {
    if (isAutoRetrying) {
      return;
    }

    autoRetryAttempt++;
    if (autoRetryAttempt > 2) {
      debugPrint('[HESEN PLAYER] MediaKit persistent failure after retries.');
      autoRetryAttempt = 0;
      isAutoRetrying = false;
      tryNextStream();
      return;
    }

    isAutoRetrying = true;
    debugPrint('[HESEN PLAYER] MediaKit retry attempt $autoRetryAttempt for: $url');

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mediaKitPlayer != null) {
      try {
        await mediaKitPlayer!
            .open(Media(url, httpHeaders: headers), play: true);
        isLoading = false;
        currentStreamUrl = url;
        hasError = false;
        isAutoRetrying = false;
        notifyListeners();
      } catch (e) {
        debugPrint('[HESEN PLAYER] Retry $autoRetryAttempt failed: $e');
        isAutoRetrying = false;
        retryMediaKitPlayback(url, headers);
      }
    } else {
      isAutoRetrying = false;
    }
  }

  Future<void> releaseControllers() async {
    bufferingRetryTimer?.cancel();
    final chewie = chewieController;
    final video = videoPlayerController;
    chewieController = null;
    videoPlayerController = null;
    chewie?.dispose();
    if (video != null) {
      video.removeListener(videoPlayerListener);
      video.dispose();
    }

    if (mediaKitPlayer != null) {
      await mediaKitPlayer!.dispose();
      mediaKitPlayer = null;
      mediaKitController = null;
    }

    // Clean up temp audio files
    try {
      final tempDir = Directory.systemTemp;
      final entries = tempDir.listSync();
      for (final entry in entries) {
        if (entry is File && entry.path.contains('hesen_audio_')) {
          await entry.delete();
        }
      }
    } catch (_) {}
  }

  void videoPlayerListener() {
    if (videoPlayerController == null ||
        !videoPlayerController!.value.isInitialized) return;
    if (videoPlayerController!.value.hasError) {
      if (!hasError) {
        hasError = true;
        isLoading = false;
        notifyListeners();
        tryNextStream();
      }
      return;
    }

    final value = videoPlayerController!.value;
    final isBuffering = value.isBuffering;

    if (isBuffering && !value.isPlaying) {
      if (bufferingRetryTimer == null || !bufferingRetryTimer!.isActive) {
        bufferingRetryTimer =
            Timer(const Duration(seconds: 15), handleBufferingTimeout);
      }
    } else {
      bufferingRetryTimer?.cancel();
    }

    if (isBuffering != isLoading && !hasError) {
      isLoading = isBuffering;
      notifyListeners();
    }
  }

  void handleBufferingTimeout() {
    if (currentStreamUrl == null) {
      return;
    }

    final isStuck = videoPlayerController?.value.isBuffering == true &&
        videoPlayerController?.value.isPlaying == false;

    if (isStuck) {
      debugPrint('[HESEN PLAYER] Buffering timed out. Retrying the same stream.');
      lastPosition = videoPlayerController?.value.position;
      initializePlayerInternal(currentStreamUrl!, startAt: lastPosition);
    }
  }

  Future<void> tryNextStream() async {
    if (validStreamLinks.length <= 1) {
      return;
    }
    autoRetryAttempt = 0;
    final int nextIndex = (selectedStreamIndex + 1) % validStreamLinks.length;
    await Future.delayed(const Duration(milliseconds: 500));
    await Future.delayed(const Duration(milliseconds: 500));
    changeStream(nextIndex, isAutoRetry: true);
  }

  Future<void> changeStream(int newStreamIndex,
      {bool isAutoRetry = false}) async {
    if (newStreamIndex == selectedStreamIndex ||
        newStreamIndex < 0 ||
        newStreamIndex >= validStreamLinks.length) return;

    final Duration? startAt = videoPlayerController?.value.position;
    if (!isAutoRetry) {
      autoRetryAttempt = 0;
    }
    cancelAllTimers();

    final newStreamData = validStreamLinks[newStreamIndex];
    final newStreamUrl = newStreamData['url']?.toString();

    if (newStreamUrl == null || newStreamUrl.isEmpty) {
      return;
    }

    if (kIsWeb) {
      final streamDetails = await PlayerStreamResolver.resolve(newStreamUrl, isWeb: kIsWeb);
      isLoading = false;
      hasError = false;
      selectedStreamIndex = newStreamIndex;
      currentStreamUrl = streamDetails.videoUrlToLoad;
      isCurrentStreamApi = currentStreamUrl != null && (
          currentStreamUrl!.startsWith('https://7esentv-match.vercel.app') ||
          currentStreamUrl!.startsWith('https://okru-api.vercel.app/api') ||
          currentStreamUrl!.contains('ok.ru/video/') ||
          currentStreamUrl!.contains('ok.ru/live/') ||
          currentStreamUrl!.contains('youtube.com') ||
          currentStreamUrl!.contains('youtu.be') ||
          (currentStreamUrl!.contains('okcdn.ru') &&
              currentStreamUrl!.split('?')[0].endsWith('.m3u8'))
      );
      fetchedApiQualities = streamDetails.fetchedQualities;
      selectedApiQualityIndex = streamDetails.selectedQualityIndex;
      notifyListeners();
      return;
    }

    selectedStreamIndex = newStreamIndex;
    await initializePlayerInternal(newStreamUrl, startAt: startAt);
  }

  Future<void> changeApiQuality(int newQualityIndex) async {
    if (!_isDisposed && (
        !isCurrentStreamApi ||
        newQualityIndex == selectedApiQualityIndex ||
        newQualityIndex < 0 ||
        newQualityIndex >= fetchedApiQualities.length)) return;

    final Duration? startAt = mediaKitPlayer?.state.position ?? videoPlayerController?.value.position;
    final newQualityData = fetchedApiQualities[newQualityIndex];
    final specificQualityUrl = newQualityData['url']?.toString();
    final specificAudioUrl = newQualityData['audioUrl']?.toString();
    if (specificQualityUrl == null || specificQualityUrl.isEmpty) {
      return;
    }

    if (kIsWeb) {
      selectedApiQualityIndex = newQualityIndex;
      notifyListeners();
      initializePlayerInternal(currentStreamUrl!,
          specificQualityUrl: specificQualityUrl, specificAudioUrl: specificAudioUrl, specificQualityIndex: newQualityIndex, startAt: startAt);
      return;
    }

    isLoading = true;
    hasError = false;
    selectedApiQualityIndex = newQualityIndex;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 50));
    await initializePlayerInternal(currentStreamUrl!,
        specificQualityUrl: specificQualityUrl, specificAudioUrl: specificAudioUrl, specificQualityIndex: newQualityIndex, startAt: startAt);
  }

  void cancelAllTimers() {
    hideControlsTimer?.cancel();
    bufferingRetryTimer?.cancel();
  }

  bool _isDisposed = false;
  @override
  void dispose() {
    _isDisposed = true;
    cancelAllTimers();
    mediaKitErrorSub?.cancel();
    mediaKitPositionSub?.cancel();
    connectivitySubscription?.cancel();
    if (!kIsWeb) {
      WakelockPlus.disable();
    }
    releaseControllers();
    super.dispose();
  }
}
