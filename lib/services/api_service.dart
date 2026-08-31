import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Conditional import: on web, use dart:html's HttpRequest (text-based, no ArrayBuffer crash)
// On native, use the stub (package:http is used directly)
import 'web_http_client_stub.dart'
    if (dart.library.js_interop) 'web_http_client_wasm.dart'
    if (dart.library.html) 'web_http_client_web.dart';

class ApiService {
  // On web: use relative URL (same-origin, Nginx proxies to Vercel â†’ NO CORS)
  // On mobile: use full Vercel URL directly
  static final String baseUrl =
      kIsWeb && !(Uri.base.toString().contains('localhost') || Uri.base.toString().contains('127.0.0.1'))
          ? '/api/mobile'
          : 'https://7esentvbackend.vercel.app/api/mobile';

  /// Web-safe GET request. Uses dart:html on web, package:http on native.
  static Future<http.Response> _safeGet(String url,
      {Map<String, String>? headers}) async {
    if (kIsWeb) {
      final result = await webGet(url, headers: headers);
      return http.Response.bytes(
        result['bodyBytes'] as Uint8List,
        result['statusCode'] as int,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final mergedHeaders = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ...?headers,
    };
    return http.get(Uri.parse(url), headers: mergedHeaders);
  }

  /// Web-safe POST request. Uses dart:html on web, package:http on native.
  static Future<http.Response> _safePost(String url,
      {Map<String, String>? headers, String? body}) async {
    if (kIsWeb) {
      final result = await webPost(url, headers: headers, body: body);
      return http.Response.bytes(
        result['bodyBytes'] as Uint8List,
        result['statusCode'] as int,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final mergedHeaders = <String, String>{
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      ...?headers,
    };
    return http.post(Uri.parse(url), headers: mergedHeaders, body: body);
  }

  /// Fetches all highlights.
  static Future<List<dynamic>> fetchHighlights({String? authToken}) async {
    final url = '$baseUrl/highlights';
    try {
      final response = await _safeGet(
        url,
        headers:
            authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
        throw Exception('API returned success=false');
      } else {
        throw Exception('Failed to load highlights: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches all channels with categories and stream links.
  static Future<List<dynamic>> fetchChannels({String? authToken}) async {
    final url = '$baseUrl/channels';

    final response = await _safeGet(
      url,
      headers:
          authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
    ).timeout(const Duration(seconds: 30));

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
    final response = await _safeGet(
      url,
      headers:
          authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
    ).timeout(const Duration(seconds: 30));

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
    final response = await _safeGet(
      url,
      headers:
          authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
    ).timeout(const Duration(seconds: 30));

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
  static Future<List<dynamic>> fetchMatches({String? authToken}) async {
    final url = '$baseUrl/matches';
    try {
      final response = await _safeGet(
        url,
        headers:
            authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? [];
        }
        throw Exception('API returned success=false');
      } else {
        throw Exception('Failed to load matches: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches all goals.
  static Future<List<dynamic>> fetchGoals({String? authToken}) async {
    final url = '$baseUrl/goals';
    final response = await _safeGet(
      url,
      headers:
          authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
    ).timeout(const Duration(seconds: 30));

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
    final response = await _safeGet(url).timeout(const Duration(seconds: 30));

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
    final response = await _safeGet(url).timeout(const Duration(seconds: 30));

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
    final response = await _safePost(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code}),
    ).timeout(const Duration(seconds: 30));

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

    final response = await _safePost(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Failed to submit payment request: ${response.statusCode}');
    }
  }

  /// Creates a Paymob payment session and returns the checkout URL.
  static Future<Map<String, dynamic>> createPaymobSession(
      String uid, int packageId, {String? couponCode}) async {
    final url = '$baseUrl/paymob/create-session';
    final requestBody = {
      'uid': uid,
      'packageId': packageId,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
    };

    final response = await _safePost(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      try {
        final Map<String, dynamic> errorData = json.decode(response.body);
        throw Exception(
            errorData['error'] ?? 'Failed to create payment session: ${response.statusCode}');
      } catch (_) {
        throw Exception('Failed to create payment session: ${response.statusCode}');
      }
    }
  }

  static Future<Map<String, dynamic>> createFawaterakSession(
      String uid, int packageId, String paymentMethod, {String? couponCode, String? phone}) async {
    final url = '$baseUrl/fawaterak/create-session';
    final requestBody = {
      'uid': uid,
      'packageId': packageId,
      'paymentMethod': paymentMethod,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };

    final response = await _safePost(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      String errorMessage = 'Failed to create Fawaterak session: ${response.statusCode}';
      try {
        final Map<String, dynamic> errorData = json.decode(response.body);
        if (errorData['error'] != null) {
          errorMessage = errorData['error'];
        }
      } catch (_) {
        // Ignore json parse errors and use default message
      }
      throw Exception(errorMessage);
    }
  }


  static Future<void> sendTelemetry(String uid) async {
    final url = '$baseUrl/telemetry';
    try {
      await _safePost(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid}),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Telemetry error: $e');
    }
  }

  static Future<void> registerUser(String uid, String email) async {
    final url = '$baseUrl/register';
    try {
      // Backend (security patch) requires a Firebase ID token + deviceId.
      String? authToken;
      try {
        final u = FirebaseAuth.instance.currentUser;
        if (u != null) authToken = await u.getIdToken();
      } catch (_) {}
      String? deviceId;
      try {
        final prefs = await SharedPreferences.getInstance();
        deviceId = prefs.getString('device_id');
      } catch (_) {}
      await _safePost(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'uid': uid, 'email': email, if (deviceId != null) 'deviceId': deviceId}),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Register User API Error: $e');
    }
  }

  /// Requests a 24h stream ticket for ticketed playback (7esenlink
  /// /api/stream URLs). Returns the backend response map
  /// ({token, sessionId, esenkoBase, ...}).
  /// Throws [Exception] carrying the backend error code on 403 responses
  /// (ACCOUNT_BANNED / SUBSCRIPTION_REQUIRED / DEVICE_LIMIT_REACHED).
  static Future<Map<String, dynamic>> requestStreamTicket({
    required String authToken,
    required String deviceId,
    required String type,
    required int id,
  }) async {
    final url = '$baseUrl/stream-ticket';
    final response = await _safePost(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'deviceId': deviceId, 'type': type, 'id': id}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map && data['success'] == true) {
        return Map<String, dynamic>.from(data);
      }
      throw Exception('Failed to request stream ticket: success=false');
    }

    String errorCode =
        'Failed to request stream ticket: ${response.statusCode}';
    try {
      final data = json.decode(response.body);
      if (data is Map && data['error'] != null) {
        errorCode = data['error'].toString();
      }
    } catch (_) {
      // Ignore json parse errors and use the default message
    }
    throw Exception(errorCode);
  }

  /// Fetches current user status from the backend.
  static Future<Map<String, dynamic>?> fetchUserStatus(String uid) async {
    final url = '$baseUrl/user-status?uid=$uid';
    try {
      final response = await _safeGet(url).timeout(const Duration(seconds: 5));

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
