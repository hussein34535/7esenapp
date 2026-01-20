import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:hesen/player_utils/video_player_web.dart'; // Import the registry
import 'package:hesen/services/web_proxy_service.dart';

class VidstackPlayerImpl extends StatefulWidget {
  final String url;
  const VidstackPlayerImpl({required this.url, Key? key}) : super(key: key);

  @override
  State<VidstackPlayerImpl> createState() => _VidstackPlayerImplState();
}

class _VidstackPlayerImplState extends State<VidstackPlayerImpl> {
  html.Element? _currentPlayer;
  int? _currentViewId;

  @override
  void didUpdateWidget(VidstackPlayerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ إذا تغير الرابط، حدّث Player
    if (oldWidget.url != widget.url) {
      _updatePlayerSource();
    }
  }

  void _updatePlayerSource() {
    if (_currentPlayer != null && _currentViewId != null) {
      print('[VIDSTACK] Updating source to: ${widget.url}');
      _currentPlayer!.setAttribute('src', widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: ValueKey(widget.url), // ✅ Force rebuild on URL change
      viewType: 'vidstack-player',
      onPlatformViewCreated: (int viewId) {
        _currentViewId = viewId;
        final element = vidstackViews[viewId];
        if (element == null) return;

        // 1. تنظيف
        element.innerHtml = '';

        // 2. Styles
        final style = html.StyleElement();
        style.innerText = """
          .vds-player { 
            width: 100%; 
            height: 100%; 
            background: #000;
            direction: ltr !important;
            --media-brand: #7C52D8;
            --media-focus: #5E3CB5;
          }
        """;
        element.append(style);

        // 3. إنشاء Player
        final player = html.Element.tag('media-player');
        player.className = 'vds-player';
        _currentPlayer = player; // ✅ حفظ المرجع

        // 4. تحديد المصدر
        player.setAttribute('src', widget.url);
        player.setAttribute('autoplay', 'true');
        player.setAttribute('controls', 'true');
        player.setAttribute('load', 'eager');
        player.setAttribute('crossorigin', 'anonymous');

        // 5. Provider
        final provider = html.Element.tag('media-provider');
        player.append(provider);

        // 6. Layout
        final layout = html.Element.tag('media-video-layout');
        player.append(layout);

        // 7. Error Handling
        player.addEventListener('error', (event) {
          print('[VIDSTACK] Error: ${widget.url}');
        });

        player.addEventListener('can-play', (event) {
          print('[VIDSTACK] Ready to play: ${widget.url}');
        });

        element.append(player);
      },
    );
  }
}
