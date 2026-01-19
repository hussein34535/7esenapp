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
          // Customize Spinner & Menu Position
          style.innerText = """
            /* Force LTR to prevent RTL flipping issues */
            .vds-player { 
              width: 100%; 
              height: 100%; 
              background-color: black;
              direction: ltr !important; 
            }
            media-spinner {
              --video-spinner-color: #ffffff;
            }
            
            /* Hide the default top-right group container to prevent ghosts */
            media-controls-group[data-position="top right"] {
              display: none !important;
            }

            /* Forcefully position the buttons at Bottom Right */
            media-menu-button {
              position: absolute !important;
              bottom: 60px !important; /* Above bottom bar */
              right: 20px !important;
              top: auto !important;
              left: auto !important;
              z-index: 99 !important;
            }
            
            media-mute-button {
              position: absolute !important;
              bottom: 60px !important;
              right: 60px !important; /* Next to settings */
              top: auto !important;
              left: auto !important;
              z-index: 99 !important;
            }

            /* Ensure main controls don't hide them */
            media-controls {
              opacity: 1;
              pointer-events: none; /* Let clicks pass through empty areas */
            }
            media-controls * {
              pointer-events: auto; /* Re-enable for buttons */
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
