import 'package:hesen/navigation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class FirebaseApi {
  final _firebseMessaging = FirebaseMessaging.instance;

  Future<String?> initNotification() async {
    try {
      if (kIsWeb) {
        return null;
      }
      await _firebseMessaging.requestPermission();
      String? token = await _firebseMessaging.getToken();
      debugPrint("FCM Token: $token");
      return token;
    } catch (e) {
      debugPrint("Notification init error: $e");
      return null;
    }
  }

  void handleMessage(RemoteMessage? message) {
    if (message == null) return;
    navigatorKey.currentState?.pushNamed(
      '/Notification_screen',
      arguments: message,
    );
  }

  Future initPushNotification() async {
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
  }
}
