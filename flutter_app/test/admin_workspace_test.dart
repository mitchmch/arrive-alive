import 'package:arrive_alive/controllers/admin_controller.dart';
import 'package:arrive_alive/controllers/auth_controller.dart';
import 'package:arrive_alive/core/theme.dart';
import 'package:arrive_alive/models/agency.dart';
import 'package:arrive_alive/models/incident.dart';
import 'package:arrive_alive/models/sync_record.dart';
import 'package:arrive_alive/models/user.dart';
import 'package:arrive_alive/models/violation.dart';
import 'package:arrive_alive/screens/admin_screen.dart';
import 'package:arrive_alive/services/admin_report_service.dart';
import 'package:arrive_alive/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AuthController auth(AppUser user) => AuthController(
      initialState: AuthState(user: user),
      loadStoredUser: false,
    );

class FakeAdminReportService implements AdminReportService {
  int shareCalls = 0;
  int exportCalls = 0;

  @override
  Future<AdminReportActionResult> exportAgencyPdf(Agency agency) async {
    exportCalls++;
    return const AdminReportActionResult(
      AdminReportActionStatus.completed,
      'PDF ready',
    );
  }

  @override
  Future<AdminReportActionResult> shareAgencyReport(Agency agency) async {
    shareCalls++;
    return const AdminReportActionResult(
      AdminReportActionStatus.completed,
      'Report shared',
    );
  }
}

List<Override> overrides({AdminReportService? reportService}) => [
      authProvider.overrideWith(
        (ref) => auth(AppUser(id: 2, phone: 'admin', role: 'admin')),
      ),
      statsProvider.overrideWith(
        (ref) async => {
          'totalJourneys': 12,
          'totalUsers': 4,
          'totalViolations': 3,
          'totalIncidents': 2,
          'totalAgencies': 1,
          'pendingViolations': 1,
          'vehiclesByType': {
            'car': 8,
            'bus': 3,
            'lorry': 2,
            'motorbike': 6,
          },
        },
      ),
      adminUsersProvider.overrideWith(
        (ref) async => [
          {'displayName': 'Grace', 'phone': '670000000', 'role': 'user'},
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
      violationsProvider.overrideWith(
        (ref) async => [
          Violation(
            id: 7,
            journeyId: 3,
            vehicleReg: 'CE 123 AA',
            mode: 'car',
            agencyId: 1,
            speed: 86,
            speedLimit: 70,
            lat: 4,
            lng: 9,
            timestamp: DateTime.utc(2026).toIso8601String(),
          ),
        ],
      ),
      pendingViolationsProvider.overrideWith(
        (ref) async => <Violation>[],
      ),
      agenciesAdminProvider.overrideWith(
        (ref) async => [
          Agency(
            id: 1,
            name: 'Safe Transit',
            region: 'Centre',
            safetyScore: 100,
            totalJourneys: 22,
            violationCount: 1,
            vehicleBreakdown: const {
              'car': 8,
              'bus': 3,
              'lorry': 2,
              'motorbike': 6,
            },
          ),
        ],
      ),
      speedLimitsAdminProvider.overrideWith(
        (ref) async => const {
          'car': 70,
          'bus': 65,
          'lorry': 60,
          'motorbike': 70,
        },
      ),
      syncHealthProvider.overrideWith(
        (ref) async => const SyncHealth(
          backendConfigured: false,
          pending: 2,
          retrying: 0,
          failed: 0,
        ),
      ),
      if (reportService != null)
        adminReportServiceProvider.overrideWithValue(reportService),
    ];

Future<void> pumpAdmin(
  WidgetTester tester, {
  required Size size,
  AdminReportService? reportService,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides(reportService: reportService),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AdminScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openMobileSection(
  WidgetTester tester,
  String section,
) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  final destination = find.byKey(Key('admin-tab-$section'));
  await tester.ensureVisible(destination);
  await tester.tap(destination);
  await tester.pumpAndSettle();
}

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

  testWidgets('wide layout uses NavigationRail and navigates sections',
      (tester) async {
    await pumpAdmin(tester, size: const Size(1280, 800));

    expect(find.byKey(const Key('admin-navigation-rail')), findsOneWidget);
    expect(find.byKey(const Key('admin-metric-journeys')), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin-tab-users')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-users')), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets('phone drawer reaches every section without overflow',
      (tester) async {
    await pumpAdmin(tester, size: const Size(320, 640));

    expect(find.byKey(const Key('admin-navigation-rail')), findsNothing);
    for (final section in [
      'users',
      'reports',
      'agencies',
      'vehicles',
      'speedLimits',
      'syncHealth',
    ]) {
      await openMobileSection(tester, section);
      expect(find.byKey(Key('admin-$section')), findsOneWidget);
    }
    expect(find.text('Local-only mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vehicle section shows all supported vehicle types',
      (tester) async {
    await pumpAdmin(tester, size: const Size(390, 760));
    await openMobileSection(tester, 'vehicles');

    for (final type in ['car', 'bus', 'lorry', 'motorbike']) {
      expect(find.byKey(Key('vehicle-type-$type')), findsOneWidget);
    }
    expect(find.text('Cars'), findsOneWidget);
    expect(find.text('Motorbikes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('agency drill-down exposes share and PDF report actions',
      (tester) async {
    final service = FakeAdminReportService();
    await pumpAdmin(
      tester,
      size: const Size(1280, 900),
      reportService: service,
    );

    await tester.tap(find.byKey(const Key('admin-tab-agencies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agency-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agency-detail-1')), findsOneWidget);
    expect(find.text('22 journeys'), findsOneWidget);
    expect(find.text('1 violations'), findsOneWidget);
    expect(find.text('Vehicle breakdown'), findsOneWidget);

    await tester.tap(find.byKey(const Key('share-agency-report')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-agency-pdf')));
    await tester.pumpAndSettle();

    expect(service.shareCalls, 1);
    expect(service.exportCalls, 1);
    expect(find.text('PDF ready'), findsOneWidget);
  });
}
