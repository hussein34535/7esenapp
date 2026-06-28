import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hesen/utils/pip_helper.dart'; // Replaces android_pip
import 'package:window_manager/window_manager.dart'; // Window control for fullscreen

import 'package:hesen/services/auth_service.dart';
import 'package:hesen/screens/login_screen.dart';
import 'package:hesen/widgets/player/premium_dialog.dart';
import 'package:hesen/widgets/player/player_controls.dart';
import 'package:hesen/widgets/player/player_video_view.dart';
import 'package:hesen/player_utils/hesen_player_controller.dart';

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
  late HesenPlayerController _controller;
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  UniqueKey _playerKey = UniqueKey();

  // Screen UI state
  bool _isControlsVisible = false;
  bool _isFullScreen = false;
  bool _isCurrentlyInPip = false;
  late PipHelper _pipHelper;
  VideoSize _currentVideoSize = VideoSize.fitWidth;
  Timer? _hideControlsTimer;
  int _premiumRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WakelockPlus.enable();
    }

    _pipHelper = PipHelper(
      onPipEntered: () {
        if (!mounted) {
          return;
        }
        setState(() => _isCurrentlyInPip = true);
        _hideControls(animate: false);
      },
      onPipExited: () {
        if (!mounted) {
          return;
        }
        setState(() => _isCurrentlyInPip = false);
        final videoController = _controller.videoPlayerController;
        if (videoController != null &&
            !videoController.value.isPlaying) {
          videoController.play();
        }
      },
      onPipAction: (action) {
        if (!mounted) {
          return;
        }
        final videoController = _controller.videoPlayerController;
        if (videoController == null) {
          return;
        }
        final actionStr = action.toString();
        if (actionStr.contains('play')) {
          videoController.play();
        } else if (actionStr.contains('pause')) {
          videoController.pause();
        }
      },
    );

    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _opacityAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    _controller = HesenPlayerController(
      initialUrl: widget.initialUrl,
      streamLinks: widget.streamLinks,
      isLocked: widget.isLocked,
      contentId: widget.contentId,
      category: widget.category,
      userAgent: _userAgent,
      onErrorCallback: () {
        if (mounted) {
          _showError("عذراً، لا يوجد بث متاح حالياً لهذه القناة.");
          Navigator.pop(context);
        }
      },
    );

    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller.isAccessBlocked) {
      _controller.isAccessBlocked = false; // Reset block flag to prevent dialog loop
      _showPremiumDialog();
    } else {
      setState(() {});
    }
  }

  Future<void> _showPremiumDialog() async {
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PremiumDialog(
        userData: _controller.userData,
        currentUser: AuthService().currentUser,
      ),
    );

    if (!mounted) return;

    if (result == 1) {
      final success = await AuthService().startTrial();
      if (success) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم تفعيل التجربة المجانية لمدة 24 ساعة!')),
        );
        _controller.unlockAndPlay();
      } else {
        if (!mounted) return;
        if (_premiumRetries < 1) {
          _premiumRetries++;
          _showPremiumDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تفعيل التجربة. يرجى المحاولة لاحقاً.')),
          );
          if (mounted) Navigator.of(context).pop();
        }
      }
    } else if (result == 2) {
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      _controller.fetchUserDataAndCheckAccess();
    } else if (result == 3) {
      if (!mounted) {
        return;
      }
      bool hasFree = widget.streamLinks.any((l) =>
          l['name']?.toString().toLowerCase().contains('free') == true ||
          l['name']?.toString().toLowerCase().contains('sd') == true);
      if (hasFree) {
        _controller.initializeScreen();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('عذراً، الجودة المجانية غير متاحة لهذا الحدث حالياً.')),
        );
        _showPremiumDialog();
      }
    } else {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _animationController.dispose();
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final videoController = _controller.videoPlayerController;
    if (videoController == null || !videoController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (videoController.value.isPlaying && !_isCurrentlyInPip) {
        videoController.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!videoController.value.isPlaying) {
        videoController.play();
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool urlChanged = widget.initialUrl != oldWidget.initialUrl;
    final bool linksChanged = !listEquals(widget.streamLinks, oldWidget.streamLinks);
    if (urlChanged || linksChanged) {
      debugPrint('[HESEN PLAYER] didUpdateWidget: URL/links changed. Re-initializing...');
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
      _controller = HesenPlayerController(
        initialUrl: widget.initialUrl,
        streamLinks: widget.streamLinks,
        isLocked: widget.isLocked,
        contentId: widget.contentId,
        category: widget.category,
        userAgent: _userAgent,
        onErrorCallback: () {
          if (mounted) {
            _showError("عذراً، لا يوجد بث متاح حالياً لهذه القناة.");
            Navigator.pop(context);
          }
        },
      );
      _controller.addListener(_onControllerChanged);
      _showControls();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer =
        Timer(const Duration(seconds: 4), () => _hideControls(animate: true));
  }

  void _hideControls({required bool animate}) {
    if (!mounted || !_isControlsVisible) {
      return;
    }
    if (animate) {
      _animationController.reverse();
    } else {
      _animationController.value = 0.0;
    }
    _setControlsVisibility(false);
  }

  void _toggleControlsVisibility() {
    if (_isControlsVisible) {
      _hideControls(animate: true);
    } else {
      _showControls();
    }
  }

  void _showControls() {
    if (!mounted || _isControlsVisible) {
      return;
    }
    _animationController.forward();
    _setControlsVisibility(true);
    _startHideControlsTimer();
  }

  void _setControlsVisibility(bool isVisible) {
    if (mounted) {
      setState(() {
        _isControlsVisible = isVisible;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message), duration: const Duration(seconds: 5)));
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final bool isDesktop = !kIsWeb &&
        ((!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ||
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) ||
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS));

    final currentPosition = isDesktop
        ? (_controller.mediaKitPlayer?.state.position ?? Duration.zero)
        : (_controller.videoPlayerController?.value.position ?? Duration.zero);
    final totalDuration = isDesktop
        ? (_controller.mediaKitPlayer?.state.duration ?? Duration.zero)
        : (_controller.videoPlayerController?.value.duration ?? Duration.zero);

    if (!mounted || totalDuration <= Duration.zero) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.localPosition.dx;
    const seekDuration = Duration(seconds: 10);
    Duration newPosition;
    if (tapPosition < screenWidth / 3) {
      newPosition =
          (currentPosition - seekDuration).clamp(Duration.zero, totalDuration);
    } else if (tapPosition > screenWidth * 2 / 3) {
      newPosition =
          (currentPosition + seekDuration).clamp(Duration.zero, totalDuration);
    } else {
      _toggleControlsVisibility();
      return;
    }

    if (isDesktop) {
      _controller.mediaKitPlayer?.seek(newPosition);
    } else {
      _controller.chewieController?.seekTo(newPosition);
    }
    _cancelAllTimers();
    _showControls();
  }

  void _cancelAllTimers() {
    _hideControlsTimer?.cancel();
  }

  Widget _buildPlayerControls(BuildContext context) {
    final controller = _controller.videoPlayerController;
    final bool isDesktop = !kIsWeb &&
        ((!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ||
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) ||
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS));

    final bool isLiveUrl =
        (_controller.currentStreamUrl?.toLowerCase().contains('.m3u8') ?? false) ||
            (_controller.currentStreamUrl
                    ?.contains('7esenlink.vercel.app/api/stream') ??
                false);

    final position = isDesktop
        ? (_controller.mediaKitPlayer?.state.position ?? Duration.zero)
        : (controller?.value.isInitialized == true
            ? controller!.value.position
            : Duration.zero);
    final duration = isDesktop
        ? (_controller.mediaKitPlayer?.state.duration ?? Duration.zero)
        : (controller?.value.isInitialized == true
            ? controller!.value.duration
            : Duration.zero);

    final bool isLive = isDesktop
        ? isLiveUrl
        : ((controller?.value.isInitialized ?? false) && duration.inMilliseconds == 0);

    double bufferedMs = 0.0;
    if (!isDesktop &&
        (controller?.value.isInitialized ?? false) &&
        !isLive &&
        controller!.value.buffered.isNotEmpty) {
      final double durationMs = duration.inMilliseconds.toDouble() > 0
          ? duration.inMilliseconds.toDouble()
          : 1.0;
      bufferedMs = controller.value.buffered.last.end.inMilliseconds
          .clamp(0.0, durationMs)
          .toDouble();
    }

    final bool isPlaying = isDesktop
        ? (_controller.mediaKitPlayer?.state.playing ?? false)
        : (controller?.value.isPlaying ?? false);

    return PlayerControls(
      opacityAnimation: _opacityAnimation,
      isControlsVisible: _isControlsVisible,
      isLoading: _controller.isLoading,
      hasError: _controller.hasError,
      isFullScreen: _isFullScreen,
      isCurrentStreamApi: _controller.isCurrentStreamApi,
      selectedStreamIndex: _controller.selectedStreamIndex,
      selectedApiQualityIndex: _controller.selectedApiQualityIndex,
      validStreamLinks: _controller.validStreamLinks,
      fetchedApiQualities: _controller.fetchedApiQualities,
      currentStreamUrl: _controller.currentStreamUrl,
      position: position,
      duration: duration,
      bufferedMs: bufferedMs,
      isDesktop: isDesktop,
      isLive: isLive,
      isPlaying: isPlaying,
      progressBarColor: widget.progressBarColor,
      currentVideoSize: _currentVideoSize,
      volume: isDesktop
          ? (_controller.mediaKitPlayer?.state.volume ?? 100.0) / 100.0
          : (controller?.value.volume ?? 1.0),
      downloadProgress: _controller.downloadProgress,
      onVolumeChanged: (v) {
        if (isDesktop) {
          _controller.mediaKitPlayer?.setVolume(v * 100.0);
        } else {
          controller?.setVolume(v);
        }
      },
      onPlayPauseToggle: () {
        if (isDesktop) {
          if (_controller.mediaKitPlayer != null) {
            if (_controller.mediaKitPlayer!.state.playing) {
              _controller.mediaKitPlayer!.pause();
            } else {
              _controller.mediaKitPlayer!.play();
            }
          }
        } else {
          if (controller != null) {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
          }
        }
        _cancelAllTimers();
        _startHideControlsTimer();
      },
      onBackPress: () async {
        if (isDesktop && _isFullScreen) {
          await windowManager.setFullScreen(false);
          _isFullScreen = false;
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      onStreamChanged: (index) {
        _controller.changeStream(index);
      },
      onQualityChanged: (qualityIndex) {
        _controller.changeApiQuality(qualityIndex);
      },
      onAspectRatioChanged: () {
        setState(() {
          _currentVideoSize = VideoSize.values[
              (_currentVideoSize.index + 1) % VideoSize.values.length];
        });
        _startHideControlsTimer();
      },
      onFullScreenToggle: () async {
        _isFullScreen = !_isFullScreen;
        await windowManager.setFullScreen(_isFullScreen);
        if (mounted) setState(() {});
        _startHideControlsTimer();
      },
      onPipToggle: () async {
        if (controller == null) return;
        try {
          final asp = controller.value.aspectRatio;
          int n = 16, d = 9;
          if (asp > 0 && asp.isFinite) {
            n = (asp * 100).round();
            d = 100;
          }
          await _pipHelper.enterPipMode(n, d);
        } catch (e) {
          _showError("Error: $e");
        }
      },
      onSeek: (value) {
        final targetPosition = Duration(milliseconds: value.round());
        if (isDesktop) {
          _controller.mediaKitPlayer?.seek(targetPosition);
        } else {
          _controller.chewieController?.seekTo(targetPosition);
        }
      },
      onSeekStart: () {
        _cancelAllTimers();
      },
      onSeekEnd: () {
        _startHideControlsTimer();
      },
    );
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
              if (mounted && _controller.currentStreamUrl != null) {
                _controller.initializePlayerInternal(_controller.currentStreamUrl!);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
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
              PlayerVideoView(
                currentStreamUrl: _controller.currentStreamUrl,
                isCurrentStreamApi: _controller.isCurrentStreamApi,
                fetchedApiQualities: _controller.fetchedApiQualities,
                validStreamLinks: _controller.validStreamLinks,
                mediaKitController: _controller.mediaKitController,
                mediaKitPlayer: _controller.mediaKitPlayer,
                chewieController: _controller.chewieController,
                currentVideoSize: _currentVideoSize,
                playerKey: _playerKey,
                screenAspectRatio: MediaQuery.of(context).size.aspectRatio,
                selectedStreamIndex: _controller.selectedStreamIndex,
                selectedApiQualityIndex: _controller.selectedApiQualityIndex,
              ),
              _buildPlayerControls(context),
              if (_controller.isLoading && !_controller.hasError)
                CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(widget.progressBarColor)),
              if (_controller.hasError) _buildErrorWidget("حدث خطأ أثناء تشغيل الفيديو."),
            ],
          ),
        ),
      ),
    );
  }
}

extension DurationClamp on Duration {
  Duration clamp(Duration lowerLimit, Duration upperLimit) {
    if (this < lowerLimit) {
      return lowerLimit;
    }
    if (this > upperLimit) {
      return upperLimit;
    }
    return this;
  }
}
