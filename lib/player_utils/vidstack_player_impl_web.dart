import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hesen/player_utils/video_player_web.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

class VidstackPlayerImpl extends StatefulWidget {
  final String url;
  final List<Map<String, dynamic>> streamLinks;

  const VidstackPlayerImpl({
    required this.url,
    this.streamLinks = const [],
    Key? key,
  }) : super(key: key);

  @override
  State<VidstackPlayerImpl> createState() => _VidstackPlayerImplState();
}

class _VidstackPlayerImplState extends State<VidstackPlayerImpl> {
  html.Element? _currentPlayer;
  html.Element? _linksContainer;
  Timer? _overlayTimer; // MASTER AUTO-HIDE TIMER
  Timer? _safetyTimer; // Safety timer for black screen
  bool _controlsVisible = true;
  int _retryCount = 0; // Track retries for current stream

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void didUpdateWidget(VidstackPlayerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url && _currentPlayer != null) {
      _retryCount = 0; // Reset on new URL
      _loadSource(widget.url);
      _updateActiveButton(widget.url);
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _safetyTimer?.cancel();
    super.dispose();
  }

  void _showControls() {
    _controlsVisible = true;
    _currentPlayer?.classes.add('controls-visible');
    // Sync with Native Controls
    _currentPlayer?.setAttribute('user-idle', 'false');
    _startHideTimer();
  }

  void _hideControls() {
    // Only hide if playing
    final isPaused = js_util.getProperty(_currentPlayer!, 'paused') ?? false;
    if (isPaused == true) return;

    _controlsVisible = false;
    _currentPlayer?.classes.remove('controls-visible');
    // Sync with Native Controls
    _currentPlayer?.setAttribute('user-idle', 'true');
    _overlayTimer?.cancel();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _startHideTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        // Enforce Hide on both Dart side and Native side
        _hideControls();
        _currentPlayer?.setAttribute('user-idle', 'true');
      }
    });
  }

  // Helper function to load source
  Future<void> _loadSource(String rawUrl) async {
    if (_currentPlayer == null) return;

    // CANCEL PREVIOUS SAFETY TIMER
    _safetyTimer?.cancel();
    // START NEW SAFETY TIMER (5 seconds for faster switching)
    _safetyTimer = Timer(const Duration(seconds: 5), () {
      print(
          '[VIDSTACK] ⚠️ Safety Timer Expired: Video did not start. Force-switching...');
      // Manually trigger error event logic
      _handleErrorLogic();
    });

    try {
      String finalUrl = rawUrl;

      // 1. Handle 7esenlink (JSON)
      if (finalUrl.contains('7esenlink.vercel.app')) {
        try {
          final jsonUri = Uri.parse(finalUrl).replace(queryParameters: {
            ...Uri.parse(finalUrl).queryParameters,
            'json': 'true'
          });
          final request = await html.HttpRequest.request(jsonUri.toString());
          final jsonResponse =
              js.context['JSON'].callMethod('parse', [request.responseText]);
          if (jsonResponse['url'] != null) {
            finalUrl = jsonResponse['url'];
          }
        } catch (e) {
          print('[VIDSTACK] Error resolving 7esenlink: $e');
        }
      }

      // 2. Handle IPTV (TS -> HLS)
      if (finalUrl.contains(':8080') ||
          (finalUrl.contains(':80') && !finalUrl.contains('stream.php'))) {
        Uri uri = Uri.parse(finalUrl);
        List<String> segments = List.from(uri.pathSegments);
        if (segments.length == 3 && segments[0] != 'live') {
          segments.insert(0, 'live');
          String lastSegment = segments.last;
          if (!lastSegment.endsWith('.m3u8'))
            segments.last = '$lastSegment.m3u8';
          finalUrl = uri.replace(pathSegments: segments).toString();
        } else if (!finalUrl.endsWith('.m3u8')) {
          finalUrl = '$finalUrl.m3u8';
        }
      }

      // 3. Direct Play with CORS Proxy Fallback
      // Browsers BLOCK direct access to IPTV servers due to CORS security.
      // We MUST use a proxy to add the required Access-Control-Allow-Origin headers.

      String sourceToUse = finalUrl;

      // Check if we need a proxy (IPTV usually needs it)
      if (finalUrl.contains(':8080') || finalUrl.contains('.m3u8')) {
        // Use a high-performance specific proxy for IPTV
        const proxyPrefix = 'https://api.codetabs.com/v1/proxy?quest=';
        // const proxyPrefix = 'https://corsproxy.io/?'; // Backup

        print('[VIDSTACK] 🔒 Applying CORS Proxy for IPTV: $finalUrl');
        sourceToUse = '$proxyPrefix${Uri.encodeComponent(finalUrl)}';
      }

      print('[VIDSTACK] Final Source URL: $sourceToUse');

      final srcObj = js_util.newObject();
      js_util.setProperty(srcObj, 'src', sourceToUse);

      String mimeType = '';
      if (finalUrl.contains('.m3u8') ||
          finalUrl.contains('stream.php') ||
          finalUrl.contains('/live/')) {
        mimeType = 'application/x-mpegurl';
      } else if (finalUrl.contains('.mp4')) {
        mimeType = 'video/mp4';
      }

      if (mimeType.isNotEmpty) {
        js_util.setProperty(srcObj, 'type', mimeType);
      }

      js_util.setProperty(_currentPlayer!, 'src', srcObj);
      _currentPlayer!.setAttribute('title', 'Live Stream');
    } catch (e) {
      print('[VIDSTACK] Critical Error in _loadSource: $e');
      _handleErrorLogic();
    }
  }

  void _handleErrorLogic() {
    _safetyTimer?.cancel();

    // Safety check: if unmounted, stop.
    if (!mounted) return;

    if (_retryCount < 2) {
      _retryCount++;
      print('[VIDSTACK] Auto-Retrying same stream (Attempt $_retryCount)...');
      Timer(const Duration(milliseconds: 1000), () {
        if (mounted) _loadSource(widget.url);
      });
    } else {
      print('[VIDSTACK] Max retries reached. Switching to Next Stream...');
      if (widget.streamLinks.isNotEmpty) {
        int currentIndex = -1;
        String? currentRawUrl;
        if (_linksContainer != null) {
          for (var child in _linksContainer!.children) {
            if (child.classes.contains('active')) {
              currentRawUrl = child.dataset['raw-url'];
              break;
            }
          }
        }
        currentRawUrl ??= widget.url;

        for (int i = 0; i < widget.streamLinks.length; i++) {
          if (widget.streamLinks[i]['url'] == currentRawUrl) {
            currentIndex = i;
            break;
          }
        }

        if (currentIndex != -1 &&
            currentIndex + 1 < widget.streamLinks.length) {
          final nextStream = widget.streamLinks[currentIndex + 1];
          final nextUrl = nextStream['url'];
          print('[VIDSTACK] Switching to Next Stream: ${nextStream['name']}');
          _retryCount = 0;
          if (mounted) {
            _loadSource(nextUrl);
            _updateActiveButton(nextUrl);
          }
        }
      }
    }
  }

  void _updateActiveButton(String currentUrl) {
    if (_linksContainer == null) return;
    for (var child in _linksContainer!.children) {
      if (child is html.ButtonElement) {
        final btnUrl = child.dataset['raw-url'];
        if (btnUrl == currentUrl) {
          child.classes.add('active');
        } else {
          child.classes.remove('active');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: ValueKey(widget.url),
      viewType: 'vidstack-player',
      onPlatformViewCreated: (int viewId) {
        final element = vidstackViews[viewId];
        if (element == null) return;

        element.innerHtml = '';
        element.style.position = 'relative'; // Anchor for absolute children
        element.style.width = '100%';
        element.style.height = '100%';
        element.style.display = 'block';

        // --- CSS Styles ---
        final style = html.StyleElement();
        style.innerText = """
          .vds-player { 
            width: 100%; height: 100%; background-color: #000; overflow: hidden;
            --media-brand: #7C52D8;
            --media-focus-ring: 0 0 0 3px rgba(124, 82, 216, 0.5);
            position: absolute; /* Absolute within container */
            top: 0; left: 0;
            z-index: 0; 
          }
          media-icon { width: 28px; height: 28px; }
          
          /* HIDE VIDSTACK DEFAULT BUFFERING INDICATOR */
          .vds-buffering-indicator, media-buffering-indicator, .vds-spinner, media-spinner {
            display: none !important;
          }

          .vds-overlay-header {
            position: absolute; top: 0; left: 0; width: 100%; 
            /* Safe Areas for iPhone Notch/Home Bar - Lowered by 20px */
            padding-top: calc(env(safe-area-inset-top, 10px) + 20px);
            padding-right: env(safe-area-inset-right, 20px);
            padding-left: env(safe-area-inset-left, 20px);
            
            background: linear-gradient(to bottom, rgba(0,0,0,0.8), transparent);
            display: flex; align-items: center; z-index: 100; /* Above player */
            /* Start VISIBLE */
            opacity: 1; 
            transition: opacity 0.3s ease; 
            pointer-events: none; /* Let clicks pass through container */
          }

          /* --- VISIBILITY LOGIC: Sync with Native Controls using 'controls-visible' class --- */
          /* Hide overlay when player does NOT have controls-visible class */
          .vds-player:not(.controls-visible) ~ .vds-overlay-header {
             opacity: 0; pointer-events: none;
          }
          /* Show overlay when player HAS controls-visible class */
          .vds-player.controls-visible ~ .vds-overlay-header {
             opacity: 1; pointer-events: auto;
          }
          
          /* 2. Hover (Desktop) - Always show on hover */
          @media (hover: hover) {
            .vds-player:hover ~ .vds-overlay-header {
              opacity: 1 !important; pointer-events: auto !important;
            }
          }

          .vds-back-btn {
            background: rgba(255, 255, 255, 0.1); border-radius: 50%;
            width: 40px; height: 40px; cursor: pointer; display: flex;
            align-items: center; justify-content: center; color: white;
            margin-right: 15px; border: none; z-index: 101; 
            pointer-events: auto; /* Ensure clickable since parent has none */
          }
          .vds-links-container {
            display: flex; gap: 10px; overflow-x: auto; flex: 1; 
            padding: 5px; align-items: center; scrollbar-width: none;
            z-index: 101;
            pointer-events: auto; /* Ensure clickable since parent has none */
            /* Fix Overlap: Increased space for Settings Icon & Notch */
            padding-right: 80px; 
          }
          .vds-link-btn {
            background: rgba(124, 82, 216, 0.3); color: white;
            border: 1px solid rgba(255, 255, 255, 0.2); border-radius: 8px;
            padding: 6px 12px; cursor: pointer; white-space: nowrap;
          }
          .vds-link-btn.active { background: #7C52D8; border-color: #fff; }

          /* --- CUSTOM LOADER (Spinner) --- */
          .vds-loader {
            position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
            width: 48px; height: 48px;
            border: 5px solid rgba(255, 255, 255, 0.3);
            border-bottom-color: #7C52D8;
            border-radius: 50%;
            display: none; /* Hidden by default, toggled by JS */
            animation: vds-spin 1s linear infinite;
            z-index: 50; /* Above player, below overlay */
            pointer-events: none;
          }
          .vds-loader.visible { display: block; }
          @keyframes vds-spin { 0% { transform: translate(-50%, -50%) rotate(0deg); } 100% { transform: translate(-50%, -50%) rotate(360deg); } }
        """;
        element.append(style);

        // إنشاء المشغل (Player)
        final player = html.Element.tag('media-player');
        player.className = 'vds-player controls-visible';
        _currentPlayer = player;

        // الخصائص الأساسية
        player.setAttribute('autoplay', 'true');
        player.setAttribute('playsinline', 'true');
        player.setAttribute('crossorigin', 'true');
        player.setAttribute('aspect-ratio', '16/9');
        player.setAttribute('load', 'eager');
        player.setAttribute('user-idle-delay', '3000'); // Explicit 3s delay

        // إضافة المزود والتخطيط
        player.append(html.Element.tag('media-provider'));
        player.append(html.Element.tag('media-video-layout'));

        // APPEND PLAYER FIRST (Layer 0)
        element.append(player);

        // --- CUSTOM LOADER (Layer 1) ---
        // Defined OUTSIDE media-player to avoid Shadow DOM clipping
        final loader = html.DivElement()
          ..className = 'vds-loader visible'; // Start visible
        element.append(loader);

        // --- OVERLAY HEADER (Layer 2) ---
        // Defined OUTSIDE media-player
        final overlay = html.DivElement()..className = 'vds-overlay-header';
        overlay.setInnerHtml(
          '''<button class="vds-back-btn"><span style="font-size:24px;">&#x276E;</span></button><div class="vds-links-container"></div>''',
          treeSanitizer: html.NodeTreeSanitizer.trusted,
        );
        element.append(overlay);

        _controlsVisible = true;

        // CLICK/TOUCH HANDLER: TOGGLE VISIBILITY EXPLICITLY

        // We use pointerup in capture phase to reliably detect interaction
        // even if the video player swallows 'click' events.
        void handleToggle(html.Event e) {
          // If visible, hide immediately.
          // If hidden, show and start timer.

          if (_controlsVisible) {
            // Force Hide
            player.setAttribute('user-idle', 'true');
            _overlayTimer?.cancel();
          } else {
            // Force Show
            player.setAttribute('user-idle', 'false');
            _startHideTimer();
          }
        }

        // Listen to pointerup on the wrapper with capture
        element.addEventListener('pointerup', (event) {
          handleToggle(event);
        }, true /* capture */);

        // Back Button Logic
        overlay.querySelector('.vds-back-btn')?.onClick.listen((e) {
          e.stopPropagation();
          e.stopPropagation();
          player.setAttribute('user-idle', 'false');

          if (mounted) Navigator.of(context).maybePop();
        });

        // Initial URL Logic
        String initialUrl = widget.url;
        if (initialUrl.isEmpty && widget.streamLinks.isNotEmpty) {
          initialUrl = widget.streamLinks.first['url'];
        }

        // Links Container Logic
        final linksContainer = overlay.querySelector('.vds-links-container');
        if (linksContainer != null) {
          _linksContainer = linksContainer;
          linksContainer.onClick.listen((e) => e.stopPropagation());

          // (initialUrl logic moved up)

          for (var link in widget.streamLinks) {
            final name = link['name'] ?? 'Stream';
            final urlStr = link['url']?.toString();
            if (urlStr != null && urlStr.isNotEmpty) {
              final btn = html.ButtonElement()
                ..className = 'vds-link-btn'
                ..innerText = name
                ..dataset['raw-url'] = urlStr;

              if (urlStr == initialUrl) btn.classes.add('active');

              btn.onClick.listen((e) {
                e.stopPropagation();
                player.setAttribute('user-idle', 'false');
                _loadSource(urlStr);
                _updateActiveButton(urlStr);
              });
              linksContainer.append(btn);
            }
          }
        }

        // --- Event Listeners ---

        void setLoader(bool visible) {
          if (visible) {
            loader.classes.add('visible');
          } else {
            loader.classes.remove('visible');
          }
        }

        player.addEventListener('can-play', (event) {
          setLoader(false);
          _safetyTimer?.cancel();
          _retryCount = 0;

          final isPaused = js_util.getProperty(player, 'paused');
          if (isPaused == true) {
            try {
              js_util.callMethod(player, 'play', []);
              setLoader(true);
            } catch (e) {/* ignore */}
          }
        });

        player.addEventListener('waiting', (event) {
          setLoader(true);
        });

        player.addEventListener('playing', (event) {
          setLoader(false);
        });

        void handleFullscreenExit(html.Event e) {
          final isPaused = js_util.getProperty(player, 'paused');
          if (isPaused == true) {
            print(
                '[VIDSTACK] iOS Fullscreen Exit Detected - Resuming Playback');
            try {
              js_util.callMethod(player, 'play', []);
              setLoader(true);
            } catch (e) {/* ignore */}
          }
        }

        player.addEventListener(
            'webkitpresentationmodechanged', handleFullscreenExit);
        player.addEventListener('fullscreen-change', handleFullscreenExit);

        player.addEventListener('pause', (event) {
          _showControls();
          _overlayTimer?.cancel(); // Keep visible when paused
        });

        player.addEventListener('play', (event) {
          setLoader(true);
          _startHideTimer();
        });

        // LISTEN TO USER IDLE CHANGE
        player.addEventListener('user-idle-change', (html.Event event) {
          // Strictly sync our overlay with Vidstack's idle state
          final isIdle = js_util.getProperty(event, 'detail') as bool;
          if (isIdle) {
            _hideControls();
          } else {
            // Note: We don't call _showControls() here blindly to avoid loop,
            // but effectively if controls-visible is removed, it hides.
            // If isIdle is false, it means it's active.
            _showControls();

            // If it became active externally (e.g. key press), restart timer
            if (_overlayTimer == null || !_overlayTimer!.isActive) {
              _startHideTimer();
            }
          }
        });

        player.addEventListener('error', (event) {
          print('[VIDSTACK] Error Event Triggered');
          setLoader(true);
          _handleErrorLogic();
        });

        // تشغيل المصدر
        _loadSource(initialUrl);

        // Debug Border to confirm new structure (Temporary)
        // element.style.border = "2px solid red";
      },
    );
  }
}
