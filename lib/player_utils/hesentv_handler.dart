import 'dart:convert';
import 'package:http/http.dart' as http;
import 'stream_details.dart';

int _findUrlIndexInList(String url, List<Map<String, dynamic>> list) {
  if (url.isEmpty) return -1;
  return list.indexWhere((item) => item['url'] == url);
}

Future<StreamDetails> handleHesenTvStream(String url) async {
  final response = await http.get(
    Uri.parse(url),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
      'Referer': 'https://7esentv.com/',
      'Origin': 'https://7esentv.com',
      'Accept': '*/*',
    },
  ).timeout(
    const Duration(seconds: 15),
  );

  if (response.statusCode != 200) {
    throw Exception("API call failed with status code: ${response.statusCode}");
  }

  if (response.body.trim().startsWith('#EXTM3U')) {
    final lines = response.body.split('\n');
    List<Map<String, dynamic>> parsedQualities = [];

    // Add 'Auto' quality that uses the master playlist URL
    parsedQualities.add({
      'name': 'Auto',
      'url': url,
      'resolution': 99999, // Highest priority for Auto
    });

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        // Find RESOLUTION=1920x1080
        final resMatch = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(line);
        final nameMatch = RegExp(r'NAME="([^"]+)"').firstMatch(line);

        int height = 0;
        if (resMatch != null) {
          height = int.tryParse(resMatch.group(1) ?? '0') ?? 0;
        }

        String name = "";
        if (nameMatch != null) {
          name = nameMatch.group(1)!;
        } else if (height > 0) {
          name = '${height}p';
        } else {
          name = 'Stream';
        }

        // The next line is usually the stream URL
        if (i + 1 < lines.length) {
          String streamUrl = lines[i + 1].trim();
          // Skip empty lines or other tags
          int j = i + 1;
          while (j < lines.length && (lines[j].trim().isEmpty || lines[j].trim().startsWith('#'))) {
             j++;
          }
          if (j < lines.length) {
              streamUrl = lines[j].trim();
          }

          if (streamUrl.isNotEmpty && !streamUrl.startsWith('#')) {
            if (!streamUrl.startsWith('http')) {
              // Relative URL, resolve it against the final requested URL
              final uri = Uri.parse(response.request?.url.toString() ?? url);
              streamUrl = uri.resolve(streamUrl).toString();
            }

            parsedQualities.add({
              'name': name,
              'url': streamUrl,
              'resolution': height,
            });
          }
        }
      }
    }

    if (parsedQualities.length > 1) {
      // Sort qualities by resolution descending, keep Auto first
      parsedQualities.sort((a, b) {
        if (a['name'] == 'Auto') return -1;
        if (b['name'] == 'Auto') return 1;
        return (b['resolution'] as int).compareTo(a['resolution'] as int);
      });

      return StreamDetails(
        videoUrlToLoad: url,
        fetchedQualities: parsedQualities.map((q) => {'name': q['name'].toString(), 'url': q['url'].toString()}).toList(),
        selectedQualityIndex: 0,
      );
    } else {
      // Fallback if no sub-streams were found
      return StreamDetails(
        videoUrlToLoad: url,
        fetchedQualities: [
          {'name': 'Auto', 'url': url}
        ],
        selectedQualityIndex: 0,
      );
    }
  }

  Map<String, dynamic> data;
  try {
    data = jsonDecode(response.body);
  } catch (e) {
    // Fallback if not JSON and not starting with #EXTM3U but still successful
    return StreamDetails(
      videoUrlToLoad: url,
      fetchedQualities: [
        {'name': 'Stream', 'url': url}
      ],
      selectedQualityIndex: 0,
    );
  }

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
    
    if (name.contains('@')) {
      final parts = name.split('@');
      name = '${parts[0]}p ${parts[1]}fps'; // e.g., 1080p 60fps
    } else if (int.tryParse(name) != null) {
      name = '${name}p'; // e.g., 720p
    } else {
      name = name.replaceFirstMapped(
          RegExp(r'(\d+)'), (match) => '${match.group(1)}p');
    }
    
    return {'name': name, 'url': q['url'].toString()};
  }).toList();

  // 5. Find the index of the selected stream in the display list
  int selectedQualityIndex =
      _findUrlIndexInList(videoUrlToLoad, apiQualitiesForDisplay);

  return StreamDetails(
    videoUrlToLoad: videoUrlToLoad,
    fetchedQualities: apiQualitiesForDisplay,
    selectedQualityIndex: selectedQualityIndex,
  );
}
