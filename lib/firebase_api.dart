import 'package:hesen/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseApi {
  final _firebseMessaging = FirebaseMessaging.instance;

  Future<String?> initNotification() async {
    if (kIsWeb) {
      try {
        await _firebseMessaging.getToken(
          vapidKey: 'YOUR_VAPID_KEY', // Get this from Firebase Console
        );
        return null; // Token handling for web is different
      } catch (e) {
        // print('Web notification error: $e');
        return null;
      }
    } else {
      await _firebseMessaging.requestPermission();
      String? token = await _firebseMessaging.getToken();
      print("FCM Token: $token");
      return token;
    }
  }

  void HandleMessage(RemoteMessage? message) {
    if (message == null) return;
    navigatorKey.currentState?.pushNamed(
      '/notification_screen',
      arguments: message,
    );
  }

  Future initPushNotification() async {
    FirebaseMessaging.instance.getInitialMessage().then(HandleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(HandleMessage);
  }
}
