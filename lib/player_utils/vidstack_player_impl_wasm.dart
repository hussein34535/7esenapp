import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'package:hesen/player_utils/video_player_wasm.dart'; // Import WASM version
import 'package:hesen/services/web_proxy_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
    WakelockPlus.enable();
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
    WakelockPlus.disable();
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
      print(
          '[VIDSTACK] ⚠️ Safety Timer Expired: Video did not start. Force-switching...');
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
          print('[VIDSTACK] Resolving 7esenlink: $proxyJsonUrl');

          // Use http package for WASM compatibility
          final response = await http.get(Uri.parse(proxyJsonUrl));
          if (myRequestId != _loadRequestId) return;

          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse['url'] != null) {
            finalUrl = jsonResponse['url'];
            print('[VIDSTACK] 7esenlink resolved to: $finalUrl');
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

      // 3. Wrap HTTP URLs through HTTPS proxy to avoid Mixed Content
      final String rawStreamUrl = finalUrl; // Keep RAW URL for Interceptor
      if (finalUrl.startsWith('http://')) {
        finalUrl = WebProxyService.getProxiedUrl(finalUrl);
        print('[VIDSTACK] Wrapped HTTP->HTTPS proxy: $finalUrl');
      }

      // 4. Direct Play with CORS Proxy Fallback
      String sourceToUse = finalUrl;
      // NEW: Force proxy mode if it's an IPTV link or starts with worker URL
      bool isIptv =
          rawStreamUrl.contains(':8080') || rawStreamUrl.contains(':80');
      bool isProxied = finalUrl.contains('workers.dev');
      bool shouldProxy = _usedProxyForCurrentStream || isIptv || isProxied;

      if (shouldProxy) {
        print('[VIDSTACK] 🔒 Activate JS Proxy Loader for: $rawStreamUrl');
        // Set global variables using js_interop
        web.window.setProperty('currentStreamUrl'.toJS, rawStreamUrl.toJS);
        web.window.setProperty('isProxyMode'.toJS, true.toJS);
        sourceToUse = 'https://proxy-live-stream/index.m3u8';
      }

      print('[VIDSTACK] Final Source URL: $sourceToUse');

      // Create JS Object for src
      final srcObj = JSObject();
      srcObj.setProperty('src'.toJS, sourceToUse.toJS);
      srcObj.setProperty('type'.toJS, 'application/x-mpegurl'.toJS);

      (_currentPlayer as JSObject).setProperty('src'.toJS, srcObj);
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
      if (!_usedProxyForCurrentStream) {
        print('[VIDSTACK] Direct Play Failed. Retrying with Proxy Fallback...');
        _usedProxyForCurrentStream = true;
        Timer(const Duration(milliseconds: 100), () {
          if (mounted) _loadSource(_currentUrl);
        });
        return;
      }

      _retryCount++;
      print('[VIDSTACK] Auto-Retrying same stream (Attempt $_retryCount)...');
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) _loadSource(_currentUrl);
      });
    } else {
      print('[VIDSTACK] Max retries reached. Switching to Next Stream...');
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
          print('[VIDSTACK] Switching to Next Stream: ${nextStream['name']}');
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
        print('[VIDSTACK_IMPL] onPlatformViewCreated: $viewId');
        final element = vidstackViews[viewId];
        if (element == null) {
          print('[VIDSTACK_IMPL] Element is null for viewId: $viewId');
          return;
        }
        print('[VIDSTACK_IMPL] Element found: $element');

        try {
          element.innerHTML = ''.toJS;
          print('[VIDSTACK_IMPL] innerHTML set');
          element.style.position = 'relative';
          element.style.width = '100%';
          element.style.height = '100%';
          element.style.display = 'block';
          print('[VIDSTACK_IMPL] Base styles set');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error setting base styles/innerHTML: $e');
        }

        // --- CSS Styles ---
        print('[VIDSTACK_IMPL] Creating style element...');
        final style =
            web.document.createElement('style') as web.HTMLStyleElement;
        print('[VIDSTACK_IMPL] Style element created: $style');

        try {
          final cssContent = """
          .vds-player { 
            width: 100%; height: 100%; background-color: #000; overflow: hidden;
            --media-brand: #7C52D8;
            --media-focus-ring: 0 0 0 3px rgba(124, 82, 216, 0.5);
            position: absolute; 
            top: 0; left: 0;
            z-index: 0; 
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
          print('[VIDSTACK_IMPL] Style textNode appended');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error setting style content: $e');
        }

        element.append(style);
        print('[VIDSTACK_IMPL] Style appended');
        print('[VIDSTACK_IMPL] VIDEO_PLAYER_WASM_DEBUG_VERSION_999');

        // CREATE PLAYER
        web.HTMLElement player;
        try {
          print('[VIDSTACK_IMPL] Creating media-player...');
          final rawPlayer = web.document.createElement('media-player');
          print(
              '[VIDSTACK_IMPL] rawPlayer created (Element). Tag: ${rawPlayer.tagName}');
          // Safe cast attempt
          if (rawPlayer.instanceOfString('HTMLElement')) {
            print('[VIDSTACK_IMPL] rawPlayer IS HTMLElement');
            player = rawPlayer as web.HTMLElement;
          } else {
            print(
                '[VIDSTACK_IMPL] rawPlayer IS NOT HTMLElement - forcing unsafe cast');
            player = rawPlayer as web.HTMLElement;
          }
          print('[VIDSTACK_IMPL] media-player cast success: $player');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error creating media-player: $e');
          rethrow;
        }

        try {
          player.className = 'vds-player controls-visible';
          print('[VIDSTACK_IMPL] className set');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error setting className: $e');
        }

        _currentPlayer = player;

        try {
          player.setAttribute('autoplay', 'true');
          player.setAttribute('playsinline', 'true');
          player.setAttribute('crossorigin', 'true');
          player.setAttribute('aspect-ratio', '16/9');
          player.setAttribute('load', 'eager');
          player.setAttribute('user-idle-delay', '3000');
          print('[VIDSTACK_IMPL] Attributes set');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error setting attributes: $e');
        }

        try {
          player.append(web.document.createElement('media-provider'));
          player.append(web.document.createElement('media-video-layout'));
          print('[VIDSTACK_IMPL] Children appended to player');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error appending children: $e');
        }

        try {
          element.append(player);
          print('[VIDSTACK_IMPL] Player appended to container');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error appending player to container: $e');
        }

        // LOADER
        web.HTMLDivElement? loader;
        try {
          print('[VIDSTACK_IMPL] Creating Loader...');
          final rawLoader = web.document.createElement('div');
          loader = rawLoader as web.HTMLDivElement;
          loader.className = 'vds-loader visible';
          element.append(loader);
          print('[VIDSTACK_IMPL] Loader appended');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error creating/appending Loader: $e');
        }

        // OVERLAY HEADER
        web.HTMLDivElement? overlay;
        try {
          print('[VIDSTACK_IMPL] Creating Overlay...');
          final rawOverlay = web.document.createElement('div');
          overlay = rawOverlay as web.HTMLDivElement;
          overlay.className = 'vds-overlay-header';
        } catch (e) {
          print('[VIDSTACK_IMPL] Error creating Overlay: $e');
        }

        // Back Button
        web.HTMLButtonElement? backBtn;
        try {
          print('[VIDSTACK_IMPL] Creating BackBtn...');
          final rawBtn = web.document.createElement('button');
          backBtn = rawBtn as web.HTMLButtonElement;
          backBtn.className = 'vds-back-btn';

          final backSpan =
              web.document.createElement('span') as web.HTMLSpanElement;
          backSpan.style.fontSize = '24px';
          backSpan.textContent = '❮';
          backBtn.append(backSpan);

          if (overlay != null) overlay.append(backBtn);
          print('[VIDSTACK_IMPL] BackBtn appended');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error creating BackBtn: $e');
        }

        // Links Container
        web.HTMLDivElement? linksContainer;
        try {
          print('[VIDSTACK_IMPL] Creating LinksContainer...');
          final rawLC = web.document.createElement('div');
          linksContainer = rawLC as web.HTMLDivElement;
          linksContainer.className = 'vds-links-container';
          if (overlay != null) overlay.append(linksContainer);
          print('[VIDSTACK_IMPL] LinksContainer appended');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error creating LinksContainer: $e');
        }

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
            print('[VIDSTACK_IMPL] streamLinks processed');
          } catch (e) {
            print('[VIDSTACK_IMPL] Error processing streamLinks: $e');
          }
        }

        void setLoader(bool visible) {
          if (loader != null) {
            if (visible) {
              loader!.classList.add('visible');
            } else {
              loader!.classList.remove('visible');
            }
          }
        }

        if (player != null) {
          try {
            print('[VIDSTACK_IMPL] Adding player listeners...');
            player.addEventListener(
                'can-play',
                (web.Event event) {
                  setLoader(false);
                  _safetyTimer?.cancel();
                  _retryCount = 0;

                  final isPaused = ((player as JSObject)
                              .getProperty('paused'.toJS) as JSBoolean?)
                          ?.toDart ??
                      false;
                  if (isPaused == true) {
                    try {
                      (player as JSObject).callMethod('play'.toJS, JSArray());
                      setLoader(true);
                    } catch (e) {/* ignore */}
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
                }.toJS);

            void handleFullscreenExit(web.Event e) {
              final isPaused = ((player as JSObject).getProperty('paused'.toJS)
                          as JSBoolean?)
                      ?.toDart ??
                  false;
              if (isPaused == true) {
                print(
                    '[VIDSTACK] iOS Fullscreen Exit Detected - Resuming Playback');
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
                  print('[VIDSTACK] Provider changed.');
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
                  final detail = (event as JSObject).getProperty('detail'.toJS);
                  print('[VIDSTACK] Error Event: $detail');
                  setLoader(true);
                  _handleErrorLogic();
                }.toJS);

            // Debugging Stalls
            player.addEventListener(
                'loaded-metadata',
                (web.Event e) {
                  print('[VIDSTACK] Event: loaded-metadata');
                }.toJS);
            player.addEventListener(
                'loaded-data',
                (web.Event e) {
                  print('[VIDSTACK] Event: loaded-data');
                }.toJS);
            player.addEventListener(
                'can-play',
                (web.Event e) {
                  print('[VIDSTACK] Event: can-play');
                }.toJS);
            player.addEventListener(
                'stalled',
                (web.Event e) {
                  print('[VIDSTACK] Event: stalled');
                }.toJS);
            player.addEventListener(
                'suspend',
                (web.Event e) {
                  print('[VIDSTACK] Event: suspend');
                }.toJS);
            player.addEventListener(
                'waiting',
                (web.Event e) {
                  print('[VIDSTACK] Event: waiting');
                }.toJS);

            print('[VIDSTACK_IMPL] Player listeners added');
          } catch (e) {
            print('[VIDSTACK_IMPL] Error adding player listeners: $e');
          }
        }

        try {
          print('[VIDSTACK_IMPL] Calling _loadSource...');
          _loadSource(initialUrl);
          print('[VIDSTACK_IMPL] _loadSource called');
        } catch (e) {
          print('[VIDSTACK_IMPL] Error calling _loadSource: $e');
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
