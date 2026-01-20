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
  void _loadSource(String rawUrl) {
    if (_currentPlayer == null) return;

    String finalUrl = rawUrl;

    // منطق خاص لروابط IPTV لإضافة الامتداد إذا كان ناقصاً
    if ((finalUrl.contains(':8080') || finalUrl.contains(':80')) &&
        !finalUrl.contains('.m3u8')) {
      finalUrl = '$finalUrl.m3u8';
    }

    final proxiedUrl = WebProxyService.proxiedUrl(finalUrl);

    print('[VIDSTACK] Loading Source: $proxiedUrl');

    _currentPlayer!.setAttribute('src', proxiedUrl);
    _currentPlayer!.setAttribute('title', 'Live Stream'); // إعادة تعيين العنوان

    // تحديد النوع بدقة مهم جداً لـ HLS
    if (finalUrl.contains('.m3u8')) {
      _currentPlayer!.setAttribute('type', 'application/x-mpegurl');
    } else if (finalUrl.contains('.mp4')) {
      _currentPlayer!.setAttribute('type', 'video/mp4');
    } else {
      // إزالة النوع لتركه يتعرف تلقائياً
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
        player.addEventListener('error', (event) {
          print('[VIDSTACK] Error Event Triggered');
        });

        element.append(player);

        // تحميل المصدر الأولي
        _loadSource(initialUrl);
      },
    );
  }
}
