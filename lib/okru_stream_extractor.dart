import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart'; // Added html_unescape

const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)';

Future<String?> getOkruStreamUrl(String videoId) async {
  final headers = {
    'User-Agent': _userAgent,
    'Referer': 'https://ok.ru/',
    'Accept': '*/*',
    'Connection': 'keep-alive',
    // إضافة هيدر مهم عشان نساعد السيرفر
    'Accept-Encoding': 'gzip, deflate',
    'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
    'Origin': 'https://ok.ru',
    'X-Requested-With': 'XMLHttpRequest',
  };

  try {
    // Use Uri.https to correctly handle encoding of special characters in videoId
    final videoUri = Uri.https('ok.ru', '/video/$videoId');
    final res = await http.get(videoUri, headers: headers).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      print('Failed to load ok.ru page: ${res.statusCode}');
      return null;
    }

    // **** ✨ التعديل هنا ✨ ****
    // بدل ما نستخدم res.body مباشرة، هنفك ترميز الـ bytes بنفسنا
    // ده بيحل مشكلة الـ FormatException
    final responseBody = utf8.decode(res.bodyBytes, allowMalformed: true);
    // **************************

    // 2. استخرج data-options من الصفحة باستخدام regex محسّن
    final regex = RegExp(
      r'data-options="(.+?)"', // تم تصحيح الـ regex
      dotAll: true,
    );
    final match = regex.firstMatch(responseBody);
    if (match == null) {
      print('Could not find data-options in video page. Trying metadata API...');
      // محاولة مباشرة لاستدعاء واجهة الميتاداتا الرسمية
      try {
        final metaApi = Uri.https('ok.ru', '/dk', {
          'cmd': 'videoPlayerMetadata',
          'mid': videoId,
        });
        final apiRes = await http
            .get(metaApi, headers: headers)
            .timeout(const Duration(seconds: 15));
        if (apiRes.statusCode == 200) {
          final metaJson = utf8.decode(apiRes.bodyBytes, allowMalformed: true);
          final metadata = json.decode(metaJson) as Map<String, dynamic>;
          if (metadata['hlsManifestUrl'] != null) {
            return Uri.encodeFull(metadata['hlsManifestUrl']);
          }
          if (metadata['hlsMasterPlaylistUrl'] != null) {
            return Uri.encodeFull(metadata['hlsMasterPlaylistUrl']);
          }
          // نفس fallback للـ MP4 ≤ 720p
          if (metadata['videos'] is List) {
            String? best;
            int bestQ = -1;
            for (final v in metadata['videos']) {
              final name = v['name']?.toString() ?? '';
              final url = v['url']?.toString();
              if (url == null) continue;
              int q = -1;
              final m = RegExp(r'([0-9]+)p').firstMatch(name);
              if (m != null) q = int.tryParse(m.group(1)!) ?? -1;
              if (q > bestQ && q <= 720) {
                bestQ = q;
                best = url;
              }
            }
            if (best != null) return Uri.encodeFull(best);
          }
        }
      } catch (e) {
        print('OKRU metadata API fallback failed: $e');
      }
      return null;
    }

    // الـ JSON بيكون URL-encoded → لازم نفكّه، ثم فك ترميز HTML entities
    final rawDataOptions = match.group(1)!;
    // print("OKRU_DEBUG: Raw data-options before sanitize and decode: $rawDataOptions");

    final unescape = HtmlUnescape();
    // Just unescape HTML entities like &quot; to get a valid JSON string.
    final cleanedDataOptions = unescape.convert(rawDataOptions);

    Map<String, dynamic> flashvars;
    try {
      flashvars = json.decode(cleanedDataOptions)['flashvars'];
    } catch (e) {
      print('Error decoding flashvars: $e');
      return null;
    }

    // 3. هات الميتاداتا
    String metadataJson = "";
    if (flashvars['metadata'] != null) {
      metadataJson = flashvars['metadata'];
    } else if (flashvars['metadataUrl'] != null) {
      try {
        String metaUrlString = flashvars['metadataUrl'];
        // print("OKRU_DEBUG: metaUrlString before sanitize and parse: $metaUrlString");

        // The URL for the POST request might also be malformed
        final sanitizedMetaUrl =
            _safeUriDecode(metaUrlString, isDecoding: false);
        if (sanitizedMetaUrl == null) {
          print(
              'OKRU_ERROR: metadataUrl is malformed and could not be sanitized.');
          return null;
        }

        final metaRes = await http
            .post(
              Uri.parse(sanitizedMetaUrl),
              headers: headers,
            )
            .timeout(const Duration(seconds: 15));
        if (metaRes.statusCode != 200) {
          print('Failed to load metadata URL: ${metaRes.statusCode}');
          return null;
        }
        metadataJson = utf8.decode(metaRes.bodyBytes,
            allowMalformed: true); // تعديل هنا كمان احتياطي
      } catch (e) {
        print('Error fetching metadata from URL: $e');
        return null;
      }
    } else {
      print('No metadata or metadataUrl found.');
      return null;
    }

    Map<String, dynamic> metadata;
    try {
      metadata = json.decode(metadataJson);
    } catch (e) {
      print('Error decoding metadata JSON: $e');
      return null;
    }

    // 4. استخرج لينك HLS أولاً
    if (metadata['hlsManifestUrl'] != null) {
      return Uri.encodeFull(metadata['hlsManifestUrl']);
    }
    if (metadata['hlsMasterPlaylistUrl'] != null) {
      return Uri.encodeFull(metadata['hlsMasterPlaylistUrl']);
    }
    if (metadata['liveDashManifestUrl'] != null) {
      return Uri.encodeFull(metadata['liveDashManifestUrl']);
    }

    // MP4 fallback with quality weights
    const qualityWeights = {
      "full": 1080,
      "hd": 720,
      "sd": 480,
      "low": 360,
      "lowest": 240,
      "mobile": 144,
    };

    String? bestUrl;
    int bestQuality = -1;

    if (metadata['videos'] is List) {
      for (var video in metadata['videos']) {
        if (video['url'] == null || video['name'] == null) continue;
        final name = video['name'].toString();
        int q = -1;

        final qm = RegExp(r'(\d+)p').firstMatch(name);
        if (qm != null) {
          q = int.parse(qm.group(1)!);
        } else if (qualityWeights.containsKey(name)) {
          q = qualityWeights[name]!;
        }

        // فضّل حتى 720p لتحسين التوافق على الأجهزة القديمة
        if (q > bestQuality && q <= 720) {
          bestQuality = q;
          bestUrl = video['url'];
        }
      }
    }
    if (bestUrl != null) {
      return Uri.encodeFull(bestUrl);
    }

    print('No HLS or MP4 stream URL found.');
    return null;
  } catch (e, s) {
    print('!!!!!!!!!!!!! FATAL ERROR IN getOkruStreamUrl !!!!!!!!!!!!!');
    print('VIDEO ID: $videoId');
    print('ERROR: $e');
    print('STACK TRACE: $s');
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    return null;
  }
}

/// A helper function to safely decode/sanitize a URI string.
/// If isDecoding is true, it tries to Uri.decodeFull.
/// If isDecoding is false, it just sanitizes for Uri.parse.
String? _safeUriDecode(String source, {bool isDecoding = true}) {
  try {
    // First, sanitize the string to fix any broken percent encodings.
    String sanitized = source.replaceAllMapped(
        RegExp(r'%(?![0-9a-fA-F]{2})'), (match) => '%25');

    // Then, attempt the primary operation (decode or just return sanitized).
    if (isDecoding) {
      return Uri.decodeFull(sanitized);
    } else {
      return sanitized;
    }
  } catch (e) {
    print("OKRU_ERROR: _safeUriDecode failed for string: $source. Error: $e");
    // Return null if any part of the process fails.
    return null;
  }
}
