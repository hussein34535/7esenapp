import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hesen/models/match_model.dart';

class ApiService {
  static const String baseUrl = 'https://st9.onrender.com/api';

  static Future<List> fetchChannelCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/channel-categories?populate=channels')
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List.from(data['data'] ?? []);
      }
    } catch (e) {
      print('Error fetching channels: $e');
    }
    return [];
  }

  static Future<List> fetchNews() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/news?populate=*')
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List.from(data['data'] ?? []);
      }
    } catch (e) {
      print('Error fetching news: $e');
    }
    return [];
  }

  static Future<List<Match>> fetchMatches() async {
    try {
      print('Fetching matches from $baseUrl/matches?populate=*');
      final response = await http.get(
        Uri.parse('$baseUrl/matches?populate=*')
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List matchesJson = data['data'] ?? [];
        print('Matches JSON: $matchesJson');
        
        final matches = matchesJson.map((match) {
          print('Processing match: $match');
          return Match.fromJson(match);
        }).toList();
        print('Processed ${matches.length} matches with stream links: ${matches.map((m) => '${m.teamA} vs ${m.teamB} (${m.streamLinks.length} links)').join(', ')}');
        return matches;
      }
    } catch (e, stackTrace) {
      print('Error fetching matches: $e');
      print('Stack trace: $stackTrace');
    }
    return [];
  }
}
