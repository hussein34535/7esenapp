import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // طلب إذن الإشعارات
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // إعداد الإشعارات المحلية
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(initializationSettings);

    // استقبال الإشعارات عندما يكون التطبيق مفتوحاً
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // استقبال الإشعارات عندما يكون التطبيق في الخلفية
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      importance: Importance.max,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      message.notification?.title ?? '',
      message.notification?.body ?? '',
      notificationDetails,
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    _showLocalNotification(message);
  }
}

// يجب أن تكون هذه الدالة خارج الكلاس وtop-level
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  print('تم استلام إشعار في الخلفية: ${message.notification?.title}');
}
