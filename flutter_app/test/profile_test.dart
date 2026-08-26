import 'dart:convert';

import 'package:arrive_alive/controllers/auth_controller.dart';
import 'package:arrive_alive/core/theme.dart';
import 'package:arrive_alive/models/user.dart';
import 'package:arrive_alive/screens/profile_screen.dart';
import 'package:arrive_alive/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppUser reads older persisted data without a display name', () {
    final user = AppUser.fromJson({
      'id': 12,
      'phone': '670000000',
      'role': 'user',
    });

    expect(user.displayName, isEmpty);
    expect(user.photoPath, isNull);
    expect(user.toJson()['displayName'], isEmpty);
  });

  test('profile update persists session/local data and updates auth state',
      () async {
    final original = AppUser(
      id: 42,
      phone: '670000000',
      role: 'user',
    );
    SharedPreferences.setMockInitialValues({
      'arrive_alive_users': jsonEncode({
        original.phone: {
          'id': original.id,
          'phone': original.phone,
          'role': original.role,
          'pin': '1234',
        },
      }),
    });
    final controller = AuthController(
      initialState: AuthState(user: original),
      loadStoredUser: false,
    );

    expect(
      await controller.updateProfile(
        displayName: '  Grace N.  ',
        phone: '671 234 567',
        photoPath: '/app/profile_photos/user_42.jpg',
      ),
      isTrue,
    );
    expect(controller.state.user?.displayName, 'Grace N.');
    expect(controller.state.user?.phone, '671 234 567');
    expect(
      controller.state.user?.photoPath,
      '/app/profile_photos/user_42.jpg',
    );

    final storedSession = await AuthService.getCurrentUser();
    expect(storedSession?.displayName, 'Grace N.');
    expect(storedSession?.phone, '671 234 567');

    final prefs = await SharedPreferences.getInstance();
    final storedUsers = jsonDecode(prefs.getString('arrive_alive_users')!)
        as Map<String, dynamic>;
    expect(storedUsers.containsKey('671 234 567'), isTrue);
    expect(storedUsers['671 234 567']['displayName'], 'Grace N.');
  });

  testWidgets('guest cannot access profile editing', (tester) async {
    final guest = AppUser(
      id: 0,
      phone: 'guest',
      role: 'guest',
      isGuest: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthController(
              initialState: AuthState(user: guest),
              loadStoredUser: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfileScreen(),
        ),
      ),
    );

    expect(
      find.byKey(const Key('profile-sign-in-required')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('profile-save')), findsNothing);
  });

  testWidgets('registered user edits profile and sees propagated state',
      (tester) async {
    final user = AppUser(
      id: 7,
      phone: '670000000',
      role: 'user',
      displayName: 'Old Name',
    );
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(
          (ref) => AuthController(
            initialState: AuthState(user: user),
            loadStoredUser: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfileScreen(),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('profile-display-name')),
      'New Name',
    );
    await tester.enterText(
      find.byKey(const Key('profile-phone')),
      '671234567',
    );
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();

    expect(container.read(authProvider).user?.displayName, 'New Name');
    expect(container.read(authProvider).user?.phone, '671234567');
    expect(find.text('Profile saved'), findsOneWidget);
    expect(find.byKey(const Key('profile-history')), findsOneWidget);
    expect(find.byKey(const Key('profile-photo-select')), findsOneWidget);
    expect(find.byKey(const Key('profile-admin')), findsNothing);
  });

  testWidgets('admin profile exposes protected workspace entry',
      (tester) async {
    final admin = AppUser(id: 0, phone: 'admin', role: 'admin');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthController(
              initialState: AuthState(user: admin),
              loadStoredUser: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('profile-admin')));
    expect(find.byKey(const Key('profile-admin')), findsOneWidget);
  });
}
