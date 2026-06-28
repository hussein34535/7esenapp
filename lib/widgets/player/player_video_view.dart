import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:chewie/chewie.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:hesen/video_player_screen.dart'; // For VideoSize enum
import 'package:hesen/player_utils/vidstack_player_widget.dart';

class PlayerVideoView extends StatelessWidget {
  final String? currentStreamUrl;
  final bool isCurrentStreamApi;
  final List<Map<String, dynamic>> fetchedApiQualities;
  final List<Map<String, dynamic>> validStreamLinks;
  final VideoController? mediaKitController;
  final Player? mediaKitPlayer;
  final ChewieController? chewieController;
  final VideoSize currentVideoSize;
  final UniqueKey playerKey;
  final double screenAspectRatio;
  final int selectedStreamIndex;
  final int selectedApiQualityIndex;

  const PlayerVideoView({
    Key? key,
    required this.currentStreamUrl,
    required this.isCurrentStreamApi,
    required this.fetchedApiQualities,
    required this.validStreamLinks,
    required this.mediaKitController,
    required this.mediaKitPlayer,
    required this.chewieController,
    required this.currentVideoSize,
    required this.playerKey,
    required this.screenAspectRatio,
    required this.selectedStreamIndex,
    required this.selectedApiQualityIndex,
  }) : super(key: key);

  double _getAspectRatioForSize(VideoSize size, double videoAspectRatio) {
    if (videoAspectRatio <= 0) return 16 / 9; // Fallback
    switch (size) {
      case VideoSize.fitWidth:
        return videoAspectRatio;
      case VideoSize.cover:
        return screenAspectRatio; // This will fill the screen
      case VideoSize.ratio16_9:
        return 16 / 9;
      case VideoSize.ratio18_9:
        return 18 / 9;
      case VideoSize.ratio4_3:
        return 4 / 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (currentStreamUrl != null) {
        // 🔒 FILTER: Never pass API URLs (JSON endpoints) to the player as sources.
        final bool isApiUrl = currentStreamUrl!.contains('7esentv-match.vercel.app') || 
                              currentStreamUrl!.contains('okru-api.vercel.app') ||
                              currentStreamUrl!.contains('okru-api');
        
        if (!isApiUrl) {
          return SizedBox.expand(
            child: VidstackPlayerWidget(
              url: currentStreamUrl!,
              streamLinks: (isCurrentStreamApi && fetchedApiQualities.isNotEmpty)
                  ? fetchedApiQualities
                  : validStreamLinks,
              selectedStreamIndex: (isCurrentStreamApi && fetchedApiQualities.isNotEmpty)
                  ? selectedApiQualityIndex
                  : selectedStreamIndex,
            ),
          );
        }
      }
      return Container(color: Colors.black);
    }

    // DESKTOP: Use MediaKit Video widget
    if (!kIsWeb &&
        ((!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) ||
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) ||
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS))) {
      if (mediaKitController != null) {
        // Cover mode: Fill entire screen (may crop video edges)
        if (currentVideoSize == VideoSize.cover) {
          return SizedBox.expand(
            child: Video(
              controller: mediaKitController!,
              controls: null,
              fit: BoxFit.cover, // Fill entire space
            ),
          );
        }

        // Other modes: Use aspect ratio
        final videoWidth = mediaKitPlayer?.state.width ?? 16;
        final videoHeight = mediaKitPlayer?.state.height ?? 9;
        final videoAspectRatio = videoWidth > 0 && videoHeight > 0
            ? videoWidth / videoHeight
            : 16 / 9;

        return Center(
          child: AspectRatio(
            aspectRatio: _getAspectRatioForSize(currentVideoSize, videoAspectRatio),
            child: Video(
              controller: mediaKitController!,
              controls: null,
              fit: BoxFit.contain, // Fit within bounds
            ),
          ),
        );
      }
      return Container(color: Colors.black);
    }

    // MOBILE: Use Chewie
    final chewie = chewieController;
    if (chewie == null || !chewie.videoPlayerController.value.isInitialized) {
      return Container(color: Colors.black);
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _getAspectRatioForSize(
          currentVideoSize,
          chewie.videoPlayerController.value.aspectRatio,
        ),
        child: Chewie(
          key: playerKey,
          controller: chewie,
        ),
      ),
    );
  }
}
