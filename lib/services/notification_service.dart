import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb) return;
    
    try {
      tz.initializeTimeZones();
      // Set UTC as local location to avoid timezone mismatch errors
      tz.setLocalLocation(tz.UTC);
      
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
      );
      debugPrint('[NOTIFICATION SERVICE] Initialized successfully.');
    } catch (e) {
      debugPrint('[NOTIFICATION SERVICE] Initialization failed: $e');
    }
  }

  static Future<bool> scheduleMatchReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (kIsWeb) return false;
    
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'match_reminders_channel',
        'تذكيرات المباريات',
        channelDescription: 'قناة لإرسال تنبيهات قبل بدء المباريات',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final now = DateTime.now();
      final difference = scheduledTime.difference(now);

      if (difference.isNegative) {
        return false;
      }

      final tzScheduledTime = tz.TZDateTime.now(tz.UTC).add(difference);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('[NOTIFICATION SERVICE] Scheduled notification $id at $tzScheduledTime (in ${difference.inSeconds} seconds)');
      return true;
    } catch (e) {
      debugPrint('[NOTIFICATION SERVICE] Error scheduling notification: $e');
      return false;
    }
  }

  static Future<void> cancelReminder(int id) async {
    if (kIsWeb) return;
    await _notificationsPlugin.cancel(id);
    debugPrint('[NOTIFICATION SERVICE] Cancelled notification $id');
  }

  static Future<void> showInstantNotification() async {
    if (kIsWeb) return;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'match_reminders_channel',
      'تذكيرات المباريات',
      channelDescription: 'قناة لإرسال تنبيهات قبل بدء المباريات',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    await _notificationsPlugin.show(
      999,
      'إشعار فوري ⚽',
      'هذا إشعار فوري للتأكد من عمل الإشعارات على جهازك!',
      notificationDetails,
    );
    debugPrint('[NOTIFICATION SERVICE] Showed instant notification.');
  }
}
