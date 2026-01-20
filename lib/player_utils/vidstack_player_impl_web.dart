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

          // GESTURES
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

          // CONTROLS LAYER
          final controls = html.Element.tag('media-controls');
          controls.style.position = 'absolute';
          controls.style.top = '0';
          controls.style.left = '0';
          controls.style.width = '100%';
          controls.style.height = '100%';
          controls.style.pointerEvents =
              'none'; // Allow clicks to pass through to gestures

          // DARK GRADIENT OVERLAY AT BOTTOM
          final gradient = html.DivElement();
          gradient.style.position = 'absolute';
          gradient.style.bottom = '0';
          gradient.style.left = '0';
          gradient.style.width = '100%';
          gradient.style.height = '120px'; // Cover bottom area
          gradient.style.background =
              'linear-gradient(to top, rgba(0,0,0,0.9), transparent)';
          gradient.style.pointerEvents = 'none';
          controls.append(gradient);

          // 1. BOTTOM CONTROLS GROUP
          final bottomGroup = html.Element.tag('media-controls-group');
          bottomGroup.className = 'vds-controls-group';
          bottomGroup.style.display = 'flex';
          bottomGroup.style.alignItems = 'center';
          bottomGroup.style.width = '100%';
          bottomGroup.style.position = 'absolute';
          bottomGroup.style.bottom = '0';
          bottomGroup.style.left = '0';
          bottomGroup.style.padding = '10px 20px 20px 20px'; // B-L-R padding
          bottomGroup.style.boxSizing = 'border-box';
          bottomGroup.style.pointerEvents = 'auto'; // Re-enable clicks
          bottomGroup.style.zIndex = '100';

          // HELPER: Create SVG Icon via DOM (Bypasses Sanitizer)
          html.Element createSvgIcon(String pathData) {
            final svg = html.document
                .createElementNS('http://www.w3.org/2000/svg', 'svg');
            svg.setAttribute('viewBox', '0 0 24 24');
            svg.setAttribute('fill', 'white');
            svg.style.width = '28px';
            svg.style.height = '28px';
            final path = html.document
                .createElementNS('http://www.w3.org/2000/svg', 'path');
            path.setAttribute('d', pathData);
            svg.append(path);
            return svg;
          }

          // PLAY BUTTON
          final playButton = html.Element.tag('media-play-button');
          final playSlot = html.DivElement();
          playSlot.setAttribute('slot', 'play');
          playSlot.append(createSvgIcon('M8 5v14l11-7z'));

          final pauseSlot = html.DivElement();
          pauseSlot.setAttribute('slot', 'pause');
          pauseSlot.append(createSvgIcon('M6 19h4V5H6v14zm8-14v14h4V5h-4z'));

          final replaySlot = html.DivElement();
          replaySlot.setAttribute('slot', 'replay');
          replaySlot.append(createSvgIcon(
              'M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z'));

          playButton.append(playSlot);
          playButton.append(pauseSlot);
          playButton.append(replaySlot);
          bottomGroup.append(playButton);

          // SPACER
          final spacer1 = html.DivElement();
          spacer1.style.width = '15px';
          bottomGroup.append(spacer1);

          // TIME SLIDER
          final timeSlider = html.Element.tag('media-time-slider');
          timeSlider.style.flex = '1';
          timeSlider.style.setProperty('--media-slider-height', '4px');
          timeSlider.style.setProperty('--media-slider-thumb-size', '14px');
          timeSlider.style.setProperty('--media-brand', '#7C52D8');
          bottomGroup.append(timeSlider);

          // SPACER
          final spacer2 = html.DivElement();
          spacer2.style.width = '15px';
          bottomGroup.append(spacer2);

          // MUTE BUTTON
          final muteButton = html.Element.tag('media-mute-button');
          final volumeHighSlot = html.DivElement();
          volumeHighSlot.setAttribute('slot', 'volume-high');
          volumeHighSlot.append(createSvgIcon(
              'M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z'));

          final volumeLowSlot = html.DivElement();
          volumeLowSlot.setAttribute('slot', 'volume-low');
          volumeLowSlot.append(createSvgIcon(
              'M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z'));

          final volumeMuteSlot = html.DivElement();
          volumeMuteSlot.setAttribute('slot', 'volume-mute');
          volumeMuteSlot.append(createSvgIcon(
              'M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z'));

          muteButton.append(volumeHighSlot);
          muteButton.append(volumeLowSlot);
          muteButton.append(volumeMuteSlot);
          bottomGroup.append(muteButton);

          // FULLSCREEN BUTTON
          final fsButton = html.Element.tag('media-fullscreen-button');
          final enterFsSlot = html.DivElement();
          enterFsSlot.setAttribute('slot', 'enter');
          enterFsSlot.append(createSvgIcon(
              'M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z'));

          final exitFsSlot = html.DivElement();
          exitFsSlot.setAttribute('slot', 'exit');
          exitFsSlot.append(createSvgIcon(
              'M5 16h3v3h2v-5H5v2zm3-8H5v2h5V5H8v3zm6 11h2v-3h3v-2h-5v5zm2-11V5h-2v5h5V8h-3z'));

          fsButton.append(enterFsSlot);
          fsButton.append(exitFsSlot);
          bottomGroup.append(fsButton);

          // Append Controls
          controls.append(bottomGroup);
          mediaPlayer.append(controls);

          element.append(mediaPlayer); // Add player to DOM
        }
      },
    );
  }
}
