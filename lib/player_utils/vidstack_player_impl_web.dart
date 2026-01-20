import 'dart:html' as html;
import 'dart:async';
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

          // Layout (Standard Vidstack Layout - Ensures Icons & Gestures work)
          final layout = html.Element.tag('media-video-layout');
          mediaPlayer.append(layout);
          element.append(mediaPlayer);

          // INJECT STYLES INTO SHADOW DOM (Persistent Retry Mechanism)
          // Vidstack loads asynchronously, so we poll for the shadowRoot to be ready.
          // This moves the top controls to the bottom-right FORCEFULLY.
          int retryCount = 0;
          const maxRetries = 50; // Try for 5 seconds (50 * 100ms)

          Timer.periodic(const Duration(milliseconds: 100), (timer) {
            retryCount++;
            if (retryCount > maxRetries) {
              timer.cancel();
              print("Vidstack Injection: Timed out.");
              return;
            }

            try {
              // Try to access shadowRoot
              final shadowRoot = (layout as dynamic).shadowRoot;
              if (shadowRoot != null) {
                // Check if we already injected to avoid duplicates
                final existingStyle =
                    shadowRoot.querySelector('#vds-custom-style');
                if (existingStyle == null) {
                  final shadowStyle = html.StyleElement();
                  shadowStyle.id = 'vds-custom-style';
                  shadowStyle.innerText = """
                      /* NUCLEAR OPTION: FORCE ALL CONTROLS TO BOTTOM */
                      
                      /* 1. Reset Top Groups (Left/Right) to Bottom */
                      media-controls-group[data-position^="top"] {
                        top: auto !important;
                        bottom: 80px !important; /* Above timeline */
                        right: 20px !important;
                        left: auto !important;
                        width: auto !important;
                        flex-direction: row-reverse !important; /* Align buttons right */
                        
                        /* Layout fixes */
                        display: flex !important;
                        align-items: center !important;
                        justify-content: flex-end !important;
                        z-index: 90 !important;
                      }

                      /* 2. Specific fix for overlapping buttons */
                      media-tooltip {
                        z-index: 99 !important;
                      }
                      
                      /* 3. Ensure they are visible */
                      media-menu-button, media-mute-button, media-fullscreen-button {
                        display: block !important;
                        visibility: visible !important;
                        pointer-events: auto !important;
                      }
                    """;
                  shadowRoot.append(shadowStyle);
                  print(
                      "Vidstack Shadow DOM styles injected SUCCESSFULLY on attempt $retryCount.");
                }
                // Success - cancel timer
                timer.cancel();
              }
            } catch (e) {
              // Ignore errors while waiting for DOM
            }
          });
        }
      },
    );
  }
}
