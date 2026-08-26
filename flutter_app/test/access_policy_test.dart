import 'package:arrive_alive/core/access_policy.dart';
import 'package:arrive_alive/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser user({bool isGuest = false, String role = 'user'}) {
  return AppUser(
    id: isGuest ? 0 : 42,
    phone: isGuest ? 'guest' : '670000000',
    role: role,
    isGuest: isGuest,
  );
}

void main() {
  group('AccessPolicy', () {
    test(
        'signed-out users see access and every authenticated user sees journey',
        () {
      expect(AccessPolicy.landingFor(null), AppLanding.access);
      expect(AccessPolicy.landingFor(user(isGuest: true)), AppLanding.journey);
      expect(AccessPolicy.landingFor(user()), AppLanding.journey);
      expect(
        AccessPolicy.landingFor(user(role: 'admin')),
        AppLanding.journey,
      );
    });

    test('scoreboard is registered and admin only', () {
      expect(AccessPolicy.canAccessScoreboard(null), isFalse);
      expect(
        AccessPolicy.canAccessScoreboard(user(isGuest: true)),
        isFalse,
      );
      expect(AccessPolicy.canAccessScoreboard(user()), isTrue);
      expect(
        AccessPolicy.canAccessScoreboard(user(role: 'admin')),
        isTrue,
      );
    });

    test('profile is registered and admin only', () {
      expect(AccessPolicy.canAccessProfile(null), isFalse);
      expect(AccessPolicy.canAccessProfile(user(isGuest: true)), isFalse);
      expect(AccessPolicy.canAccessProfile(user()), isTrue);
      expect(AccessPolicy.canAccessProfile(user(role: 'admin')), isTrue);
    });

    test('admin access is centrally restricted to registered admins', () {
      expect(AccessPolicy.canAccessAdmin(null), isFalse);
      expect(AccessPolicy.canAccessAdmin(user(isGuest: true)), isFalse);
      expect(AccessPolicy.canAccessAdmin(user()), isFalse);
      expect(AccessPolicy.canAccessAdmin(user(role: 'admin')), isTrue);
    });
  });
}
