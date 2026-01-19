import 'dart:html' as html;
import 'package:flutter/material.dart';
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
    // we define the factory here dynamically? No, factory must be registered globally usually.

    // BETTER APPROACH:
    // Define a custom factory that accepts params? No, standard PlatformView API is limited.
    //
    // We register the factory ONCE.
    // Inside the factory, we return a Div.
    // We use a simplified approach: The factory creates a Div with a known ID scheme based on `viewId`.
    // BUT we don't know the `viewId` in `build`.
    //
    // SO: We will use a dedicated customized element or just straightforward JS interop.

    // Let's try this:
    // 1. `HtmlElementView`
    // 2. `onPlatformViewCreated`: (id) => _setupPlayer(id)

    return HtmlElementView(
      key: ValueKey(widget.url), // Force rebuild when URL changes
      viewType: 'vidstack-player',
      onPlatformViewCreated: (int viewId) {
        final containerId = 'vidstack-container-$viewId';
        print(
            '[VIDSTACK] onPlatformViewCreated - viewId: $viewId, looking for container: $containerId');

        // Access the element directly from our registry
        final element = vidstackViews[viewId];

        if (element != null) {
          print('[VIDSTACK] Container found. Initializing player...');
          element.innerHtml = ''; // Clear previous

          final mediaPlayer = html.Element.tag('media-player');
          mediaPlayer.className = 'vds-player';

          print('[VIDSTACK] Source URL: ${widget.url}');
          // Wrap with proxy to handle CORS/Redirects on Web
          // Debug: Direct (requires disabled security). Release: Vercel Proxy.
          final proxiedUrl = WebProxyService.proxiedUrl(widget.url);
          mediaPlayer.setAttribute('src', proxiedUrl);

          // Set autoplay, controls, etc.
          mediaPlayer.setAttribute('autoplay', 'true');
          mediaPlayer.setAttribute(
              'playsinline', 'true'); // Required for iOS inline playback
          // mediaPlayer.setAttribute('controls', 'true'); // REMOVED: conflicting with custom layout
          mediaPlayer.setAttribute('load', 'eager');
          mediaPlayer.setAttribute(
              'aspect-ratio', '16/9'); // Default aspect ratio

          // Add Media Provider
          final mediaProvider = html.Element.tag('media-provider');
          mediaPlayer.append(mediaProvider);

          // Add Default Layout (Controls)
          final defaultLayout = html.Element.tag('media-video-layout');
          // No need for detailed slotting if using default layout component
          // The CDN script imports default layouts usually.
          // Checking Vidstack docs: <media-video-layout> is correct for default layout in recent versions if using the right bundle.
          // If we used the "player" bundle in index.html, it includes defaults.

          // Actually, <media-video-layout> might need slots.
          // Newest Vidstack uses <media-audio-layout> or <media-video-layout>.
          mediaPlayer.append(defaultLayout);

          element.append(mediaPlayer);
          print('[VIDSTACK] Player initialized and appended.');
        } else {
          print('[VIDSTACK] ERROR: Container $containerId NOT FOUND.');
        }
      },
    );
  }
}
