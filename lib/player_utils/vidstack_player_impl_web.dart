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
  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      key: ValueKey(widget.url),
      viewType: 'vidstack-player',
      onPlatformViewCreated: (int viewId) {
        final element = vidstackViews[viewId];

        if (element != null) {
          // 1. Clean previous element
          element.innerHtml = '';

          // 2. Add essential styles (mainly for LTR direction)
          final style = html.StyleElement();
          style.innerText = """
            .vds-player { 
              width: 100%; 
              height: 100%; 
              background-color: black;
              direction: ltr !important; 
            }
          """;
          element.append(style);

          // 3. Create Main Player
          final mediaPlayer = html.Element.tag('media-player');
          mediaPlayer.className = 'vds-player';

          // Config & Attributes
          final proxiedUrl = WebProxyService.proxiedUrl(widget.url);
          mediaPlayer.setAttribute('src', proxiedUrl);
          mediaPlayer.setAttribute('title', 'Live Stream');
          mediaPlayer.setAttribute('autoplay', 'true');
          mediaPlayer.setAttribute('load', 'eager');
          mediaPlayer.setAttribute('aspect-ratio', '16/9');

          // 4. Add Media Provider
          mediaPlayer.append(html.Element.tag('media-provider'));

          // 5. Add Default Vidstack Layout (The Magic Line)
          // This automatically handles controls, icons, settings, animations, and responsiveness.
          final defaultLayout = html.Element.tag('media-video-layout');
          // Optional: Add thumbnails if available
          // defaultLayout.setAttribute('thumbnails', 'https://example.com/thumbnails.vtt');

          mediaPlayer.append(defaultLayout);

          // 6. Append Player to the View
          element.append(mediaPlayer);
        }
      },
    );
  }
}
