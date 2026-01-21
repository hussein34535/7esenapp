import 'dart:html' as html;
import 'dart:js' as js;
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

    // 1. إذا كان رابط 7esenlink، نطلب الرابط الحقيقي (JSON Mode)
    // هذا يحل مشكلة الـ Redirect + CORS
    if (finalUrl.contains('7esenlink.vercel.app')) {
      try {
        print('[VIDSTACK] Resolving 7esenlink URL: $finalUrl');
        // نضيف ?json=true للرابط
        final jsonUri = Uri.parse(finalUrl).replace(queryParameters: {
          ...Uri.parse(finalUrl).queryParameters,
          'json': 'true'
        });

        // نستخدم fetch من dart:html لأن http package قد تواجه مشاكل CORS أقل هنا
        final response = await html.window.fetch(jsonUri.toString());
        if (response != null) {
          // response is actually a Future<Response> wrapper related
          // Simplified fetch in Dart web can be tricky, fallback to HttpRequest if needed or just use standard logic
          // Let's use standard HttpRequest which is simpler in Dart Web context
          final request = await html.HttpRequest.request(jsonUri.toString());
          final jsonResponse =
              js.context['JSON'].callMethod('parse', [request.responseText]);
          if (jsonResponse['url'] != null) {
            finalUrl = jsonResponse['url'];
            print('[VIDSTACK] Resolved URL: $finalUrl');
          }
        }
      } catch (e) {
        print('[VIDSTACK] Error resolving URL: $e');
        // في حال الفشل، نكمل بالرابط الأصلي (سيفشل غالباً لكن نحاول)
      }
    }

    // 2. منطق خاص لروابط IPTV (تحويل MPEG-TS إلى HLS)
    // النمط المعتاد: http://host:port/user/pass/id
    // النمط المطلوب للويب: http://host:port/live/user/pass/id.m3u8
    if (finalUrl.contains(':8080') ||
        (finalUrl.contains(':80') && !finalUrl.contains('stream.php'))) {
      Uri uri = Uri.parse(finalUrl);
      List<String> segments = List.from(uri.pathSegments);

      // إذا كان الرابط يحتوي على 3 أجزاء (user, pass, id) ولا يبدأ بـ live
      if (segments.length == 3 && segments[0] != 'live') {
        print('[VIDSTACK] Converting TS to HLS (Injecting /live/)');
        segments.insert(0, 'live'); // إضافة live في البداية

        // التأكد من الامتداد .m3u8
        String lastSegment = segments.last;
        if (!lastSegment.endsWith('.m3u8')) {
          segments.last = '$lastSegment.m3u8';
        }

        finalUrl = uri.replace(pathSegments: segments).toString();
      }
      // حالة أخرى: إذا كان ينقصه الامتداد فقط
      else if (!finalUrl.endsWith('.m3u8')) {
        finalUrl = '$finalUrl.m3u8';
      }
    }

    // 3. تغليف الرابط بالبروكسي (CodeTabs)
    final proxiedUrl = WebProxyService.proxiedUrl(finalUrl);

    print('[VIDSTACK] Loading Source (Proxied): $proxiedUrl');

    String sourceToUse = proxiedUrl;

    // ✅ اعتراض ملفات M3U8 لإعادة صياغة الروابط الداخلية (Segments)
    // المشكلة: ملف M3U8 يحتوي على روابط مباشرة (.ts) لا تدعم CORS
    // الحل: تحميل الملف نصياً، إضافة البروكسي قبل كل رابط داخلي، ثم تشغيله كـ Blob
    if (finalUrl.contains('.m3u8') ||
        finalUrl.contains('stream.php') ||
        finalUrl.contains('/live/')) {
      try {
        print('[VIDSTACK] Intercepting Manifest for Rewriting...');
        final content = await html.HttpRequest.getString(proxiedUrl);

        // 1. استخراج الـ Base URL الصحيح (بدون اسم الملف)
        // http://server.com/live/user/pass/132.m3u8 -> http://server.com/live/user/pass/
        // نستخدم finalUrl (الرابط الأصلي) وليس البروكسي
        final uri = Uri.parse(finalUrl);
        final baseUrlString =
            uri.toString().substring(0, uri.toString().lastIndexOf('/') + 1);
        final baseUrl = Uri.parse(baseUrlString);

        print('[VIDSTACK] Base URL for Relative Resolution: $baseUrlString');

        final lines = content.split('\n');
        final rewrittenLines = [];

        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) {
            rewrittenLines.add(line);
            continue;
          }

          // تخطي الأسطر الوصفية (Metadata) ولكن معالجة المفاتيح (Keys)
          if (line.startsWith('#')) {
            if (line.startsWith('#EXT-X-KEY') && line.contains('URI="')) {
              // معالجة مفتاح التشفير اذا كان نسبياً
              line = line.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (match) {
                String keyUri = match.group(1)!;
                if (!keyUri.startsWith('http')) {
                  keyUri = baseUrl.resolve(keyUri).toString();
                }
                return 'URI="${WebProxyService.proxiedUrl(keyUri)}"';
              });
            }
            rewrittenLines.add(line);
            continue;
          }

          // هذا السطر هو رابط لملف (Segment)
          String segmentUrl = line;

          // أ) حل الرابط النسبي
          if (!segmentUrl.startsWith('http')) {
            segmentUrl = baseUrl.resolve(segmentUrl).toString();
          }

          // ب) تغليف الرابط بالبروكسي (CodeTabs)
          if (!segmentUrl.contains('codetabs.com')) {
            segmentUrl = WebProxyService.proxiedUrl(segmentUrl);
          }

          rewrittenLines.add(segmentUrl);
        }

        final rewrittenContent = rewrittenLines.join('\n');

        final blob = html.Blob([rewrittenContent], 'application/x-mpegurl');
        sourceToUse = html.Url.createObjectUrlFromBlob(blob);
        print(
            '[VIDSTACK] Manifest Rewritten & Created Blob (Relative URLs Fixed): $sourceToUse');
      } catch (e) {
        print('[VIDSTACK] Manifest Rewriting Failed: $e');
        // Fallback: Use proxied URL directly
        sourceToUse = proxiedUrl;
      }
    }

    _currentPlayer!.setAttribute('src', sourceToUse);
    _currentPlayer!.setAttribute('title', 'Live Stream');

    // تحديد النوع بدقة مهم جداً لـ HLS
    if (finalUrl.contains('.m3u8') ||
        proxiedUrl.contains('.m3u8') ||
        finalUrl.contains('stream.php') ||
        finalUrl.contains('/live/')) {
      _currentPlayer!.setAttribute('type', 'application/x-mpegurl');
    } else if (finalUrl.contains('.mp4')) {
      _currentPlayer!.setAttribute('type', 'video/mp4');
    } else {
      _currentPlayer!.removeAttribute('type');
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
          .vds-player:hover .vds-overlay-header,
          .vds-player[paused] .vds-overlay-header,
          .vds-player[user-idle="false"] .vds-overlay-header {
            opacity: 1; pointer-events: auto;
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
            js.JsObject.fromBrowserObject(player).callMethod('play');
          } catch (e) {
            print('Play error: \$e');
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
