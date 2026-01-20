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
            
            /* FORCE ALL TOP CONTROLS (Left/Right) TO BOTTOM RIGHT */
            media-controls-group[data-position^="top"] {
              display: flex !important;
              position: absolute !important;
              top: auto !important;
              bottom: 80px !important; /* Safe distance above timeline */
              right: 20px !important;
              left: auto !important;   /* Override 'left' from top-left groups */
              flex-direction: row-reverse !important;
              z-index: 99 !important;
              pointer-events: auto !important;
            }

            .vds-controls-spacer { 
              display: none !important; 
            }
            
            /* Ensure buttons inside are visible and clickable */
            media-menu-button, media-mute-button {
              display: block !important;
              visibility: visible !important;
              pointer-events: auto !important;
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

          // Build Layout
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

          // Providers
          mediaPlayer.append(html.Element.tag('media-provider'));

          // GESTURES (Since we removed the default layout, we need to add these back)
          // Toggle Play/Pause on Tap
          final gesturePlay = html.Element.tag('media-gesture');
          gesturePlay.setAttribute('event', 'pointerup');
          gesturePlay.setAttribute('action', 'toggle:paused');
          mediaPlayer.append(gesturePlay);

          // Double Tap to Seek (+/- 10s)
          final gestureSeekFwd = html.Element.tag('media-gesture');
          gestureSeekFwd.setAttribute('event', 'dblpointerup');
          gestureSeekFwd.setAttribute('action', 'seek:10');
          mediaPlayer.append(gestureSeekFwd);

          final gestureSeekRew = html.Element.tag('media-gesture');
          gestureSeekRew.setAttribute('event', 'dblpointerup');
          gestureSeekRew.setAttribute('action', 'seek:-10');
          mediaPlayer.append(gestureSeekRew);

          // CONTROLS LAYER (Custom Manual Build)
          final controls = html.Element.tag('media-controls');
          controls.style.position = 'absolute';
          controls.style.top = '0';
          controls.style.left = '0';
          controls.style.width = '100%';
          controls.style.height = '100%';
          // Pointer events logic usually handled by CSS, but let's be safe:
          // controls.style.pointerEvents = 'none'; // Individual buttons will re-enable it

          // 1. BOTTOM CONTROLS GROUP (The only one we want!)
          final bottomGroup = html.Element.tag('media-controls-group');
          bottomGroup.className = 'vds-controls-group';
          // Force layout
          bottomGroup.style.display = 'flex';
          bottomGroup.style.alignItems = 'center';
          bottomGroup.style.width = '100%';
          bottomGroup.style.position = 'absolute';
          bottomGroup.style.bottom = '0'; // Pinned to bottom
          bottomGroup.style.left = '0';
          bottomGroup.style.padding = '20px';
          bottomGroup.style.boxSizing = 'border-box';
          // Gradient background for readability
          bottomGroup.style.background =
              'linear-gradient(to top, rgba(0,0,0,0.8), transparent)';
          bottomGroup.style.pointerEvents = 'auto'; // Enable clicks
          bottomGroup.style.zIndex = '999';

          // ADD BUTTONS TO BOTTOM GROUP

          // Play Button
          bottomGroup.append(html.Element.tag('media-play-button'));

          // Spacer just in case
          final spacer = html.DivElement();
          spacer.style.width = '10px';
          bottomGroup.append(spacer);

          // Time Slider (Seek Bar)
          final timeSlider = html.Element.tag('media-time-slider');
          timeSlider.style.flex = '1'; // Take remaining space
          bottomGroup.append(timeSlider);

          // Time Label
          // bottomGroup.append(html.Element.tag('media-time')); // Optional, can be inside slider

          // Mute Button (Volume)
          bottomGroup.append(html.Element.tag('media-mute-button'));

          // Settings Menu (The problem child!)
          final settingsButton = html.Element.tag('media-menu-button');
          settingsButton.setAttribute(
              'placement', 'top end'); // Pop upwards to the right
          settingsButton.setAttribute('tooltip', 'Settings');
          bottomGroup.append(settingsButton);

          // Fullscreen
          bottomGroup.append(html.Element.tag('media-fullscreen-button'));

          // Append Group to Controls
          controls.append(bottomGroup);

          // Append Controls to Player
          mediaPlayer.append(controls);

          element.append(mediaPlayer);

          // NO Shadow DOM Injection needed because we own the Light DOM now!
        }
      },
    );
  }
}
