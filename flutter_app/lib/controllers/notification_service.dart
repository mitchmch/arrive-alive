import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';
import 'auth_controller.dart';

/// Controller for FCM push notification registration
class NotificationController {
  /// Initialize Firebase and register the device token for the current user
  static Future<void> initForUser(WidgetRef ref) async {
    try {
      await NotificationService.init();
      final auth = ref.read(authProvider);
      if (auth.user != null && !auth.user!.isGuest) {
        await NotificationService.saveToken(auth.user!.id);
      }
    } catch (_) {
      // Firebase not configured — app works without push
    }
  }

  /// Unregister device token on logout
  static Future<void> unregister() async {
    try {
      await NotificationService.removeToken();
    } catch (_) {}
  }
}
