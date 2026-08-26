import 'package:shared_preferences/shared_preferences.dart';

abstract final class OnboardingService {
  static const firstLaunchGuideSeenKey =
      'arrive_alive_first_launch_guide_seen_v1';

  static Future<bool> shouldShowFirstLaunchGuide() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return !(preferences.getBool(firstLaunchGuideSeenKey) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markFirstLaunchGuideSeen() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(firstLaunchGuideSeenKey, true);
    } catch (_) {
      // The guide remains available from Help even if preferences are
      // temporarily unavailable.
    }
  }
}
