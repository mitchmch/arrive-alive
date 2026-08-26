import '../models/user.dart';

enum AppLanding { access, journey }

abstract final class AccessPolicy {
  static AppLanding landingFor(AppUser? user) {
    return user == null ? AppLanding.access : AppLanding.journey;
  }

  static bool canAccessScoreboard(AppUser? user) {
    return user != null && !user.isGuest;
  }

  static bool canAccessProfile(AppUser? user) {
    return user != null && !user.isGuest;
  }

  static bool canAccessHistory(AppUser? user) => canAccessProfile(user);

  /// The single source of truth for every admin entry point and data provider.
  static bool canAccessAdmin(AppUser? user) {
    return user != null && !user.isGuest && user.role == 'admin';
  }
}
