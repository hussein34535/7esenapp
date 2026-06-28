import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hesen/player_utils/video_player_wasm.dart'; // Import WASM version
import 'package:hesen/services/web_proxy_service.dart';
import 'package:web/web.dart' as web;
import 'package:http/http.dart'
    as http; // Use http package for requests in WASM
import 'dart:convert'; // For jsonDecode

class VidstackPlayerImpl extends StatefulWidget {
  final String url;
  final List<Map<String, dynamic>> streamLinks;
  final int selectedStreamIndex;

  const VidstackPlayerImpl({
    required this.url,
    this.streamLinks = const [],
    this.selectedStreamIndex = 0,
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
  bool _usedProxyForCurrentStream = false; // Flag to track if we switched to proxy
  String _currentUrl = ""; // Track the ACTUAL current playing URL
  int _loadRequestId = 0; // Prevent race conditions in async load
  bool _isPlayerInitializing = false; // NEW: Track initialization state
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
      _retryCount = 0;
      _usedProxyForCurrentStream = false;
      _currentUrl = widget.url;
      _loadRequestId++;
      _isPlayerInitializing = false;
      _safetyTimer?.cancel();
      _loadSource(widget.url);
      _updateActiveButtonByIndex(widget.selectedStreamIndex);
    } else if (widget.selectedStreamIndex != oldWidget.selectedStreamIndex && _currentPlayer != null) {
      _updateActiveButtonByIndex(widget.selectedStreamIndex);
    }
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _retryTimer?.cancel();
    _overlayTimer?.cancel();

    if (_currentPlayer != null) {
      try {
        (_currentPlayer as JSObject).callMethod('destroy'.toJS, JSArray());
      } catch (e) {
        debugPrint('[VIDSTACK] Ignored destroy error: $e');
      }
    }
    super.dispose();
  }

  // 🛡️ FIX: Prevent TypeError in Debug Mode when Flutter inspects JS objects
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    // Do NOT add _currentPlayer or other JS objects here as they cause
    // 'LegacyJavaScriptObject is not a subtype of DiagnosticsNode' in WASM
  }

  void _showControls() {
    _controlsVisible = true;
    _currentPlayer?.classList.add('controls-visible');
    // Sync with Native Controls
    _currentPlayer?.setAttribute('user-idle', 'false');
    _startHideTimer();
  }

  void _hideControls() {
    if (_currentPlayer == null) return;
    final isPaused =
        ((_currentPlayer as JSObject).getProperty('paused'.toJS) as JSBoolean?)
                ?.toDart ??
            false;
    if (isPaused == true) return;

    _controlsVisible = false;
    _currentPlayer?.classList.remove('controls-visible');
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
    if (rawUrl.isEmpty) return;
    
    if (_isPlayerInitializing) return;
    _isPlayerInitializing = true;

    if (_currentPlayer == null) {
      _isPlayerInitializing = false;
      return;
    }

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
      // Extract original URL if it's already proxied to avoid double-proxying later
      String rawTargetUrlForInterceptor = rawUrl;

      // 🛡️ OPTIMIZATION: If URL is already resolved by VideoPlayerScreen (e.g. proxied), SKIP heavy lookups
      bool isPreResolved = finalUrl.contains('workers.dev') || finalUrl.contains('hi.husseinh2711.workers.dev');

      if (isPreResolved) {
        try {
          final uri = Uri.parse(finalUrl);
          rawTargetUrlForInterceptor = uri.queryParameters['url'] ?? finalUrl;
          debugPrint('[VIDSTACK] Extracted original URL for interceptor from proxy: $rawTargetUrlForInterceptor');
        } catch (e) {}
      } else {
        // 1. Handle 7esenlink (JSON resolution)
        String? sevenEsenUrl;
        if (finalUrl.contains('7esenlink.vercel.app')) {
          if (finalUrl.contains('/proxy?url=')) {
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
            final targetUrlStr = jsonUri.toString();
            final proxyJsonUrl = targetUrlStr.startsWith('http://')
                ? WebProxyService.getProxiedUrl(targetUrlStr)
                : targetUrlStr;

            final response = await http.get(Uri.parse(proxyJsonUrl));
            if (myRequestId != _loadRequestId) return;

            final jsonResponse = jsonDecode(response.body);
            if (jsonResponse['url'] != null) {
              finalUrl = jsonResponse['url'];
              rawTargetUrlForInterceptor = finalUrl;
            }
          } catch (e) {
            // Error resolving 7esenlink - silently fall through
          }
        }
      }

      // 2. Handle IPTV (TS -> HLS) - Only for actual IPTV servers (numeric IPs with port 80/8080)
      bool isActualIptv = false;
      try {
        final parsedUri = Uri.parse(finalUrl);
        final host = parsedUri.host;
        final port = parsedUri.port;
        // Real IPTV servers are numeric IPs (e.g., 192.168.1.1:8080) not domain names
        final isNumericHost = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host);
        isActualIptv = isNumericHost && (port == 8080 || port == 80);
        // Also catch explicit :8080 or :80 in the authority for edge cases
        if (!isActualIptv) {
          final authority = parsedUri.authority;
          isActualIptv = authority.endsWith(':8080') || (authority.endsWith(':80') && !finalUrl.contains('stream.php'));
        }
      } catch (_) {}
      
      if (isActualIptv) {
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
      // 4. Determine if it's HLS or MP4 or YouTube for correct player behavior
      final lowerRawUrl = rawStreamUrl.toLowerCase();
      final lowerFinalUrl = finalUrl.toLowerCase();
      
      bool isYoutube = lowerRawUrl.contains('youtube.com') || lowerRawUrl.contains('youtu.be');
      bool isMp4 = lowerRawUrl.contains('.mp4') ||
                   lowerFinalUrl.contains('.mp4') ||
                   lowerFinalUrl.contains('type=mp4') ||
                   lowerFinalUrl.contains('video/mp4') ||
                   lowerFinalUrl.contains('type=video/mp4');

      String type;
      if (isYoutube) {
        type = 'youtube';
      } else if (isMp4) {
        type = 'video/mp4';
      } else {
        type = 'application/x-mpegurl';
      }

      // 5. Decide whether to use the JS Interceptor (Only for HLS)
      String sourceToUse = finalUrl;
      bool isProxied = finalUrl.contains('workers.dev');
      bool shouldProxy = _usedProxyForCurrentStream || isActualIptv || isProxied;

      // We ONLY use the JS Interceptor for HLS because it rewrites playlists.
      // If it's an MP4 or YouTube, the interceptor would try to parse binary/html as text and fail.
      bool shouldUseInterceptor = !isMp4 && !isYoutube && shouldProxy;

      if (shouldUseInterceptor) {
        // Set global variables using js_interop for the interceptor
        // Use the proxied URL so the interceptor can fetch it bypass CORS
        web.window.setProperty('currentStreamUrl'.toJS, rawStreamUrl.toJS);
        web.window.setProperty('isProxyMode'.toJS, true.toJS);
        // This dummy domain is intercepted by xhr_interceptor.js
        sourceToUse = 'https://proxy-live-stream/index.m3u8';
        debugPrint('[VIDSTACK] Using JS Interceptor with proxied URL: $rawStreamUrl');
      }

      // Assign src via a plain JS object using jsify()
      final srcMap = {
        'src': sourceToUse,
        'type': type,
      };
      
      try {
        (_currentPlayer as JSObject).setProperty('src'.toJS, srcMap.jsify());
        try {
          (_currentPlayer as JSObject).callMethod('play'.toJS, JSArray());
        } catch (e) {}
      } catch (e) {
        // Fallback setting attribute
        _currentPlayer!.setAttribute('src', sourceToUse);
        try {
          (_currentPlayer as JSObject).callMethod('play'.toJS, JSArray());
        } catch (e) {}
      }
      
      // 🏁 Set title and stream type (Live vs VOD)
      bool isMatch = rawStreamUrl.contains('dmcdn.net') || rawStreamUrl.contains('dailymotion.com');
      String title = isMp4 ? 'Video' : (isMatch ? 'Full Match' : 'Live Stream');
      
      _currentPlayer!.setAttribute('title', title);
      
      // Force VOD type for matches and mp4 so seeker bar works properly
      if (isMp4 || isMatch) {
        _currentPlayer!.setAttribute('stream-type', 'vod');
      }
    } catch (e) {
      _handleErrorLogic();
    } finally {
      _isPlayerInitializing = false;
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
            if (child.classList.contains('active') && child.hasAttribute('data-raw-url')) {
              currentRawUrl = child.getAttribute('data-raw-url');
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
            _updateActiveButtonByIndex(currentIndex + 1);
          }
        }
      }
    }
  }

  void _updateActiveButtonByIndex(int index) {
    if (_linksContainer == null) return;
    int btnIndex = 0;
    for (int i = 0; i < _linksContainer!.children.length; i++) {
      final child = _linksContainer!.children.item(i) as web.HTMLElement;
      if (child.tagName == 'BUTTON') {
        if (btnIndex == index) {
          child.classList.add('active');
        } else {
          child.classList.remove('active');
        }
        btnIndex++;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: const ValueKey('vidstack-player-stable'),
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
            --video-object-fit: contain;
            --video-object-position: center;
            position: absolute; 
            top: 0; left: 0;
            z-index: 0; 
            transform: translateZ(0); 
            will-change: transform;
          }
          .vds-player video,
          .vds-player iframe {
            object-fit: contain !important;
            object-position: center !important;
            width: 100% !important;
            height: 100% !important;
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
            debugPrint('[VIDSTACK_IMPL] Overlay appended to container');
          }
        } catch (e) {
          debugPrint('[VIDSTACK_IMPL] Error appending Overlay to container: $e');
        }

        _controlsVisible = true;

        void handleToggle(web.Event e) {
          if (_controlsVisible) {
            try {
              _hideControls();
              player.setAttribute('user-idle', 'true');
            } catch (e) {
              debugPrint('Error in handleToggle hide: $e');
            }
          } else {
            try {
              _showControls();
              player.setAttribute('user-idle', 'false');
            } catch (e) {
              debugPrint('Error in handleToggle show: $e');
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
          debugPrint('[VIDSTACK_IMPL] pointerup listener added');
        } catch (e) {
          debugPrint('[VIDSTACK_IMPL] Error adding pointerup listener: $e');
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
                    debugPrint('Error setting idle: $e');
                  }

                  if (mounted) Navigator.of(context).maybePop();
                }.toJS);
            debugPrint('[VIDSTACK_IMPL] backBtn listener added');
          } catch (e) {
            debugPrint('[VIDSTACK_IMPL] Error adding backBtn listener: $e');
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
            debugPrint('[VIDSTACK_IMPL] linksContainer listener added');
          } catch (e) {
            debugPrint('[VIDSTACK_IMPL] Error adding linksContainer listener: $e');
          }

          try {
            debugPrint('[VIDSTACK_IMPL] Processing streamLinks...');
            int indexCounter = 0;
            for (var link in widget.streamLinks) {
              final name = link['name'] ?? 'Stream';
              final urlStr = link['url']?.toString();
              if (urlStr != null && urlStr.isNotEmpty) {
                final btn = web.document.createElement('button')
                    as web.HTMLButtonElement;
                btn.className = 'vds-link-btn';
                btn.textContent = name;
                btn.setAttribute('data-raw-url', urlStr);

                if (indexCounter == widget.selectedStreamIndex) btn.classList.add('active');

                final currentBtnIndex = indexCounter;
                btn.addEventListener(
                    'click',
                    (web.Event e) {
                      e.stopPropagation();
                      player.setAttribute('user-idle', 'false');
                      _currentUrl = urlStr;
                      _loadSource(urlStr);
                      _updateActiveButtonByIndex(currentBtnIndex);
                    }.toJS);
                linksContainer.append(btn);
                indexCounter++;
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
                  // We removed the manual .play() call here to prevent "AbortError" 
                  // race conditions since the player handles autoplay natively.
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
