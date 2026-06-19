import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:hesen/models/match_model.dart';
import 'package:hesen/models/highlight_model.dart';

Future<void> initializeDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('device_id') == null) {
    await prefs.setString('device_id', const Uuid().v4());
  }
}

Future<Map<String, dynamic>> processFetchedData(List<dynamic> results) async {
  final uuid = Uuid();

  final fetchedChannels = results[0] ?? [];
  final fetchedNews = results[1] ?? [];

  final List<Match> fetchedMatches = [];
  if (results[2] != null && results[2] is List) {
    for (var item in (results[2] as List)) {
      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          item is Match ? item.toJson() : item,
        );
        fetchedMatches.add(Match.fromJson(data));
      } catch (e) {
        debugPrint("Match error: $e");
      }
    }
  }

  final List<dynamic> fetchedGoals = (results[3] as List<dynamic>?) ?? [];

  final List<Highlight> fetchedHighlights = [];
  if (results[4] != null && results[4] is List) {
    for (var item in (results[4] as List)) {
      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          item is Highlight ? item.toJson() : item,
        );
        fetchedHighlights.add(Highlight.fromJson(data));
      } catch (e) {
        debugPrint("Highlight error: $e");
      }
    }
  }

  final List<dynamic> fetchedCategories = (results[5] as List<dynamic>?) ?? [];

  Map<String, Map<String, dynamic>> categoryMap = {};

  for (var catData in fetchedCategories) {
    if (catData is! Map) continue;
    final cat = Map<String, dynamic>.from(catData);
    final catId = cat['id']?.toString() ?? uuid.v4();
    categoryMap[catId] = {
      'id': catId,
      'name': cat['name'] ?? 'Unknown',
      'is_premium': cat['is_premium'] ?? false,
      'sort_order': cat['sort_order'] ?? 0,
      'image': cat['image'],
      'channels': <Map<String, dynamic>>[],
    };
  }

  for (var channelData in fetchedChannels) {
    if (channelData is! Map) continue;
    final channel = Map<String, dynamic>.from(channelData);
    final categories = channel['categories'] as List<dynamic>? ?? [];

    if (categories.isEmpty) {
      const unCatId = 'uncategorized';
      categoryMap.putIfAbsent(
        unCatId,
        () => {
          'id': unCatId,
          'name': 'قنوات أخرى',
          'sort_order': 9999,
          'channels': <Map<String, dynamic>>[],
        },
      );
      (categoryMap[unCatId]!['channels'] as List).add(channel);
    } else {
      for (var cat in categories) {
        if (cat is! Map) continue;
        final catId = cat['id']?.toString() ?? uuid.v4();
        final entry = categoryMap.putIfAbsent(
          catId,
          () => {
            'id': catId,
            'name': cat['name'] ?? 'Unknown',
            'is_premium': cat['is_premium'] ?? false,
            'sort_order': cat['sort_order'] ?? 0,
            'image': cat['image'],
            'channels': <Map<String, dynamic>>[],
          },
        );
        (entry['channels'] as List).add(channel);
      }
    }
  }

  List<Map<String, dynamic>> processedChannels = categoryMap.values.toList();
  processedChannels.sort(
    (a, b) =>
        (a['sort_order'] as int? ?? 0).compareTo(b['sort_order'] as int? ?? 0),
  );

  fetchedNews.sort((a, b) {
    try {
      return DateTime.parse(
        b['date'].toString(),
      ).compareTo(DateTime.parse(a['date'].toString()));
    } catch (e) {
      return 0;
    }
  });
  fetchedGoals.sort((a, b) {
    try {
      return DateTime.parse(
        b['createdAt'].toString(),
      ).compareTo(DateTime.parse(a['createdAt'].toString()));
    } catch (e) {
      return 0;
    }
  });

  return {
    'channels': processedChannels,
    'news': fetchedNews,
    'matches': fetchedMatches,
    'goals': fetchedGoals,
    'highlights': fetchedHighlights,
  };
}

Future<List<Map<String, dynamic>>> processRefreshedChannelsData(
  List<dynamic> args,
) async {
  final List<dynamic> fetchedChannels = args[0] as List<dynamic>;
  final List<dynamic> fetchedCategories = args[1] as List<dynamic>;
  const uuid = Uuid();

  Map<String, Map<String, dynamic>> categoryMap = {};

  for (var catData in fetchedCategories) {
    if (catData is! Map) continue;
    final cat = Map<String, dynamic>.from(catData);
    final catId = cat['id']?.toString() ?? uuid.v4();
    categoryMap[catId] = {
      'id': catId,
      'name': cat['name'] ?? 'Unknown',
      'is_premium': cat['is_premium'] ?? false,
      'sort_order': cat['sort_order'] ?? 0,
      'image': cat['image'],
      'channels': <Map<String, dynamic>>[],
    };
  }

  for (var channelData in fetchedChannels) {
    if (channelData is! Map) continue;
    final channel = Map<String, dynamic>.from(channelData);

    if (channel['id'] == null) {
      channel['id'] = uuid.v4();
    }

    final categories = channel['categories'] as List<dynamic>? ?? [];

    if (categories.isEmpty) {
      const unCatId = 'uncategorized';
      categoryMap.putIfAbsent(
        unCatId,
        () => {
          'id': unCatId,
          'name': 'قنوات أخرى',
          'sort_order': 9999,
          'channels': <Map<String, dynamic>>[],
        },
      );
      (categoryMap[unCatId]!['channels'] as List).add(channel);
    } else {
      for (var cat in categories) {
        if (cat is! Map) continue;
        final catId = cat['id']?.toString() ?? uuid.v4();
        final Map<String, dynamic> entry = categoryMap.putIfAbsent(
          catId,
          () => {
            'id': catId,
            'name': cat['name'] ?? 'Unknown',
            'is_premium': cat['is_premium'] ?? false,
            'sort_order': cat['sort_order'] ?? 0,
            'image': cat['image'],
            'channels': <Map<String, dynamic>>[],
          },
        );
        (entry['channels'] as List).add(channel);
      }
    }
  }

  List<Map<String, dynamic>> processedChannels = categoryMap.values.toList();
  processedChannels.sort((a, b) {
    final orderA = a['sort_order'] as int? ?? 0;
    final orderB = b['sort_order'] as int? ?? 0;
    return orderA.compareTo(orderB);
  });

  return processedChannels;
}

Future<List<dynamic>> processRefreshedNewsData(
  List<dynamic> fetchedNews,
) async {
  fetchedNews.sort((a, b) {
    final bool aHasDate = a is Map && a['date'] != null;
    final bool bHasDate = b is Map && b['date'] != null;
    if (!aHasDate && !bHasDate) return 0;
    if (!aHasDate) return 1;
    if (!bHasDate) return -1;
    try {
      final dateA = DateTime.parse(a['date'].toString());
      final dateB = DateTime.parse(b['date'].toString());
      return dateB.compareTo(dateA);
    } catch (e) {
      if (aHasDate && bHasDate) return 0;
      if (aHasDate) return 1;
      if (bHasDate) return -1;
      return 0;
    }
  });
  return fetchedNews;
}

Future<List<dynamic>> processRefreshedGoalsData(
  List<dynamic> fetchedGoals,
) async {
  fetchedGoals.sort((a, b) {
    final bool aHasDate = a is Map && a['createdAt'] != null;
    final bool bHasDate = b is Map && b['createdAt'] != null;
    if (!aHasDate && !bHasDate) return 0;
    if (!aHasDate) return 1;
    if (!bHasDate) return -1;
    try {
      final dateA = DateTime.parse(a['createdAt'].toString());
      final dateB = DateTime.parse(b['createdAt'].toString());
      return dateB.compareTo(dateA);
    } catch (e) {
      if (aHasDate && bHasDate) return 0;
      if (aHasDate) return 1;
      if (bHasDate) return -1;
      return 0;
    }
  });
  return fetchedGoals;
}
