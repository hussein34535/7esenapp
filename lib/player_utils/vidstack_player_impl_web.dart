import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hesen/player_utils/video_player_web.dart';
import 'package:hesen/services/web_proxy_service.dart';
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
  Timer? _overlayTimer;
  Timer? _safetyTimer; // Safety timer for black screen
  bool _controlsVisible = true;
  int _retryCount = 0; // Track retries for current stream

  @override
  void didUpdateWidget(VidstackPlayerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url && _currentPlayer != null) {
      _retryCount = 0; // Reset on new URL
      _loadSource(widget.url);
      _updateActiveButton(widget.url);
    }
  }

  // ... [initState, dispose, _showControls, _hideControls, _toggleControls, _startOverlayTimer, _onPlayerInteraction, _loadSource, _updateActiveButton remain unchanged] ...

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _showControls() {
    _controlsVisible = true;
    _currentPlayer?.classes.add('controls-visible');
    // Sync with Native Controls
    _currentPlayer?.setAttribute('user-idle', 'false');
    _startOverlayTimer();
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

  void _startOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _hideControls();
    });
  }

  // Helper function to load source (Same as before)
  Future<void> _loadSource(String rawUrl) async {
    if (_currentPlayer == null) return;

    // CANCEL PREVIOUS SAFETY TIMER
    _safetyTimer?.cancel();
    // START NEW SAFETY TIMER (10 seconds)
    _safetyTimer = Timer(const Duration(seconds: 10), () {
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

      // 3. Multi-Proxy Race Strategy
      List<String> proxies = WebProxyService.getAllProxiedUrls(finalUrl);

      final isCurrentlySecure = html.window.location.protocol == 'https:';
      final isTargetSecure = finalUrl.startsWith('https://');
      bool directUrlInserted = false;

      if (isTargetSecure || !isCurrentlySecure) {
        proxies.insert(0, finalUrl);
        directUrlInserted = true;
      } else {
        print(
            '[VIDSTACK] Skipping direct HTTP URL on HTTPS site (Mixed Content Prevention)');
      }

      String? workingProxiedUrl;
      String? workingManifestContent;
      String activeProxyTemplate = '';

      print('[VIDSTACK] Starting Multi-Proxy Race for: $finalUrl');

      if (finalUrl.contains('.m3u8') ||
          finalUrl.contains('stream.php') ||
          finalUrl.contains('/live/')) {
        for (var i = 0; i < proxies.length; i++) {
          final proxyUrl = proxies[i];
          try {
            print('[VIDSTACK] Trying Proxy: $proxyUrl');
            final content = await html.HttpRequest.getString(proxyUrl)
                .timeout(const Duration(seconds: 10));

            if (content.contains('#EXTM3U')) {
              print('[VIDSTACK] ✅ Success with Proxy: $proxyUrl');
              workingProxiedUrl = proxyUrl;
              workingManifestContent = content;

              if (directUrlInserted) {
                if (i == 0) {
                  activeProxyTemplate = '';
                } else if (i > 0 &&
                    (i - 1) < WebProxyService.proxyTemplates.length) {
                  activeProxyTemplate = WebProxyService.proxyTemplates[i - 1];
                }
              } else {
                if (i < WebProxyService.proxyTemplates.length) {
                  activeProxyTemplate = WebProxyService.proxyTemplates[i];
                }
              }
              break;
            }
          } catch (e) {
            // print('[VIDSTACK] ❌ Proxy Failed ($proxyUrl): $e');
          }
        }
      } else {
        workingProxiedUrl = proxies.first;
      }

      if (workingProxiedUrl == null) {
        print('[VIDSTACK] ⚠️ All proxies failed. Using primary fallback.');
        workingProxiedUrl = proxies.isNotEmpty ? proxies.first : finalUrl;
        activeProxyTemplate = proxies.isNotEmpty
            ? proxies.first.split(Uri.encodeComponent(finalUrl))[0]
            : '';
      }

      // 4. Manifest Rewriting
      String sourceToUse = workingProxiedUrl!;

      if (workingManifestContent != null && activeProxyTemplate.isNotEmpty) {
        try {
          print('[VIDSTACK] Intercepting Manifest for Rewriting...');

          final uri = Uri.parse(finalUrl);
          final baseUrlString =
              uri.toString().substring(0, uri.toString().lastIndexOf('/') + 1);
          final baseUrl = Uri.parse(baseUrlString);
          final parentQueryParams = uri.query;

          final lines = workingManifestContent!.split('\n');
          final rewrittenLines = [];

          for (var line in lines) {
            line = line.trim();
            if (line.isEmpty) {
              rewrittenLines.add(line);
              continue;
            }

            if (line.startsWith('#')) {
              if (line.startsWith('#EXT-X-KEY') && line.contains('URI="')) {
                line = line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (match) {
                  String keyUri = match.group(1)!;
                  if (!keyUri.startsWith('http')) {
                    keyUri = baseUrl.resolve(keyUri).toString();
                    if (parentQueryParams.isNotEmpty && !keyUri.contains('?')) {
                      keyUri += '?$parentQueryParams';
                    }
                  }
                  return 'URI="${activeProxyTemplate}${Uri.encodeComponent(keyUri)}"';
                });
              }
              rewrittenLines.add(line);
              continue;
            }

            String segmentUrl = line;
            if (!segmentUrl.startsWith('http')) {
              segmentUrl = baseUrl.resolve(segmentUrl).toString();
            }
            if (parentQueryParams.isNotEmpty) {
              if (!segmentUrl.contains('?')) {
                segmentUrl += '?$parentQueryParams';
              }
            }
            if (!segmentUrl.startsWith(activeProxyTemplate)) {
              segmentUrl =
                  '$activeProxyTemplate${Uri.encodeComponent(segmentUrl)}';
            }
            rewrittenLines.add(segmentUrl);
          }

          final rewrittenContent = rewrittenLines.join('\n');
          final blob = html.Blob([rewrittenContent], 'application/x-mpegurl');
          sourceToUse = html.Url.createObjectUrlFromBlob(blob);
        } catch (e) {
          print('[VIDSTACK] Manifest Rewriting Failed: $e');
          sourceToUse = workingProxiedUrl!;
        }
      }

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

        // --- CSS Styles ---
        final style = html.StyleElement();
        style.innerText = """
          .vds-player { 
            width: 100%; height: 100%; background-color: #000; overflow: hidden;
            --media-brand: #7C52D8;
            --media-focus-ring: 0 0 0 3px rgba(124, 82, 216, 0.5);
            position: relative; /* Context for overlay */
          }
          media-icon { width: 28px; height: 28px; }

          .vds-overlay-header {
            position: absolute; top: 0; left: 0; width: 100%; 
            /* Safe Areas for iPhone Notch/Home Bar - Lowered by 20px */
            padding-top: calc(env(safe-area-inset-top, 10px) + 20px);
            padding-right: env(safe-area-inset-right, 20px);
            padding-left: env(safe-area-inset-left, 20px);
            
            background: linear-gradient(to bottom, rgba(0,0,0,0.8), transparent);
            display: flex; align-items: center; z-index: 100;
            /* Forced Visibility to prevent Black Screen of Death */
            opacity: 1; 
            transition: opacity 0.3s ease; 
            pointer-events: auto;
          }

          /* --- VISIBILITY LOGIC (Refined) --- */
          /* Hide only when explicitly hidden AND playing */
          .vds-player:not(.controls-visible) .vds-overlay-header {
             opacity: 0; pointer-events: none;
          }
          
          /* 2. Hover (Desktop) */
          @media (hover: hover) {
            .vds-player:hover .vds-overlay-header {
              opacity: 1; pointer-events: auto;
            }
          }

          .vds-back-btn {
            background: rgba(255, 255, 255, 0.1); border-radius: 50%;
            width: 40px; height: 40px; cursor: pointer; display: flex;
            align-items: center; justify-content: center; color: white;
            margin-right: 15px; border: none; z-index: 101; /* Ensure clickable */
          }
          .vds-links-container {
            display: flex; gap: 10px; overflow-x: auto; flex: 1; 
            padding: 5px; align-items: center; scrollbar-width: none;
            z-index: 101;
            /* Fix Overlap: Increased space for Settings Icon & Notch */
            padding-right: 80px; 
            /* Optional: Pointer events only on content? keeping container generic is safer for scroll */
          }
          .vds-link-btn {
            background: rgba(124, 82, 216, 0.3); color: white;
            border: 1px solid rgba(255, 255, 255, 0.2); border-radius: 8px;
            padding: 6px 12px; cursor: pointer; white-space: nowrap;
          }
          .vds-link-btn.active { background: #7C52D8; border-color: #fff; }
        """;
        element.append(style);

        // إنشاء المشغل
        final player = html.Element.tag('media-player');
        player.className = 'vds-player controls-visible'; // Start visible
        _currentPlayer = player;
        _controlsVisible = true; // Sync state

        // الخصائص الأساسية
        player.setAttribute('autoplay', 'true');
        player.setAttribute('playsinline', 'true');
        player.setAttribute('crossorigin', 'true');
        player.setAttribute('aspect-ratio', '16/9');
        player.setAttribute('load', 'eager');

        // إضافة المزود والتخطيط
        player.append(html.Element.tag('media-provider'));
        player.append(html.Element.tag('media-video-layout'));

        // --- OVERLAY ---
        final overlay = html.DivElement()..className = 'vds-overlay-header';
        overlay.setInnerHtml(
          '''<button class="vds-back-btn"><span style="font-size:24px;">&#x276E;</span></button><div class="vds-links-container"></div>''',
          treeSanitizer: html.NodeTreeSanitizer.trusted,
        );

        // Back Button
        overlay.querySelector('.vds-back-btn')?.onClick.listen((e) {
          e.stopPropagation(); // Prevent toggling when clicking button
          _startOverlayTimer(); // Interactions keep controls alive
          if (mounted) Navigator.of(context).maybePop();
        });

        // Links Container
        final linksContainer = overlay.querySelector('.vds-links-container');
        if (linksContainer == null) return;
        _linksContainer = linksContainer;

        // Prevent toggling when scrolling links
        linksContainer.onClick.listen((e) => e.stopPropagation());

        String initialUrl = widget.url;
        if (initialUrl.isEmpty && widget.streamLinks.isNotEmpty) {
          initialUrl = widget.streamLinks.first['url'];
        }

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
              e.stopPropagation(); // Prevent toggle
              _startOverlayTimer();
              _loadSource(urlStr);
              _updateActiveButton(urlStr);
            });
            linksContainer.append(btn);
          }
        }
        player.append(overlay);

        // --- Interaction Logic (Tap to Toggle) ---
        player.onClick.listen((e) {
          // If we clicked something else interactive (like built-in controls), ignore.
          // But here we are clicking the main container.
          _toggleControls();
        });

        // --- Event Listeners & Auto-Play Fix ---

        // 1. Media Ready (can-play)
        player.addEventListener('can-play', (event) {
          _safetyTimer?.cancel(); // SUCCESS! Cancel safety timer
          _retryCount = 0; // Reset retry count on success
          _startOverlayTimer();

          final isPaused = js_util.getProperty(player, 'paused');
          if (isPaused == true) {
            try {
              js_util.callMethod(player, 'play', []);
            } catch (e) {/* ignore */}
          }
        });

        // 2. iOS PiP/Fullscreen Exit Resume Fix
        // Safari often pauses video when exiting native fullscreen. We force resume.
        void handleFullscreenExit(html.Event e) {
          final isPaused = js_util.getProperty(player, 'paused');
          if (isPaused == true) {
            print(
                '[VIDSTACK] iOS Fullscreen Exit Detected - Resuming Playback');
            try {
              js_util.callMethod(player, 'play', []);
            } catch (e) {/* ignore */}
          }
        }

        player.addEventListener(
            'webkitpresentationmodechanged', handleFullscreenExit);
        player.addEventListener('fullscreen-change', handleFullscreenExit);

        // Pause/Play Listeners to manage visibility state
        player.addEventListener('pause', (event) {
          _showControls(); // Always show when paused
          _overlayTimer?.cancel(); // Cancel timer so it stays visible
        });

        player.addEventListener('play', (event) {
          _startOverlayTimer(); // Restart timer when playing resumes
        });

        // 3. Error Handling & Auto-Retry
        player.addEventListener('error', (event) {
          print('[VIDSTACK] Error Event Triggered');
          _handleErrorLogic();

          try {
            final eventObj = js.JsObject.fromBrowserObject(event);
            if (eventObj.hasProperty('detail')) {
              final detail = eventObj['detail'];
              if (detail != null) {
                // print('[VIDSTACK] Error Detail: $detail');
              }
            }
          } catch (e) {/* ignore */}
        });

        // تحميل المصدر الأولي
        _loadSource(initialUrl);
      },
    );
  }
}
