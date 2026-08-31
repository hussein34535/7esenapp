import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hesen/services/web_proxy_service.dart';
import 'package:hesen/okru_stream_extractor.dart';
import 'package:hesen/player_utils/hesentv_handler.dart';
import 'package:hesen/player_utils/okru_playlist_parser.dart';
import 'package:hesen/player_utils/youtube_handler.dart';
import 'package:hesen/player_utils/stream_details.dart';

class PlayerStreamResolver {
  /// Validates and filters raw stream links to ensure they have correct URLs and non-empty names.
  static List<Map<String, dynamic>> validateStreamLinks(List<Map<String, dynamic>> rawLinks) {
    return rawLinks.where((link) {
      final name = link['name']?.toString();
      final url = link['url']?.toString();

      // Basic validation: must have a URL and a non-empty name
      if (name == null ||
          name.trim().isEmpty ||
          url == null ||
          url.isEmpty ||
          name.trim().toLowerCase() == 'stream') {
        return false;
      }

      // Advanced validation: check for empty JSON rich text names like [{"text":""}]
      if (name.trim().startsWith('[') && name.trim().endsWith(']')) {
        try {
          final List<dynamic> nameParts = jsonDecode(name);
          if (nameParts.isNotEmpty) {
            bool allPartsEmpty = nameParts.every((part) {
              if (part is Map && part.containsKey('text')) {
                final text = part['text']?.toString();
                return text == null || text.trim().isEmpty;
              }
              return false; // Invalid part structure, treat as empty
            });
            if (allPartsEmpty) {
              return false; // It's an empty rich text, ignore it.
            }
          }
        } catch (e) {
          // Not valid JSON, so it's a regular name. Let it pass.
        }
      }

      return true; // The link is valid
    }).toList();
  }

  /// Resolves the stream URL and details (qualities) for both Web and Mobile/Desktop.
  static Future<StreamDetails> resolve(String urlToProcess, {required bool isWeb}) async {
    String? videoUrlToLoad;

    if (isWeb) {
      // ========== WEB STREAM RESOLUTION ==========
      // 🛡️ GUARD: If URL is already proxied, use it directly - prevents double-proxying 404!
      if (urlToProcess.contains('hi.husseinh2711.workers.dev')) {
        debugPrint('[WEB] URL already proxied, using directly: $urlToProcess');
        videoUrlToLoad = urlToProcess;
      } else if (urlToProcess.contains('youtube.com') || urlToProcess.contains('youtu.be')) {
        // Vidstack handles YouTube natively - NO PROXY NEEDED
        debugPrint('[WEB] YouTube detected - using Vidstack directly');
        videoUrlToLoad = urlToProcess;
      } else if (urlToProcess.contains('ok.ru/')) {
        // Ok.ru - Resolve to direct stream for Vidstack on Web
        String? videoId;
        if (urlToProcess.contains('/video/')) {
          videoId = urlToProcess.split('/video/').last.split('?').first;
        } else if (urlToProcess.contains('/live/')) {
          videoId = urlToProcess.split('/live/').last.split('?').first;
        }

        if (videoId != null && videoId.isNotEmpty) {
          debugPrint('[WEB] Resolving Ok.ru stream for ID: $videoId');
          final resolvedUrl = await getOkruStreamUrl(videoId);
          if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
            videoUrlToLoad = WebProxyService.proxiedUrl(resolvedUrl);
            debugPrint('[WEB] Resolved Ok.ru stream: $videoUrlToLoad');
          } else {
            // ❌ Extraction failed, return empty StreamDetails to show error
            debugPrint('[WEB] ❌ Failed to extract Ok.ru stream.');
            return StreamDetails();
          }
        } else {
          // Not a valid ID, proxy original URL as last resort
          videoUrlToLoad = WebProxyService.proxiedUrl(urlToProcess);
        }
      } else if (urlToProcess.startsWith('https://7esentv-match.vercel.app')) {
        // Guard: Skip if the video ID is empty
        final matchUri = Uri.tryParse(urlToProcess);
        final videoId = matchUri?.queryParameters['id'] ?? '';
        if (videoId.isEmpty) {
          debugPrint('[WEB] ❌ Empty video ID in match URL, skipping: $urlToProcess');
          return StreamDetails();
        }
        debugPrint('[WEB] Resolving 7esentv-match API stream...');
        final streamDetails = await handleHesenTvStream(urlToProcess);
        final resolvedUrl = streamDetails.videoUrlToLoad ?? '';
        final isDailymotion = resolvedUrl.contains('dmcdn.net') || resolvedUrl.contains('dailymotion');
        if (isDailymotion) {
          videoUrlToLoad = resolvedUrl;
          debugPrint('[WEB] Resolved Dailymotion stream - Using direct URL (no proxy): $videoUrlToLoad');
        } else {
          videoUrlToLoad = WebProxyService.proxiedUrl(resolvedUrl);
          debugPrint('[WEB] Resolved stream - Using proxied URL: $videoUrlToLoad');
        }
        return StreamDetails(
          videoUrlToLoad: videoUrlToLoad,
          fetchedQualities: streamDetails.fetchedQualities,
          selectedQualityIndex: streamDetails.selectedQualityIndex,
        );
      } else if (urlToProcess.contains('youtube.com') || urlToProcess.contains('youtu.be')) {
        debugPrint('[WEB] Resolving YouTube stream...');
        final streamDetails = await handleYoutubeStream(urlToProcess);
        return streamDetails;
      } else {
        // Dailymotion, Twitch, or any external embed page - use directly (no proxy needed, Vidstack handles it)
        // Only proxy actual HLS .m3u8 or direct stream files
        final isHlsOrStream = (urlToProcess.contains('.m3u8') ||
            urlToProcess.contains('.ts') ||
            urlToProcess.contains('manifest') ||
            urlToProcess.contains('/live/') ||
            urlToProcess.contains('.mp4')) &&
            !urlToProcess.contains('dailymotion') &&
            !urlToProcess.contains('dmcdn.net');

        // Streams served from our own domains already have a trusted
        // certificate. Proxying them would break native HLS on iOS, because
        // relative playlist segments resolve against the proxy host.
        final Uri? parsedUrl = Uri.tryParse(urlToProcess);
        final bool isOwnTrustedHost = parsedUrl != null &&
            parsedUrl.scheme == 'https' &&
            (parsedUrl.host == '7esentv.com' ||
                parsedUrl.host.endsWith('.7esentv.com'));

        if (isOwnTrustedHost) {
          videoUrlToLoad = urlToProcess;
          debugPrint('[WEB] Trusted own host - Using direct URL (no proxy): $videoUrlToLoad');
        } else if (isHlsOrStream) {
          videoUrlToLoad = WebProxyService.proxiedUrl(urlToProcess);
          debugPrint('[WEB] HLS/Stream - Using proxied URL: $videoUrlToLoad');
        } else {
          // External embed (Dailymotion, etc.) - Vidstack handles natively
          videoUrlToLoad = urlToProcess;
          debugPrint('[WEB] External embed - Using direct URL (no proxy): $videoUrlToLoad');
        }
      }
      return StreamDetails(videoUrlToLoad: videoUrlToLoad);
    } else {
      // ========== NATIVE MOBILE/DESKTOP RESOLUTION ==========
      if (urlToProcess.contains('youtube.com') || urlToProcess.contains('youtu.be')) {
        debugPrint('[MOBILE] URL identified as YouTube. Processing in background...');
        final streamDetails = await compute(handleYoutubeStream, urlToProcess);
        return streamDetails;
      } else if (urlToProcess.contains('ok.ru/')) {
        String? videoId;
        if (urlToProcess.contains('/video/')) {
          videoId = urlToProcess.split('/video/').last.split('?').first;
        } else if (urlToProcess.contains('/live/')) {
          videoId = urlToProcess.split('/live/').last.split('?').first;
        }

        if (videoId != null && videoId.isNotEmpty) {
          final streamUrl = await getOkruStreamUrl(videoId);
          if (streamUrl != null && streamUrl.isNotEmpty) {
            videoUrlToLoad = streamUrl;
            List<Map<String, dynamic>> qualities = [];
            int selectedIdx = -1;
            if (videoUrlToLoad.toLowerCase().contains('.m3u8')) {
              qualities = await parseOkruQualities(videoUrlToLoad);
              if (qualities.isNotEmpty) {
                selectedIdx = 0;
              }
            }
            return StreamDetails(
              videoUrlToLoad: videoUrlToLoad,
              fetchedQualities: qualities,
              selectedQualityIndex: selectedIdx,
            );
          } else {
            throw Exception('Could not extract a playable URL from ok.ru');
          }
        } else {
          videoUrlToLoad = urlToProcess; // Not a recognized ok.ru format, play raw
          return StreamDetails(videoUrlToLoad: videoUrlToLoad);
        }
      } else if (urlToProcess.contains('okcdn.ru') &&
          urlToProcess.toLowerCase().contains('.m3u8')) {
        videoUrlToLoad = urlToProcess;
        final qualities = await parseOkruQualities(videoUrlToLoad);
        int selectedIdx = qualities.isNotEmpty ? 0 : -1;
        return StreamDetails(
          videoUrlToLoad: videoUrlToLoad,
          fetchedQualities: qualities,
          selectedQualityIndex: selectedIdx,
        );
      } else if (urlToProcess.startsWith('https://7esentv-match.vercel.app')) {
        // Guard: Skip if the video ID is empty (e.g. ?id= with no value)
        final matchUri = Uri.tryParse(urlToProcess);
        final videoId = matchUri?.queryParameters['id'] ?? '';
        if (videoId.isEmpty) {
          debugPrint('[MOBILE] ❌ Empty video ID in match URL, skipping: $urlToProcess');
          return StreamDetails();
        }
        final streamDetails = await handleHesenTvStream(urlToProcess);
        return streamDetails;
      } else if (urlToProcess.contains('youtube.com') || urlToProcess.contains('youtu.be')) {
        debugPrint('[MOBILE] Resolving YouTube stream...');
        final streamDetails = await handleYoutubeStream(urlToProcess);
        return streamDetails;
      } else {
        debugPrint('[HESEN PLAYER] URL did not match any handler. Playing raw URL.');
        videoUrlToLoad = urlToProcess;
        return StreamDetails(videoUrlToLoad: videoUrlToLoad);
      }
    }
  }
}
