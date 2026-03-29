import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:hesen/player_utils/video_player_wasm.dart'; // Import WASM version
import 'package:hesen/services/web_proxy_service.dart';
import 'package:web/web.dart' as web;
import 'package:http/http.dart'
    as http; // Use http package for requests in WASM
import 'dart:convert'; // For jsonDecode

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
  web.HTMLElement? _currentPlayer;
  web.HTMLElement? _linksContainer;
  Timer? _overlayTimer; // MASTER AUTO-HIDE TIMER
  Timer? _safetyTimer; // Safety timer for black screen
  bool _controlsVisible = true;
  int _retryCount = 0; // Track retries for current stream
  bool _usedProxyForCurrentStream =
      false; // Flag to track if we switched to proxy
  String _currentUrl = ""; // Track the ACTUAL current playing URL
  int _loadRequestId = 0; // Prevent race conditions in async load
  Timer? _retryTimer; // To cancel pending retries

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  @override
  void didUpdateWidget(VidstackPlayerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url && _currentPlayer != null) {
      _retryCount = 0; // Reset on new URL
      _usedProxyForCurrentStream = false; // direct first
      _currentUrl = widget.url;
      _loadSource(widget.url);
      _updateActiveButton(widget.url);
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    super.dispose();
  }

  void _showControls() {
    _controlsVisible = true;
    _currentPlayer?.classList.add('controls-visible');
    // Sync with Native Controls
    _currentPlayer?.setAttribute('user-idle', 'false');
    _startHideTimer();
  }

  void _hideControls() {
    // Only hide if playing
    final isPaused =
        ((_currentPlayer as JSObject).getProperty('paused'.toJS) as JSBoolean?)
                ?.toDart ??
            false;
    if (isPaused == true) return;

    _controlsVisible = false;
    _currentPlayer?.classList.remove('controls-visible');
    // Sync with Native Controls
    _currentPlayer?.setAttribute('user-idle', 'true');
    _overlayTimer?.cancel();
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

    _loadRequestId++; // New request invalidates older ones
    final myRequestId = _loadRequestId;
    _retryTimer?.cancel(); // Cancel any pending retry

    // CANCEL PREVIOUS SAFETY TIMER
    _safetyTimer?.cancel();
    // Start Safety Timer (Give it 25 seconds for slow IPTV)
    _safetyTimer = Timer(const Duration(seconds: 25), () {
      _handleErrorLogic();
    });

    try {
      String finalUrl = rawUrl;

      // 1. Handle 7esenlink (JSON resolution)
      // Works with both raw and proxied 7esenlink URLs
      String? sevenEsenUrl;
      if (finalUrl.contains('7esenlink.vercel.app')) {
        if (finalUrl.contains('/proxy?url=')) {
          // Already proxied — extract raw URL from query param
          final uri = Uri.parse(finalUrl);
          sevenEsenUrl = uri.queryParameters['url'];
        } else {
          sevenEsenUrl = finalUrl;
        }
      }

      if (sevenEsenUrl != null) {
        try {
          final jsonUri = Uri.parse(sevenEsenUrl).replace(queryParameters: {
            ...Uri.parse(sevenEsenUrl).queryParameters,
            'json': 'true'
          });
          // Fetch through our HTTPS proxy ONLY if it's an HTTP URL to avoid Mixed Content
          final targetUrlStr = jsonUri.toString();
          final proxyJsonUrl = targetUrlStr.startsWith('http://')
              ? WebProxyService.getProxiedUrl(targetUrlStr)
              : targetUrlStr;

          // Use http package for WASM compatibility
          final response = await http.get(Uri.parse(proxyJsonUrl));
          if (myRequestId != _loadRequestId) return;

          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse['url'] != null) {
            finalUrl = jsonResponse['url'];
          }
        } catch (e) {
          // Error resolving 7esenlink - silently fall through
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

      // 3. Wrap HTTP URLs through HTTPS proxy to avoid Mixed Content
      final String rawStreamUrl = finalUrl; // Keep RAW URL for Interceptor
      if (finalUrl.startsWith('http://')) {
        String referer;
        if (finalUrl.contains('ok.ru')) {
          referer = 'https://ok.ru/';
        } else {
          referer = 'https://7esentv.com/';
        }
        finalUrl = WebProxyService.getProxiedUrl(finalUrl, referer: referer);
        // HTTP wrapped through HTTPS proxy
      } else if (finalUrl.contains('ok.ru') && !finalUrl.contains('workers.dev')) {
        // Even if HTTPS, proxy ok.ru to bypass CORS and set referer
        finalUrl = WebProxyService.getProxiedUrl(finalUrl, referer: 'https://ok.ru/');
      }
      // 4. Determine if it's HLS or MP4 for correct player behavior
      final lowerRawUrl = rawStreamUrl.toLowerCase();
      final lowerFinalUrl = finalUrl.toLowerCase();
      bool isMp4 = lowerRawUrl.contains('.mp4') ||
                   lowerFinalUrl.contains('.mp4') ||
                   lowerFinalUrl.contains('type=mp4') ||
                   lowerFinalUrl.contains('video/mp4') ||
                   lowerFinalUrl.contains('type=video/mp4');

      String type = isMp4 ? 'video/mp4' : 'application/x-mpegurl';

      // 5. Decide whether to use the JS Interceptor (Only for HLS)
      String sourceToUse = finalUrl;
      bool isIptv = rawStreamUrl.contains(':8080') || rawStreamUrl.contains(':80');
      bool isProxied = finalUrl.contains('workers.dev');
      bool shouldProxy = _usedProxyForCurrentStream || isIptv || isProxied;


      // We ONLY use the JS Interceptor for HLS because it rewrites playlists.
      // If it's an MP4, the interceptor would try to parse binary as text and fail.
      bool shouldUseInterceptor = !isMp4 && shouldProxy;

      if (shouldUseInterceptor) {
        // Set global variables using js_interop for the interceptor
        web.window.setProperty('currentStreamUrl'.toJS, rawStreamUrl.toJS);
        web.window.setProperty('isProxyMode'.toJS, true.toJS);
        // This dummy domain is intercepted by xhr_interceptor.js
        sourceToUse = 'https://proxy-live-stream/index.m3u8';
      }

      // Create JS Object for src
      final srcObj = JSObject();
      srcObj.setProperty('src'.toJS, sourceToUse.toJS);
      srcObj.setProperty('type'.toJS, type.toJS);

      (_currentPlayer as JSObject).setProperty('src'.toJS, srcObj);
      _currentPlayer!.setAttribute('title', isMp4 ? 'Video' : 'Live Stream');
    } catch (e) {
      _handleErrorLogic();
    }
  }

  void _handleErrorLogic() {
    _safetyTimer?.cancel();

    // Safety check: if unmounted, stop.
    if (!mounted) return;

    if (_retryCount < 2) {
      if (!_usedProxyForCurrentStream) {
        // Direct play failed, retrying with proxy fallback
        _usedProxyForCurrentStream = true;
        Timer(const Duration(milliseconds: 100), () {
          if (mounted) _loadSource(_currentUrl);
        });
        return;
      }

      _retryCount++;
      // Auto-retrying same stream
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) _loadSource(_currentUrl);
      });
    } else {
      // Max retries reached, switching to next stream
      if (widget.streamLinks.isNotEmpty) {
        int currentIndex = -1;
        String? currentRawUrl;
        if (_linksContainer != null) {
          for (int i = 0; i < _linksContainer!.children.length; i++) {
            final child = _linksContainer!.children.item(i) as web.HTMLElement;
            if (child.classList.contains('active')) {
              currentRawUrl = child.dataset['raw-url'];
              break;
            }
          }
        }
        currentRawUrl ??= _currentUrl;

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
          // Switching to next stream
          _retryCount = 0;
          _usedProxyForCurrentStream = false; // Reset for new stream
          if (mounted) {
            _currentUrl = nextUrl;
            _loadSource(nextUrl);
            _updateActiveButton(nextUrl);
          }
        }
      }
    }
  }

  void _updateActiveButton(String currentUrl) {
    if (_linksContainer == null) return;
    for (int i = 0; i < _linksContainer!.children.length; i++) {
      final child = _linksContainer!.children.item(i) as web.HTMLElement;
      if (child.tagName == 'BUTTON') {
        final btnUrl = child.dataset['raw-url'];
        if (btnUrl == currentUrl) {
          child.classList.add('active');
        } else {
          child.classList.remove('active');
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
        if (element == null) {
          return;
        }

        try {
          element.innerHTML = ''.toJS;
          element.style.position = 'relative';
          element.style.width = '100%';
          element.style.height = '100%';
          element.style.display = 'block';
        } catch (e) {}

        // --- CSS Styles ---
        final style =
            web.document.createElement('style') as web.HTMLStyleElement;

        try {
          final cssContent = """
          .vds-player { 
            width: 100%; height: 100%; background-color: #000; overflow: hidden;
            --media-brand: #7C52D8;
            --media-focus-ring: 0 0 0 3px rgba(124, 82, 216, 0.5);
            position: absolute; 
            top: 0; left: 0;
            z-index: 0; 
            transform: translateZ(0); 
            will-change: transform;
          }
          media-icon { width: 28px; height: 28px; }
          
          .vds-buffering-indicator, media-buffering-indicator, .vds-spinner, media-spinner {
            display: none !important;
          }

          .vds-overlay-header {
            position: absolute; top: 0; left: 0; width: 100%; 
            padding-top: calc(env(safe-area-inset-top, 10px) + 20px);
            padding-right: env(safe-area-inset-right, 20px);
            padding-left: env(safe-area-inset-left, 20px);
            background: linear-gradient(to bottom, rgba(0,0,0,0.8), transparent);
            display: flex; align-items: center; z-index: 100; 
            opacity: 1; 
            transition: opacity 0.35s ease-out 0.1s; 
            pointer-events: none; 
          }

          .vds-player:not(.controls-visible) ~ .vds-overlay-header {
             opacity: 0; pointer-events: none;
             transition: opacity 0.2s ease 0s; 
          }
          .vds-player.controls-visible ~ .vds-overlay-header {
             opacity: 1; pointer-events: auto;
          }
          
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
            pointer-events: auto; 
          }
          .vds-links-container {
            display: flex; gap: 10px; overflow-x: auto; flex: 1; 
            padding: 5px; align-items: center; scrollbar-width: none;
            z-index: 101;
            pointer-events: auto; 
            padding-right: 80px; 
          }
          .vds-link-btn {
            background: rgba(124, 82, 216, 0.3); color: white;
            border: 1px solid rgba(255, 255, 255, 0.2); border-radius: 8px;
            padding: 6px 12px; cursor: pointer; white-space: nowrap;
          }
          .vds-link-btn.active { background: #7C52D8; border-color: #fff; }
          .vds-loader {
            position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
            width: 48px; height: 48px;
            border: 5px solid rgba(255, 255, 255, 0.3);
            border-bottom-color: #7C52D8;
            border-radius: 50%;
            display: none; 
            animation: vds-spin 1s linear infinite;
            z-index: 50; 
            pointer-events: none;
          }
          .vds-loader.visible { display: block; }
          @keyframes vds-spin { 0% { transform: translate(-50%, -50%) rotate(0deg); } 100% { transform: translate(-50%, -50%) rotate(360deg); } }
        """;
          style.appendChild(web.document.createTextNode(cssContent));
        } catch (e) {
          // CSS injection error - non-fatal
        }

        element.append(style);

        // CREATE PLAYER
        web.HTMLElement player;
        try {
          final rawPlayer = web.document.createElement('media-player');
          player = rawPlayer as web.HTMLElement;
        } catch (e) {
          rethrow;
        }

        try {
          player.className = 'vds-player controls-visible';
          // iOS/Safari: Muted autoplay is the only way to play without user interaction.
          // We unmute on the 'playing' event.
          player.setAttribute('autoplay', 'true');
          player.setAttribute('muted', 'true');
          player.setAttribute('playsinline', 'true');
          player.setAttribute('crossorigin', 'anonymous'); // Essential for CORS on Safari
          player.setAttribute('aspect-ratio', '16/9');
          player.setAttribute('load', 'eager');
          player.setAttribute('user-idle-delay', '3000');
          player.append(web.document.createElement('media-provider'));
          player.append(web.document.createElement('media-video-layout'));
          element.append(player);
          _currentPlayer = player;
          debugPrint('[VIDSTACK] Player created and attached to DOM.');
        } catch (e) {
          debugPrint('[VIDSTACK] Error creating player: $e');
          rethrow;
        }

        // LOADER
        web.HTMLDivElement? loader;
        try {
          final rawLoader = web.document.createElement('div');
          loader = rawLoader as web.HTMLDivElement;
          loader.className = 'vds-loader visible';
          element.append(loader);
        } catch (e) {}

        // OVERLAY HEADER
        web.HTMLDivElement? overlay;
        try {
          final rawOverlay = web.document.createElement('div');
          overlay = rawOverlay as web.HTMLDivElement;
          overlay.className = 'vds-overlay-header';
        } catch (e) {}

        // Back Button
        web.HTMLButtonElement? backBtn;
        try {
          final rawBtn = web.document.createElement('button');
          backBtn = rawBtn as web.HTMLButtonElement;
          backBtn.className = 'vds-back-btn';

          final backSpan =
              web.document.createElement('span') as web.HTMLSpanElement;
          backSpan.style.fontSize = '24px';
          backSpan.textContent = '❮';
          backBtn.append(backSpan);

          if (overlay != null) overlay.append(backBtn);
        } catch (e) {}

        // Links Container
        web.HTMLDivElement? linksContainer;
        try {
          final rawLC = web.document.createElement('div');
          linksContainer = rawLC as web.HTMLDivElement;
          linksContainer.className = 'vds-links-container';
          if (overlay != null) overlay.append(linksContainer);
        } catch (e) {}

        try {
          if (overlay != null) {
            element.append(overlay);
            print('[VIDSTACK_IMPL] Overlay appended to container');
          }
        } catch (e) {
          print('[VIDSTACK_IMPL] Error appending Overlay to container: $e');
        }

        _controlsVisible = true;

        void handleToggle(web.Event e) {
          if (_controlsVisible) {
            try {
              _hideControls();
              player.setAttribute('user-idle', 'true');
            } catch (e) {
              print('Error in handleToggle hide: $e');
            }
          } else {
            try {
              _showControls();
              player.setAttribute('user-idle', 'false');
            } catch (e) {
              print('Error in handleToggle show: $e');
            }
          }
        }

        try {
          element.addEventListener(
              'pointerup',
              (web.Event event) {
                handleToggle(event);
              }.toJS,
              true.toJS);
          print('[VIDSTACK_IMPL] pointerup listener added');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error adding pointerup listener: $e');
        }

        if (backBtn != null) {
          try {
            backBtn.addEventListener(
                'click',
                (web.Event e) {
                  e.stopPropagation();
                  e.stopPropagation();
                  try {
                    player.setAttribute('user-idle', 'false');
                  } catch (e) {
                    print('Error setting idle: $e');
                  }

                  if (mounted) Navigator.of(context).maybePop();
                }.toJS);
            print('[VIDSTACK_IMPL] backBtn listener added');
          } catch (e) {
            print('[VIDSTACK_IMPL] Error adding backBtn listener: $e');
          }
        }

        // Initial URL Logic
        String initialUrl = widget.url;
        if (initialUrl.isEmpty && widget.streamLinks.isNotEmpty) {
          initialUrl = widget.streamLinks.first['url'];
        }

        if (linksContainer != null) {
          _linksContainer = linksContainer;
          try {
            linksContainer.addEventListener(
                'click',
                (web.Event e) {
                  e.stopPropagation();
                }.toJS);
            print('[VIDSTACK_IMPL] linksContainer listener added');
          } catch (e) {
            print('[VIDSTACK_IMPL] Error adding linksContainer listener: $e');
          }

          try {
            print('[VIDSTACK_IMPL] Processing streamLinks...');
            for (var link in widget.streamLinks) {
              final name = link['name'] ?? 'Stream';
              final urlStr = link['url']?.toString();
              if (urlStr != null && urlStr.isNotEmpty) {
                final btn = web.document.createElement('button')
                    as web.HTMLButtonElement;
                btn.className = 'vds-link-btn';
                btn.textContent = name;
                btn.setAttribute('data-raw-url', urlStr);

                if (urlStr == initialUrl) btn.classList.add('active');

                btn.addEventListener(
                    'click',
                    (web.Event e) {
                      e.stopPropagation();
                      player.setAttribute('user-idle', 'false');
                      _currentUrl = urlStr;
                      _loadSource(urlStr);
                      _updateActiveButton(urlStr);
                    }.toJS);
                linksContainer.append(btn);
              }
            }
            // streamLinks processed
          } catch (e) {
            // Error processing streamLinks - non-fatal
          }
        }

        void setLoader(bool visible) {
          if (loader != null) {
            if (visible) {
              loader.classList.add('visible');
            } else {
              loader.classList.remove('visible');
            }
          }
        }

        // ignore: unnecessary_null_comparison
        if (player != null) {
          try {
            player.addEventListener(
                'can-play',
                (web.Event event) {
                  setLoader(false);
                  _safetyTimer?.cancel();
                  _retryCount = 0;

                  final playerObj = player as JSObject;
                  bool isPaused = false;
                  try {
                    if (playerObj.hasProperty('paused'.toJS).toDart) {
                      isPaused = (playerObj.getProperty('paused'.toJS) as JSBoolean?)
                              ?.toDart ??
                          false;
                    }
                  } catch (e) {
                    debugPrint('[VIDSTACK] Error checking paused state: $e');
                  }

                  if (isPaused) {
                    try {
                      playerObj.callMethod('play'.toJS, JSArray());
                      setLoader(true);
                    } catch (e) {
                      debugPrint('[VIDSTACK] play() failed: $e');
                    }
                  }
                }.toJS);

            player.addEventListener(
                'waiting',
                (web.Event event) {
                  setLoader(true);
                }.toJS);

            player.addEventListener(
                'playing',
                (web.Event event) {
                  setLoader(false);
                  debugPrint('[VIDSTACK] Playing started.');
                  // iOS: Unmute after autoplay starts (muted autoplay workaround)
                  try {
                    final playerObj = player as JSObject;
                    if (playerObj.hasProperty('muted'.toJS).toDart) {
                      playerObj.setProperty('muted'.toJS, false.toJS);
                      debugPrint('[VIDSTACK] Auto-unmuted.');
                    }
                  } catch (e) {
                    debugPrint('[VIDSTACK] Auto-unmute failed: $e');
                  }
                }.toJS);

            void handleFullscreenExit(web.Event e) {
              final isPaused = ((player as JSObject).getProperty('paused'.toJS)
                          as JSBoolean?)
                      ?.toDart ??
                  false;
              if (isPaused == true) {
                try {
                  (player as JSObject).callMethod('play'.toJS, JSArray());
                  setLoader(true);
                } catch (e) {/* ignore */}
              }
            }

            player.addEventListener(
                'webkitpresentationmodechanged',
                (web.Event e) {
                  handleFullscreenExit(e);
                }.toJS);
            player.addEventListener(
                'fullscreen-change',
                (web.Event e) {
                  handleFullscreenExit(e);
                }.toJS);

            player.addEventListener(
                'pause',
                (web.Event event) {
                  _showControls();
                  _overlayTimer?.cancel();
                }.toJS);

            player.addEventListener(
                'play',
                (web.Event event) {
                  setLoader(true);
                  _startHideTimer();
                }.toJS);

            player.addEventListener(
                'provider-change',
                (web.Event event) {
                  // Provider changed - no action needed
                }.toJS);

            player.addEventListener(
                'user-idle-change',
                (web.Event event) {
                  final isIdle = ((event as JSObject).getProperty('detail'.toJS)
                              as JSBoolean?)
                          ?.toDart ??
                      false;
                  if (isIdle) {
                    _hideControls();
                  } else {
                    _showControls();
                    if (_overlayTimer == null || !_overlayTimer!.isActive) {
                      _startHideTimer();
                    }
                  }
                }.toJS);

            player.addEventListener(
                'error',
                (web.Event event) {
                  setLoader(true);
                  _handleErrorLogic();
                }.toJS);

          } catch (e) {
            // Error adding player listeners
          }
        }

        try {
          _loadSource(initialUrl);
        } catch (e) {
          // Error calling _loadSource
        }
      },
    );
  }
}

// Extensions for dataset access if needed, or just use setAttribute
extension HTMLElementDataset on web.HTMLElement {
  String? get datasetRawUrl => this.getAttribute('data-raw-url');
  set datasetRawUrl(String? value) {
    if (value != null)
      this.setAttribute('data-raw-url', value);
    else
      this.removeAttribute('data-raw-url');
  }

  Map<String, String> get dataset {
    // Simplified shim
    return {};
  }
}
