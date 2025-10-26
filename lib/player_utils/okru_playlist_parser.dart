// file: player_utils/okru_playlist_parser.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

const String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64-x64)';

Future<List<Map<String, dynamic>>> parseOkruQualities(String masterPlaylistUrl) async {
  try {
    final response = await http.get(
      Uri.parse(masterPlaylistUrl),
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      return [];
    }

    final m3u8Content = utf8.decode(response.bodyBytes);
    final lines = m3u8Content.split('\n');
    final List<Map<String, dynamic>> qualities = [];

    // *** (1) Extract the base part from the main link ***
    final baseUrl = masterPlaylistUrl.substring(0, masterPlaylistUrl.lastIndexOf('/') + 1);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('#EXT-X-STREAM-INF')) {
        if (i + 1 < lines.length) {
          final relativeUrl = lines[i + 1].trim();
          
          if (relativeUrl.isNotEmpty && !relativeUrl.startsWith('#')) {
            // *** (2) Build the full link ***
            final absoluteUrl = Uri.parse(baseUrl).resolve(relativeUrl).toString();
            
            String qualityName = _extractResolution(line);

            // Only add the quality if a valid name was extracted
            if (qualityName.isNotEmpty) {
              qualities.add({
                'name': qualityName,
                'url': absoluteUrl, // <-- Use the full link
              });
            }
          }
        }
      }
    }
    
    // Add an "Auto" option that points to the main link itself
    qualities.insert(0, {
      'name': 'Auto',
      'url': masterPlaylistUrl,
    });
    
    final uniqueQualities = <String, Map<String, dynamic>>{};
    for (var quality in qualities) {
      uniqueQualities[quality['name']] = quality;
    }

    return uniqueQualities.values.toList();
    
  } catch (e) {
    print("Error parsing OK.ru qualities: $e");
    return [];
  }
}

String _extractResolution(String line) {
  if (line.contains('RESOLUTION=')) {
    try {
      final resolutionPart = line.split('RESOLUTION=')[1].split(',')[0];
      final height = resolutionPart.split('x')[1];
      return '${height}p';
    } catch (e) {
      // fallback: return empty string if resolution cannot be parsed
      return '';
    }
  }
  // Return empty string if RESOLUTION tag is not found
  return '';
}
