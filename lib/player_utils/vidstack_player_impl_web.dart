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

  @override
  void didUpdateWidget(VidstackPlayerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url && _currentPlayer != null) {
      _loadSource(widget.url);
      _updateActiveButton(widget.url);
    }
  }

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

  // دالة مساعدة لتحميل المصدر بشكل صحيح
  Future<void> _loadSource(String rawUrl) async {
    if (_currentPlayer == null) return;

    String finalUrl = rawUrl;

    // 1. معالجة 7esenlink (JSON)
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

    // 2. معالجة IPTV (تحويل TS إلى HLS)
    if (finalUrl.contains(':8080') ||
        (finalUrl.contains(':80') && !finalUrl.contains('stream.php'))) {
      Uri uri = Uri.parse(finalUrl);
      List<String> segments = List.from(uri.pathSegments);
      if (segments.length == 3 && segments[0] != 'live') {
        segments.insert(0, 'live');
        String lastSegment = segments.last;
        if (!lastSegment.endsWith('.m3u8')) segments.last = '$lastSegment.m3u8';
        finalUrl = uri.replace(pathSegments: segments).toString();
      } else if (!finalUrl.endsWith('.m3u8')) {
        finalUrl = '$finalUrl.m3u8';
      }
    }

    // 3. Multi-Proxy Race Strategy (Validated List) 🏎️
    // بما أن لدينا قائمة بروكسيات كبيرة، سنجربها واحدة تلو الأخرى
    // ونستخدم أول واحد ينجح في جلب المانيفست
    List<String> proxies = WebProxyService.getAllProxiedUrls(finalUrl);
    // إضافة الرابط المباشر كأول خيار للمحاولة (الأسرع والأفضل إذا نجح)
    // إذا فشل بسبب CORS، سينتقل فوراً للبروكسيات
    proxies.insert(0, finalUrl);

    String? workingProxiedUrl;
    String? workingManifestContent;
    String activeProxyTemplate = '';

    print('[VIDSTACK] Starting Multi-Proxy Race for: $finalUrl');

    if (finalUrl.contains('.m3u8') ||
        finalUrl.contains('stream.php') ||
        finalUrl.contains('/live/')) {
      // تجربة البروكسيات للمانيفست
      // تجربة البروكسيات للمانيفست
      for (var i = 0; i < proxies.length; i++) {
        final proxyUrl = proxies[i];
        try {
          print('[VIDSTACK] Trying Proxy: $proxyUrl');
          // Timeout متوسط (10 ثواني) لأن بعض البروكسيات مثل codetabs بطيئة
          final content = await html.HttpRequest.getString(proxyUrl)
              .timeout(const Duration(seconds: 10));

          if (content.contains('#EXTM3U')) {
            print('[VIDSTACK] ✅ Success with Proxy: $proxyUrl');
            workingProxiedUrl = proxyUrl;
            workingManifestContent = content;

            // تحديد القالب بدقة من القائمة الأصلية
            // ملاحظة: قمنا بإضافة الرابط المباشر في البداية (index 0)
            // لذا القوالب تبدأ من (i - 1)
            if (i > 0 && (i - 1) < WebProxyService.proxyTemplates.length) {
              activeProxyTemplate = WebProxyService.proxyTemplates[i - 1];
            } else {
              // إذا كان i=0 فهذا الرابط المباشر، لا يوجد قالب
              activeProxyTemplate = '';
            }
            break;
          }
        } catch (e) {
          String errorMsg = e.toString();
          if (e is html.ProgressEvent && e.target is html.HttpRequest) {
            final req = e.target as html.HttpRequest;
            errorMsg = 'Status: ${req.status}, StatusText: ${req.statusText}';
          }
          print('[VIDSTACK] ❌ Proxy Failed ($proxyUrl): $errorMsg');
        }
      }
    } else {
      // للفيديو العادي (MP4) استخدم الأول
      workingProxiedUrl = proxies.first;
    }

    // Fallback: إذا فشل الجميع، استخدم الأول كملجأ أخير
    if (workingProxiedUrl == null) {
      print('[VIDSTACK] ⚠️ All proxies failed. Using primary fallback.');
      workingProxiedUrl = proxies.isNotEmpty ? proxies.first : finalUrl;
      activeProxyTemplate = proxies.isNotEmpty
          ? proxies.first.split(Uri.encodeComponent(finalUrl))[0]
          : '';
    }

    // 4. Manifest Rewriting
    String sourceToUse = workingProxiedUrl!;

    // إذا كان لدينا محتوى المانيفست (يعني نجحنا في جلبه)، نقوم بإعادة كتابته
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
                // نستخدم نفس البروكسي الذي نجح
                return 'URI="${activeProxyTemplate}${Uri.encodeComponent(keyUri)}"';
              });
            }
            rewrittenLines.add(line);
            continue;
          }

          String segmentUrl = line;

          // أ) حل الرابط النسبي
          if (!segmentUrl.startsWith('http')) {
            segmentUrl = baseUrl.resolve(segmentUrl).toString();
          }

          // ب) إضافة التوكين (هام جداً للحماية)
          if (parentQueryParams.isNotEmpty) {
            if (!segmentUrl.contains('?')) {
              segmentUrl += '?$parentQueryParams';
            }
          }

          // ج) تغليف الرابط بالبروكسي (الناجح)
          // نتأكد فقط أنه غير مغلف بالفعل
          if (!segmentUrl.startsWith(activeProxyTemplate)) {
            segmentUrl =
                '$activeProxyTemplate${Uri.encodeComponent(segmentUrl)}';
          }

          rewrittenLines.add(segmentUrl);
        }

        final rewrittenContent = rewrittenLines.join('\n');

        // DEBUG: Print the rewritten manifest to verify URLs
        print('[VIDSTACK] Rewritten Manifest (First 500 chars):');
        print(rewrittenContent.length > 500
            ? rewrittenContent.substring(0, 500)
            : rewrittenContent);

        final blob = html.Blob([rewrittenContent], 'application/x-mpegurl');
        sourceToUse = html.Url.createObjectUrlFromBlob(blob);
        print(
            '[VIDSTACK] Manifest Rewritten & Serving Blob using $activeProxyTemplate');
      } catch (e) {
        print('[VIDSTACK] Manifest Rewriting Failed: $e');
        sourceToUse = workingProxiedUrl!;
      }
    }

    // Fix: Pass source as a JS Object to avoid "undefined" errors in Vidstack
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

    // Use js_util to set the property directly on the element
    js_util.setProperty(_currentPlayer!, 'src', srcObj);
    _currentPlayer!.setAttribute('title', 'Live Stream');
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
      key: ValueKey(widget.url), // Force rebuild if URL changes completely
      viewType: 'vidstack-player',
      onPlatformViewCreated: (int viewId) {
        final element = vidstackViews[viewId];
        if (element == null) return;

        element.innerHtml = '';

        // --- CSS Styles (نفس الستايل السابق) ---
        final style = html.StyleElement();
        style.innerText = """
          .vds-player { 
            width: 100%; height: 100%; background-color: #000; overflow: hidden;
            --media-brand: #7C52D8;
            --media-focus-ring: 0 0 0 3px rgba(124, 82, 216, 0.5);
          }
          media-icon { width: 28px; height: 28px; }
          .vds-overlay-header {
            position: absolute; top: 0; left: 0; width: 100%; padding: 10px 20px;
            background: linear-gradient(to bottom, rgba(0,0,0,0.8), transparent);
            display: flex; align-items: center; z-index: 100; opacity: 0;
            transition: opacity 0.3s ease; pointer-events: none;
          }
          /* Logic for showing overlay: 
             1. User is active (user-idle="false") OR Video Paused.
             2. Mouse Hover (Only on devices with mouse to avoid sticky hover on mobile). */
          .vds-player[paused] .vds-overlay-header,
          .vds-player[user-idle="false"] .vds-overlay-header {
            opacity: 1; pointer-events: auto;
          }
          @media (hover: hover) {
            .vds-player:hover .vds-overlay-header {
              opacity: 1; pointer-events: auto;
            }
          }
          .vds-back-btn {
            background: rgba(255, 255, 255, 0.1); border-radius: 50%;
            width: 40px; height: 40px; cursor: pointer; display: flex;
            align-items: center; justify-content: center; color: white;
            margin-right: 15px; border: none;
          }
          .vds-links-container {
            display: flex; gap: 10px; overflow-x: auto; flex: 1; 
            padding: 5px; align-items: center; scrollbar-width: none;
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
        player.className = 'vds-player';
        _currentPlayer = player;

        // الخصائص الأساسية
        player.setAttribute('autoplay', 'true');
        player.setAttribute('playsinline', 'true');
        player.setAttribute('crossorigin', 'true'); // تصحيح لـ CORS
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
        overlay.querySelector('.vds-back-btn')!.onClick.listen((_) {
          if (mounted) Navigator.of(context).maybePop();
        });

        // Links
        final linksContainer = overlay.querySelector('.vds-links-container')!;
        _linksContainer = linksContainer;

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

            btn.onClick.listen((_) {
              _loadSource(urlStr);
              _updateActiveButton(urlStr);
            });
            linksContainer.append(btn);
          }
        }
        player.append(overlay);

        // --- Event Listeners & Auto-Play Fix ---

        // 1. استمع لحدث "يمكن التشغيل" بدلاً من إجبار التشغيل فوراً
        player.addEventListener('can-play', (event) {
          print('[VIDSTACK] Media Ready - Attempting Play');
          try {
            final playPromise = js_util.callMethod(player, 'play', []);
            if (playPromise != null) {
              js_util.promiseToFuture(playPromise).then((_) {
                print('[VIDSTACK] Playback started successfully');
              }).catchError((e) {
                // AbortError is common when switching sources quickly or auto-play logic interferes
                print('[VIDSTACK] Play request handled: $e');
              });
            }
          } catch (e) {
            print('[VIDSTACK] Data connection to play failed: $e');
          }
        });

        // 2. معالجة الأخطاء
        // 2. معالجة الأخطاء
        player.addEventListener('error', (event) {
          print('[VIDSTACK] Error Event Triggered');
          try {
            // استخدام js_util لاستخراج تفاصيل الخطأ العميق
            final detail =
                js.context['Object'].callMethod('getPrototypeOf', [event]);
            // أو محاولة الوصول المباشر
            final eventObj = js.JsObject.fromBrowserObject(event);
            print('[VIDSTACK] Event Type: ${eventObj['type']}');

            // محاولة الوصول لـ detail (مشتركة في CustomEvent)
            if (eventObj.hasProperty('detail')) {
              final detail = eventObj['detail'];
              print('[VIDSTACK] Error Detail Object: $detail');
              // تفاصيل HLS often inside detail
              if (detail != null) {
                final code = detail['code'];
                final message = detail['message'];
                print(
                    '[VIDSTACK] HLS/Media Error: Code=$code, Message=$message');
              }
            }
          } catch (e) {
            print('[VIDSTACK] Error extraction failed: $e');
          }
        });

        element.append(player);

        // تحميل المصدر الأولي
        _loadSource(initialUrl);
      },
    );
  }
}
