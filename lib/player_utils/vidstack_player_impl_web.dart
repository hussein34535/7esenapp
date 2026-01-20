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
            /* CUSTOM SLOT VISIBILITY FOR MANUAL DIVs */
            
            /* PLAY BUTTON */
            media-play-button [slot="play"] { display: block !important; }
            media-play-button [slot="pause"] { display: none !important; }
            media-play-button [slot="replay"] { display: none !important; }
            
            media-play-button[data-pressed] [slot="play"] { display: none !important; }
            media-play-button[data-pressed] [slot="pause"] { display: block !important; }

            /* MUTE BUTTON */
            media-mute-button [slot="volume-high"] { display: block !important; }
            media-mute-button [slot="volume-low"] { display: none !important; }
            media-mute-button [slot="volume-mute"] { display: none !important; }

            media-mute-button[data-muted] [slot="volume-high"] { display: none !important; }
            media-mute-button[data-muted] [slot="volume-low"] { display: none !important; }
            media-mute-button[data-muted] [slot="volume-mute"] { display: block !important; }

            /* FULLSCREEN BUTTON */
            media-fullscreen-button [slot="enter"] { display: block !important; }
            media-fullscreen-button [slot="exit"] { display: none !important; }

            media-fullscreen-button[aria-pressed="true"] [slot="enter"] { display: none !important; }
            media-fullscreen-button[aria-pressed="true"] [slot="exit"] { display: block !important; }

            /* General Icon Sizing Fixes */
            media-controls-group svg {
               vertical-align: middle;
            }
            /* CUSTOM SLOT VISIBILITY removed as we use standard media-icon */
            media-controls-group svg {
               vertical-align: middle;
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

          // PLAY BUTTON
          final playButton = html.Element.tag('media-play-button');

          final playIcon = html.Element.tag('media-icon');
          playIcon.setAttribute('type', 'play');
          playIcon.setAttribute('slot', 'play');

          final pauseIcon = html.Element.tag('media-icon');
          pauseIcon.setAttribute('type', 'pause');
          pauseIcon.setAttribute('slot', 'pause');

          final replayIcon = html.Element.tag('media-icon');
          replayIcon.setAttribute('type', 'replay');
          replayIcon.setAttribute('slot', 'replay');

          playButton.append(playIcon);
          playButton.append(pauseIcon);
          playButton.append(replayIcon);
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

          final volumeHighIcon = html.Element.tag('media-icon');
          volumeHighIcon.setAttribute('type', 'volume-high');
          volumeHighIcon.setAttribute('slot', 'volume-high');

          final volumeLowIcon = html.Element.tag('media-icon');
          volumeLowIcon.setAttribute('type', 'volume-low');
          volumeLowIcon.setAttribute('slot', 'volume-low');

          final volumeMuteIcon = html.Element.tag('media-icon');
          volumeMuteIcon.setAttribute('type', 'volume-mute');
          volumeMuteIcon.setAttribute('slot', 'volume-mute');

          muteButton.append(volumeHighIcon);
          muteButton.append(volumeLowIcon);
          muteButton.append(volumeMuteIcon);
          bottomGroup.append(muteButton);

          // FULLSCREEN BUTTON
          final fsButton = html.Element.tag('media-fullscreen-button');

          final fsEnterIcon = html.Element.tag('media-icon');
          fsEnterIcon.setAttribute('type', 'fullscreen');
          fsEnterIcon.setAttribute('slot', 'enter');

          final fsExitIcon = html.Element.tag('media-icon');
          fsExitIcon.setAttribute('type', 'fullscreen-exit');
          fsExitIcon.setAttribute('slot', 'exit');

          fsButton.append(fsEnterIcon);
          fsButton.append(fsExitIcon);
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
