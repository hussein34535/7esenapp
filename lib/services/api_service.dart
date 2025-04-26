import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hesen/models/match_model.dart';

class ApiService {
  static const String baseUrl = 'https://st9.onrender.com/api';

  static Future<List> fetchChannelCategories() async {
    try {
      final response = await http.get(Uri.parse(
          '$baseUrl/channel-categories?populate[channels][sort][0]=createdAt:asc&sort=createdAt:asc'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List.from(data['data'] ?? []);
      }
    } catch (e) {}
    return [];
  }

  static Future<List> fetchNews() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/news?populate=*'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List.from(data['data'] ?? []);
      } else {}
    } catch (e) {}
    return [];
  }

  static Future<List<Match>> fetchMatches() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/matches?populate=*'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List matchesJson = data['data'] ?? [];

        final matches = matchesJson.map((match) {
          return Match.fromJson(match);
        }).toList();
        return matches;
      }
    } catch (e, stackTrace) {}
    return [];
  }

  static Future<List<dynamic>> fetchGoals() async {
    try {
      final response = await http
          .get(Uri.parse('https://st9.onrender.com/api/goals?populate=*'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      }
      throw Exception('Failed to load goals');
    } catch (e) {
      // Handle potential network or parsing errors
      // print('Error fetching goals: $e');
      return []; // Return empty list on error
    }
  }
}
