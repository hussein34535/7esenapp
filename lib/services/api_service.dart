import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hesen/models/match_model.dart';
import 'package:hesen/services/web_proxy_service.dart';

class ApiService {
  static const String baseUrl = 'https://st9.onrender.com/api';

  static Future<List> fetchChannelCategories() async {
    final url =
        '$baseUrl/channel-categories?populate[channels][sort][0]=createdAt:asc&sort=createdAt:asc';

    // نستخدم proxiedUrl لتمرير الطلب عبر كلاود فلير
    final response = await http.get(
      Uri.parse(WebProxyService.proxiedUrl(url)),
      // ❌ حذفنا الـ headers لأنها تسبب مشاكل CORS
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List.from(data['data'] ?? []);
    } else {
      throw Exception(
          'Failed to load channel categories: ${response.statusCode}');
    }
  }

  static Future<List> fetchNews() async {
    final url = '$baseUrl/news?populate=*';
    final response = await http.get(
      Uri.parse(WebProxyService.proxiedUrl(url)),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List.from(data['data'] ?? []);
    } else {
      throw Exception('Failed to load news: ${response.statusCode}');
    }
  }

  static Future<List<Match>> fetchMatches() async {
    final url = '$baseUrl/matches?populate=*';
    final response = await http.get(
      Uri.parse(WebProxyService.proxiedUrl(url)),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List matchesJson = data['data'] ?? [];

      final matches = matchesJson.map((match) {
        return Match.fromJson(match);
      }).toList();
      return matches;
    } else {
      throw Exception('Failed to load matches: ${response.statusCode}');
    }
  }

  static Future<List<dynamic>> fetchGoals() async {
    final url = 'https://st9.onrender.com/api/goals?populate=*';
    final response = await http.get(
      Uri.parse(WebProxyService.proxiedUrl(url)),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] ?? [];
    } else {
      throw Exception('Failed to load goals: ${response.statusCode}');
    }
  }
}
