import 'package:arrive_alive/controllers/admin_controller.dart';
import 'package:arrive_alive/controllers/auth_controller.dart';
import 'package:arrive_alive/core/theme.dart';
import 'package:arrive_alive/models/agency.dart';
import 'package:arrive_alive/models/incident.dart';
import 'package:arrive_alive/models/sync_record.dart';
import 'package:arrive_alive/models/user.dart';
import 'package:arrive_alive/models/violation.dart';
import 'package:arrive_alive/screens/admin_screen.dart';
import 'package:arrive_alive/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AuthController auth(AppUser user) => AuthController(
      initialState: AuthState(user: user),
      loadStoredUser: false,
    );

void main() {
  testWidgets('ordinary user is denied before admin data renders',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => auth(AppUser(id: 1, phone: '670000000', role: 'user')),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdminScreen(),
        ),
      ),
    );

    expect(find.byKey(const Key('admin-access-denied')), findsOneWidget);
    expect(find.text('Admin workspace'), findsNothing);
  });

  testWidgets('admin can navigate all narrow-layout sections with data',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => auth(AppUser(id: 2, phone: 'admin', role: 'admin')),
          ),
          statsProvider.overrideWith(
            (ref) async => {
              'totalJourneys': 12,
              'totalUsers': 4,
              'totalViolations': 3,
              'totalIncidents': 2,
            },
          ),
          adminUsersProvider.overrideWith(
            (ref) async => [
              {'displayName': 'Grace', 'role': 'user'},
            ],
          ),
          incidentsProvider.overrideWith(
            (ref) async => [
              Incident(
                id: 1,
                type: 'pothole',
                timestamp: DateTime.utc(2026).toIso8601String(),
              ),
            ],
          ),
          violationsProvider.overrideWith((ref) async => <Violation>[]),
          pendingViolationsProvider.overrideWith(
            (ref) async => <Violation>[],
          ),
          agenciesAdminProvider.overrideWith(
            (ref) async => [Agency(id: 1, name: 'Safe Transit')],
          ),
          syncHealthProvider.overrideWith(
            (ref) async => const SyncHealth(
              backendConfigured: false,
              pending: 2,
              retrying: 0,
              failed: 0,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdminScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);

    for (final section in ['users', 'reports', 'speedBoard', 'sync']) {
      final tab = find.byKey(Key('admin-tab-$section'));
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.byKey(Key('admin-$section')), findsOneWidget);
    }
    expect(find.text('Local-only mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
