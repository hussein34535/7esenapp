import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'stream_details.dart';

// This function MUST be a top-level function to be used with compute.
Future<StreamDetails> handleYoutubeStream(String url) async {
  // This outer try-catch is to catch fatal errors that might crash the isolate.
  try {
    debugPrint('[YOUTUBE HANDLER] Attempting to process URL: $url');
    final yt = YoutubeExplode();
    try {
      final videoId = VideoId(url);
    
      debugPrint('[YOUTUBE HANDLER] Getting video metadata...');
      debugPrint('[YOUTUBE HANDLER] Getting stream manifest...');
      final manifest = await yt.videos.streamsClient.getManifest(videoId, ytClients: [
        YoutubeApiClient.android,
        YoutubeApiClient.safari,
      ]);
      debugPrint('[YOUTUBE HANDLER] Successfully got stream manifest.');

      // Helper: codec priority (lower is better)
      int _codecPriority(VideoStreamInfo v) {
        final codec = v.videoCodec.toString().toLowerCase();
        final container = v.container.name.toLowerCase();
        final isMp4 = container == 'mp4';
        // Prefer AVC/H.264, then VP9, then AV1
        if (codec.contains('avc') || codec.contains('h264') || codec.contains('avc1')) {
          return isMp4 ? 0 : 1;
        }
        if (codec.contains('vp09') || codec.contains('vp9')) {
          return isMp4 ? 2 : 3;
        }
        if (codec.contains('av01') || codec.contains('av1')) {
          return isMp4 ? 4 : 5;
        }
        return isMp4 ? 6 : 7;
      }

      // Get muxed, video-only, and audio-only streams
      final muxed = manifest.muxed.toList()
        ..sort((a, b) {
          final aIsMp4 = a.container.name.toLowerCase() == 'mp4';
          final bIsMp4 = b.container.name.toLowerCase() == 'mp4';
          if (aIsMp4 != bIsMp4) return aIsMp4 ? -1 : 1;
          final heightCmp =
              b.videoResolution.height.compareTo(a.videoResolution.height);
          if (heightCmp != 0) return heightCmp;
          return b.bitrate.compareTo(a.bitrate);
        });

      final videoOnly = manifest.video.toList()
        ..sort((a, b) {
          final codecCmp = _codecPriority(a).compareTo(_codecPriority(b));
          if (codecCmp != 0) return codecCmp;
          final aIsMp4 = a.container.name.toLowerCase() == 'mp4';
          final bIsMp4 = b.container.name.toLowerCase() == 'mp4';
          if (aIsMp4 != bIsMp4) return aIsMp4 ? -1 : 1;
          final heightCmp =
              b.videoResolution.height.compareTo(a.videoResolution.height);
          if (heightCmp != 0) return heightCmp;
          return b.bitrate.compareTo(a.bitrate);
        });

      final audioOnly = manifest.audioOnly.toList()
        ..sort((a, b) {
          final aIsMp4 = a.container.name.toLowerCase() == 'mp4';
          final bIsMp4 = b.container.name.toLowerCase() == 'mp4';
          if (aIsMp4 != bIsMp4) return aIsMp4 ? -1 : 1; // Prioritize MP4
          return b.bitrate.compareTo(a.bitrate); // Then sort by bitrate
        });

      final Map<String, Map<String, dynamic>> qualitiesMap = {};
      final String currentVideoId = videoId.value;

      // Priority 1: Use muxed streams (video + audio together)
      if (muxed.isNotEmpty) {
        debugPrint('[YOUTUBE HANDLER] Found ${muxed.length} muxed streams with audio');
        for (final s in muxed) {
          final qualityLabel = '${s.videoResolution.height}p';
          if (!qualitiesMap.containsKey(qualityLabel)) {
            qualitiesMap[qualityLabel] = {
              'name': '$qualityLabel - ${s.container.name.toUpperCase()} (مع صوت)',
          'url': s.url.toString(),
          'height': s.videoResolution.height,
              'hasAudio': true,
              'type': 'muxed',
              'videoId': currentVideoId,
            };
            debugPrint('[YOUTUBE HANDLER] Added muxed: $qualityLabel');
          }
        }
      }

      // Priority 2: Use video-only URL + external audio for higher qualities
      // Avoids DASH manifest crash in MediaKit/MPV on Windows (media-kit #973)
      if (videoOnly.isNotEmpty && audioOnly.isNotEmpty) {
        debugPrint('[YOUTUBE HANDLER] Creating video-only + audio for higher qualities');
        final bestAudio = audioOnly.first;

        for (final video in videoOnly) {
          final qualityLabel = '${video.videoResolution.height}p';
          if (!qualitiesMap.containsKey(qualityLabel)) {
            final videoUrl = video.url.toString();
            final audioUrl = bestAudio.url.toString();

            debugPrint('[YOUTUBE HANDLER] Added split quality: $qualityLabel (video=${video.videoCodec} + audio=mp4a.40.2)');

            qualitiesMap[qualityLabel] = {
              'name':
                  '$qualityLabel - ${video.container.name.toUpperCase()} (مع صوت)',
              'url': videoUrl,
              'audioUrl': audioUrl,
              'height': video.videoResolution.height,
              'hasAudio': true,
              'type': 'video_audio_split',
              'videoId': currentVideoId,
              'itag': video.tag,
              'audioItag': bestAudio.tag,
            };
          }
        }
      }

      // Fallback: If still no qualities, use video-only (worst case)
      if (qualitiesMap.isEmpty && videoOnly.isNotEmpty) {
        debugPrint('[YOUTUBE HANDLER] Warning: Creating video-only fallback (NO AUDIO)');
        for (final s in videoOnly) {
          final qualityLabel = '${s.videoResolution.height}p';
          if (!qualitiesMap.containsKey(qualityLabel)) {
            qualitiesMap[qualityLabel] = {
              'name': '$qualityLabel - ${s.container.name.toUpperCase()} (بدون صوت)',
          'url': s.url.toString(),
          'height': s.videoResolution.height,
              'hasAudio': false,
              'type': 'video_only',
            };
            debugPrint('[YOUTUBE HANDLER] Added video-only (no audio): $qualityLabel');
          }
        }
      }

      if (qualitiesMap.isEmpty) {
      throw Exception('No playable streams found for this YouTube video.');
    }

      final qualities = qualitiesMap.values.toList()
        ..sort((a, b) => (b['height'] as int).compareTo(a['height'] as int));

      String? videoUrlToLoad;
      String? audioUrlToLoad;
      int selectedQualityIndex = -1;

      final streamsWithAudio = qualities.where((q) => q['hasAudio'] == true).toList();

      if (streamsWithAudio.isNotEmpty) {
        // Prefer muxed streams first to prevent Data URI playback errors in certain media players
        final muxedStreams = streamsWithAudio.where((q) => q['type'] == 'muxed').toList();
        Map<String, dynamic> preferredStream;

        
        if (muxedStreams.isNotEmpty) {
          preferredStream = muxedStreams.firstWhere(
            (q) => (q['height'] as int) <= 480,
            orElse: () => muxedStreams.first,
          );
        } else {
          preferredStream = streamsWithAudio.firstWhere(
            (q) => (q['height'] as int) <= 480,
            orElse: () => streamsWithAudio.last,
          );
        }
        videoUrlToLoad = preferredStream['url'] as String?;
        audioUrlToLoad = preferredStream['audioUrl'] as String?;
        debugPrint('[YOUTUBE HANDLER] Selected stream with audio: ${preferredStream['name']}');
      } else if (qualities.isNotEmpty) {
        final preferredStream = qualities.firstWhere(
          (q) => (q['height'] as int) <= 480,
          orElse: () => qualities.first,
        );
        videoUrlToLoad = preferredStream['url'] as String?;
        audioUrlToLoad = preferredStream['audioUrl'] as String?;
        debugPrint('[YOUTUBE HANDLER] Selected stream (warning - no audio): ${preferredStream['name']}');
      }

      if (videoUrlToLoad == null) {
        throw Exception('No streams could be selected.');
      }

      selectedQualityIndex =
          qualities.indexWhere((q) => q['url'] == videoUrlToLoad);
      if (selectedQualityIndex == -1) selectedQualityIndex = 0;

      String urlToPrint = videoUrlToLoad;
      if (urlToPrint.startsWith('data:')) {
        urlToPrint = '${urlToPrint.substring(0, 50)}...';
      }
      debugPrint('--- [YOUTUBE HANDLER] FINAL SELECTED STREAM ---');
      debugPrint('URL: $urlToPrint');
      debugPrint('Quality Name: ${qualities[selectedQualityIndex]['name']}');
      debugPrint('Has Audio: ${qualities[selectedQualityIndex]['hasAudio']}');
      debugPrint('Type: ${qualities[selectedQualityIndex]['type']}');
      debugPrint('---');

    return StreamDetails(
      videoUrlToLoad: videoUrlToLoad,
      audioUrlToLoad: audioUrlToLoad,
      fetchedQualities: qualities,
      selectedQualityIndex: selectedQualityIndex,
    );
    } catch (e) {
      debugPrint('[YOUTUBE HANDLER] ERROR processing YouTube stream: $e');
      throw Exception('Failed to load YouTube streams: $e');
    } finally {
      yt.close();
    }
  } catch (e, s) {
    // This will catch any other error that was missed, including fatal ones.
    debugPrint('[YOUTUBE HANDLER] FATAL ERROR in isolate: $e');
    debugPrint('[YOUTUBE HANDLER] STACK TRACE: $s');
    throw Exception('A fatal error occurred in the YouTube handler isolate: $e');
  }
}
