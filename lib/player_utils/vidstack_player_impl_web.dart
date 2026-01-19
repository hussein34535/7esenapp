import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'dart:ui_web' as ui_web;
import 'package:hesen/player_utils/video_player_web.dart'; // Import the registry
import 'package:hesen/services/web_proxy_service.dart';

class VidstackPlayerImpl extends StatefulWidget {
  final String url;
  const VidstackPlayerImpl({required this.url, Key? key}) : super(key: key);

  @override
  State<VidstackPlayerImpl> createState() => _VidstackPlayerImplState();
}

class _VidstackPlayerImplState extends State<VidstackPlayerImpl> {
  // Use a unique ID for each instance to avoid collisions if multiple players existed (though unlikely here)
  final String _viewIdPrefix = 'vidstack_container_';
  late String _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    // Force Landscape for viewing experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didUpdateWidget(covariant VidstackPlayerImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _currentUrl = widget.url;
      _updatePlayerSource();
    }
  }

  void _updatePlayerSource() {
    // We need to find the element in the DOM and update it.
    // Since HtmlElementView creates the element inside the shadow root or iframe depending on mode,
    // accessing it via ID defined in the factory is the most reliable way if we know the ID.
    // However, the factory is registered once.
    // A better approach for dynamic updates in Flutter Web with HtmlElementView is to use the `onPlatformViewCreated` callback if possible,
    // but HtmlElementView doesn't expose the created ID directly to the factory easily unless we manage IDs.

    // Instead, we will search for our specific container ID pattern if we can,
    // OR we simply re-render. Re-rendering HtmlElementView usually works but might be heavy.
    // Let's try to locate the media-player element inside our container.

    // Actually, creating a new UniqueKey for HtmlElementView forces a partial reload which might be safest for switching streams cleanly in web.
    setState(() {});
  }

  @override
  void dispose() {
    // Reset to portrait or system default when player is closed
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the type of stream to set the correct provider/type if needed.
    // Vidstack auto-detects pretty well, but we can hint.
    String streamType = '';
    if (_currentUrl.endsWith('.m3u8')) {
      streamType = 'application/x-mpegurl'; // HLS
    } else if (_currentUrl.contains('youtube')) {
      streamType = 'video/youtube';
    }

    // We register the factory such that it creates a container.
    // Here we need to pass parameters or handle setup.
    // To keep it simple: We will use a unique key to force recreation of the view when URL changes,
    // and rely on the factory (which we'll update to be smarter) OR
    // we define the factory here dynamically? No, factory must
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Web Player
          HtmlElementView(
            key: ValueKey(widget.url),
            viewType: 'vidstack-player',
            onPlatformViewCreated: (int viewId) {
              final containerId = 'vidstack-container-$viewId';
              final element = vidstackViews[viewId];

              if (element != null) {
                element.innerHtml = '';
                final style = html.StyleElement();
                // Customize Spinner - WHITE Color
                style.innerText = """
                  .vds-player {
                    width: 100%;
                    height: 100%;
                    background-color: black;
                  }
                  /* Improve spinner visibility */
                  media-spinner {
                    --video-spinner-color: #ffffff;
                    opacity: 1 !important;
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
          ),

          // 2. Custom Back Button Overlay
          Positioned(
            top: 20,
            left: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
