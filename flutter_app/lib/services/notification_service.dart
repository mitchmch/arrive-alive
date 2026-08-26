import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    await Firebase.initializeApp();

    // Request permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Init local notifications for foreground
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        showLocalNotification(
          notification.title ?? 'Arrive Alive',
          notification.body ?? '',
        );
      }
    });

    // Background message handler (must be top-level function)
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }

  static Future<String?> getToken() async {
    return FirebaseMessaging.instance.getToken();
  }

  static Future<void> saveToken(int userId) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await ApiService.post('/api/devices/register', {
        'userId': userId,
        'token': token,
        'platform': _platform(),
      });
    } catch (_) {}
  }

  static Future<void> removeToken() async {
    final token = await getToken();
    if (token == null) return;
    try {
      await ApiService.delete('/api/devices/$token');
    } catch (_) {}
  }

  static Future<void> showLocalNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'arrive_alive_alerts',
      'Arrive Alive Alerts',
      channelDescription: 'Safety alerts and violation notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  static String _platform() {
    // Will be 'android' or 'ios' at runtime
    return const bool.fromEnvironment('dart.platform.android')
        ? 'android'
        : 'ios';
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are handled by the system notification tray
}
