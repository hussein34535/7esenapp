import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hesen/services/api_service.dart';

/// Thrown when the backend refuses to mint a stream ticket. [code] is the
/// backend error string (ACCOUNT_BANNED / SUBSCRIPTION_REQUIRED /
/// DEVICE_LIMIT_REACHED / ...).
class StreamTicketException implements Exception {
  final String code;
  const StreamTicketException(this.code);

  @override
  String toString() => 'StreamTicketException: $code';
}

/// Mints 24h playback tickets for 7esenlink /api/stream URLs through the
/// backend stream-ticket route. A ticket is bound to (uid, deviceId) and
/// carries a single active sessionId; the app stamps it onto stream URLs as
/// tk/sid/dv query params.
class StreamTicketService {
  /// Requests a stream ticket for the given content type ('channel'/'match').
  /// Returns the backend response map ({token, sessionId, esenkoBase, ...}).
  /// Throws [StreamTicketException] when the ticket is refused.
  static Future<Map<String, dynamic>> getTicket({
    required String type,
    required int id,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const StreamTicketException('NOT_LOGGED_IN');
    }
    final authToken = await user.getIdToken();
    if (authToken == null || authToken.isEmpty) {
      throw const StreamTicketException('NOT_LOGGED_IN');
    }

    final deviceId = await getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      throw const StreamTicketException('NO_DEVICE_ID');
    }

    try {
      return await ApiService.requestStreamTicket(
        authToken: authToken,
        deviceId: deviceId,
        type: type,
        id: id,
      );
    } catch (e) {
      // ApiService wraps the backend error code in a plain Exception.
      final code = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      throw StreamTicketException(code);
    }
  }

  /// The stable per-install device id created by data_processor.dart.
  static Future<String?> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id');
  }

  /// True for 7esenlink stream URLs that require a playback ticket.
  static bool isTicketedStreamUrl(String url) => url.contains('/api/stream/');

  /// Appends/replaces the tk/sid/dv query params on a 7esenlink stream URL.
  static String ticketUrl(
    String url, {
    required Map<String, dynamic> ticket,
    required String deviceId,
  }) {
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params['tk'] = ticket['token']?.toString() ?? '';
    params['sid'] = ticket['sessionId']?.toString() ?? '';
    params['dv'] = deviceId;
    return uri.replace(queryParameters: params).toString();
  }
}
