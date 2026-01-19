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
    // Return the Web Player directly (No custom overlays)
    return HtmlElementView(
      key: ValueKey(widget.url), // Force rebuild when URL changes
      viewType: 'vidstack-player',
      onPlatformViewCreated: (int viewId) {
        final element = vidstackViews[viewId];

        if (element != null) {
          element.innerHtml = '';
          final style = html.StyleElement();
          // Customize Spinner - WHITE Color, but let it hide via default behavior
          style.innerText = """
            .vds-player { 
              width: 100%; 
              height: 100%; 
              background-color: black; 
            }
            media-spinner {
              --video-spinner-color: #ffffff;
            }
          """;
          element.append(style);

          final mediaPlayer = html.Element.tag('media-player');
          mediaPlayer.className = 'vds-player';

          // Proxy & Config
          final proxiedUrl = WebProxyService.proxiedUrl(widget.url);
          mediaPlayer.setAttribute('src', proxiedUrl);
          mediaPlayer.setAttribute('autoplay', 'true');
          mediaPlayer.setAttribute('muted', 'true');
          mediaPlayer.setAttribute('playsinline', 'true');
          mediaPlayer.setAttribute('load', 'eager');
          mediaPlayer.setAttribute('aspect-ratio', '16/9');

          // Providers & Layouts
          mediaPlayer.append(html.Element.tag('media-provider'));
          mediaPlayer.append(html.Element.tag('media-video-layout'));
          element.append(mediaPlayer);
        }
      },
    );
  }
}
