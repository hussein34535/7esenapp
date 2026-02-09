import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hesen/models/match_model.dart';
import 'package:hesen/models/highlight_model.dart';
import 'package:hesen/services/web_proxy_service.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = 'https://7esentvbackend.vercel.app/api/mobile';

  /// Fetches all highlights.
  static Future<List<Highlight>> fetchHighlights({String? authToken}) async {
    final url = '$baseUrl/highlights';
    final response = await http
        .get(
          Uri.parse(WebProxyService.proxiedUrl(url)),
          headers:
              authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final List highlightsJson = data['data'] ?? [];
        return highlightsJson.map((h) => Highlight.fromJson(h)).toList();
      }
      throw Exception('API returned success=false');
    } else {
      throw Exception('Failed to load highlights: ${response.statusCode}');
    }
  }

  /// Fetches all channels with categories and stream links.
  static Future<List<dynamic>> fetchChannels({String? authToken}) async {
    final url = '$baseUrl/channels';

    final response = await http
        .get(
          Uri.parse(WebProxyService.proxiedUrl(url)),
          headers:
              authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
        )
        .timeout(const Duration(seconds: 10));

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

  /// Fetches all categories with images.
  static Future<List<dynamic>> fetchCategories({String? authToken}) async {
    final url = '$baseUrl/categories';
    final response = await http
        .get(
          Uri.parse(WebProxyService.proxiedUrl(url)),
          headers:
              authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
        )
        .timeout(const Duration(seconds: 10));

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
  static Future<List<dynamic>> fetchNews({String? authToken}) async {
    final url = '$baseUrl/news';
    final response = await http
        .get(
          Uri.parse(WebProxyService.proxiedUrl(url)),
          headers:
              authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
        )
        .timeout(const Duration(seconds: 10));

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
  static Future<List<Match>> fetchMatches({String? authToken}) async {
    final url = '$baseUrl/matches';
    final response = await http
        .get(
          Uri.parse(WebProxyService.proxiedUrl(url)),
          headers:
              authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
        )
        .timeout(const Duration(seconds: 10));

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
  static Future<List<dynamic>> fetchGoals({String? authToken}) async {
    final url = '$baseUrl/goals';
    final response = await http
        .get(
          Uri.parse(WebProxyService.proxiedUrl(url)),
          headers:
              authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
        )
        .timeout(const Duration(seconds: 10));

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

  /// Fetches subscription packages.
  static Future<List<dynamic>> fetchPackages() async {
    final url = '$baseUrl/packages';
    final response = await http
        .get(Uri.parse(WebProxyService.proxiedUrl(url)))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Handle both list direct response (per guide) or wrapped response
      if (data is List) {
        return data;
      } else if (data is Map && data['data'] is List) {
        return data['data'];
      }
      debugPrint("fetchPackages: Unexpected response format: $data");
      return [];
    } else {
      throw Exception('Failed to load packages: ${response.statusCode}');
    }
  }

  /// Fetches payment methods.
  static Future<List<dynamic>> fetchPaymentMethods() async {
    final url = '$baseUrl/payment-methods';
    final response = await http
        .get(Uri.parse(WebProxyService.proxiedUrl(url)))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        return data;
      } else if (data is Map && data['data'] is List) {
        return data['data'];
      }
      return [];
    } else {
      throw Exception('Failed to load payment methods: ${response.statusCode}');
    }
  }

  /// Verifies a coupon code.
  static Future<Map<String, dynamic>> verifyCoupon(String code) async {
    final url = '$baseUrl/coupon';
    final response = await http
        .post(
          Uri.parse(WebProxyService.proxiedUrl(url)),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'code': code}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to verify coupon: ${response.statusCode}');
    }
  }

  /// Submits a payment request.
  static Future<Map<String, dynamic>> submitPaymentRequest(
      String uid, int packageId, String imageUrl,
      {String? paymentIdentifier}) async {
    final url = '$baseUrl/submit-payment';
    final requestBody = {
      'uid': uid,
      'packageId': packageId,
      'receiptImage': {'url': imageUrl}, // Matches requested structure
      'paymentIdentifier': paymentIdentifier ?? '',
    };

    final response = await http
        .post(
          Uri.parse(WebProxyService.proxiedUrl(url)),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Failed to submit payment request: ${response.statusCode}');
    }
  }

  static Future<void> sendTelemetry(String uid) async {
    final url = '$baseUrl/telemetry';
    try {
      await http
          .post(
            Uri.parse(WebProxyService.proxiedUrl(url)),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': uid}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Telemetry error: $e');
    }
  }

  /// Fetches current user status from the backend.
  static Future<Map<String, dynamic>?> fetchUserStatus(String uid) async {
    final url = '$baseUrl/user-status?uid=$uid';
    try {
      final response = await http
          .get(Uri.parse(WebProxyService.proxiedUrl(url)))
          .timeout(const Duration(seconds: 5));

      debugPrint("ApiService: fetchUserStatus status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle both wrapper (success/data) and direct response formats
        if (data is Map<String, dynamic>) {
          if (data.containsKey('success') && data['success'] == true) {
            debugPrint(
                "ApiService: fetchUserStatus (wrapper) response: ${data['data']}");
            return data['data'];
          } else if (data.containsKey('uid') ||
              data.containsKey('isSubscribed')) {
            // Direct response format
            debugPrint("ApiService: fetchUserStatus (direct) response: $data");
            return data;
          }
        }

        debugPrint(
            "ApiService: fetchUserStatus failed logic: ${response.body}");
      } else {
        debugPrint("ApiService: fetchUserStatus HTTP error: ${response.body}");
      }
      return null;
    } catch (e) {
      debugPrint("fetchUserStatus error: $e");
      return null;
    }
  }
}
