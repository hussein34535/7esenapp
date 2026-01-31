import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hesen/models/match_model.dart';
import 'package:hesen/services/web_proxy_service.dart';

class ApiService {
  static const String baseUrl = 'https://7esentvbackend.vercel.app/api/mobile';

  /// Fetches all channels with categories and stream links.
  /// Premium stream URLs will be null if user is not subscribed.
  static Future<List<dynamic>> fetchChannels() async {
    final url = '$baseUrl/channels';

    final response = await http.get(
      Uri.parse(WebProxyService.proxiedUrl(url)),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List.from(data['data'] ?? []);
      }
      throw Exception('API returned success=false');
    } else {
      throw Exception('Failed to load channels: ${response.statusCode}');
    }
  }

  /// Fetches all categories.
  static Future<List<dynamic>> fetchCategories() async {
    final url = '$baseUrl/categories';

    final response = await http.get(
      Uri.parse(WebProxyService.proxiedUrl(url)),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List.from(data['data'] ?? []);
      }
      throw Exception('API returned success=false');
    } else {
      throw Exception('Failed to load categories: ${response.statusCode}');
    }
  }

  /// Fetches all news items.
  /// Premium news links will be null if user is not subscribed.
  static Future<List<dynamic>> fetchNews() async {
    final url = '$baseUrl/news';
    final response = await http.get(
      Uri.parse(WebProxyService.proxiedUrl(url)),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return List.from(data['data'] ?? []);
      }
      throw Exception('API returned success=false');
    } else {
      throw Exception('Failed to load news: ${response.statusCode}');
    }
  }

  /// Fetches all matches.
  /// Premium stream URLs will be null if user is not subscribed.
  static Future<List<Match>> fetchMatches() async {
    final url = '$baseUrl/matches';
    final response = await http.get(
      Uri.parse(WebProxyService.proxiedUrl(url)),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final List matchesJson = data['data'] ?? [];
        return matchesJson.map((match) => Match.fromJson(match)).toList();
      }
      throw Exception('API returned success=false');
    } else {
      throw Exception('Failed to load matches: ${response.statusCode}');
    }
  }

  /// Fetches all goals.
  /// Premium goal URLs will be null if user is not subscribed.
  static Future<List<dynamic>> fetchGoals() async {
    final url = '$baseUrl/goals';
    final response = await http.get(
      Uri.parse(WebProxyService.proxiedUrl(url)),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'] ?? [];
      }
      throw Exception('API returned success=false');
    } else {
      throw Exception('Failed to load goals: ${response.statusCode}');
    }
  }
}
