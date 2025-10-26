import 'dart:convert';
import 'package:http/http.dart' as http;
import 'stream_details.dart';

int _findUrlIndexInList(String url, List<Map<String, dynamic>> list) {
  if (url.isEmpty) return -1;
  return list.indexWhere((item) => item['url'] == url);
}

Future<StreamDetails> handleHesenTvStream(String url) async {
  final response = await http.get(Uri.parse(url));
  String? videoUrlToLoad;
  List<Map<String, dynamic>> apiQualitiesForDisplay = [];
  int selectedQualityIndex = -1;

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = jsonDecode(response.body);
    const qualityOrder = ['720', '480', '380', '1080'];
    Map<String, String> qualityUrlMap = {};

    data.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        qualityUrlMap[key] = value.toString();
        if (qualityOrder.contains(key)) {
          apiQualitiesForDisplay
              .add({'name': '${key}p', 'url': value.toString()});
        }
      }
    });

    apiQualitiesForDisplay.sort((a, b) {
      int indexA = qualityOrder.indexOf(a['name']!.replaceAll('p', ''));
      int indexB = qualityOrder.indexOf(b['name']!.replaceAll('p', ''));
      return indexA.compareTo(indexB);
    });

    for (String qualityKey in qualityOrder) {
      if (qualityUrlMap.containsKey(qualityKey)) {
        videoUrlToLoad = qualityUrlMap[qualityKey];
        break;
      }
    }
    videoUrlToLoad ??=
        qualityUrlMap.values.firstWhere((v) => v.isNotEmpty, orElse: () => '');

    if (videoUrlToLoad.isNotEmpty) {
      selectedQualityIndex =
          _findUrlIndexInList(videoUrlToLoad, apiQualitiesForDisplay);
    } else {
      throw Exception("API call successful but no stream URLs found.");
    }
  } else {
    throw Exception("API call failed with status code: ${response.statusCode}");
  }

  return StreamDetails(
    videoUrlToLoad: videoUrlToLoad,
    fetchedQualities: apiQualitiesForDisplay,
    selectedQualityIndex: selectedQualityIndex,
  );
}
