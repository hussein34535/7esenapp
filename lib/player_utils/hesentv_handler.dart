import 'dart:convert';
import 'package:http/http.dart' as http;
import 'stream_details.dart';

int _findUrlIndexInList(String url, List<Map<String, dynamic>> list) {
  if (url.isEmpty) return -1;
  return list.indexWhere((item) => item['url'] == url);
}

Future<StreamDetails> handleHesenTvStream(String url) async {
  final response = await http.get(Uri.parse(url));

  if (response.statusCode != 200) {
    throw Exception("API call failed with status code: ${response.statusCode}");
  }

  final Map<String, dynamic> data = jsonDecode(response.body);
  List<Map<String, dynamic>> parsedQualities = [];

  // 1. Parse all available qualities from the JSON response
  data.forEach((key, value) {
    if (value != null && value.toString().isNotEmpty) {
      final parts = key.split('@');
      final int quality = int.tryParse(parts[0]) ?? 0;
      final int fps = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      
      parsedQualities.add({
        'key': key,
        'url': value.toString(),
        'quality': quality,
        'fps': fps,
      });
    }
  });

  if (parsedQualities.isEmpty) {
    throw Exception("API call successful but no stream URLs found.");
  }

  // 2. Sort qualities: highest resolution first, then highest FPS first.
  parsedQualities.sort((a, b) {
    int qualityCompare = b['quality'].compareTo(a['quality']);
    if (qualityCompare != 0) {
      return qualityCompare;
    }
    return b['fps'].compareTo(a['fps']);
  });

  // 3. Select the best quality as the default to play
  String videoUrlToLoad = parsedQualities.first['url'];

  // 4. Create the list for the UI display with user-friendly names
  List<Map<String, dynamic>> apiQualitiesForDisplay = parsedQualities.map((q) {
    String name = q['key'];
    // e.g., 720 -> 720p, 720@60 -> 720p@60
    if (int.tryParse(name) != null) {
      name = '${name}p';
    } else {
        name = name.replaceFirstMapped(RegExp(r'(\d+)'), (match) => '${match.group(1)}p');
    }
    return {'name': name, 'url': q['url']};
  }).toList();
  
  // 5. Find the index of the selected stream in the display list
  int selectedQualityIndex = _findUrlIndexInList(videoUrlToLoad, apiQualitiesForDisplay);

  return StreamDetails(
    videoUrlToLoad: videoUrlToLoad,
    fetchedQualities: apiQualitiesForDisplay,
    selectedQualityIndex: selectedQualityIndex,
  );
}
