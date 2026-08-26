import 'package:arrive_alive/controllers/auth_controller.dart';
import 'package:arrive_alive/controllers/scoreboard_controller.dart';
import 'package:arrive_alive/core/theme.dart';
import 'package:arrive_alive/models/user.dart';
import 'package:arrive_alive/models/speed_board_entry.dart';
import 'package:arrive_alive/screens/scoreboard_screen.dart';
import 'package:arrive_alive/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Speed Board uses clear labels and over-limit values',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final user = AppUser(id: 1, phone: '670000000', role: 'user');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthController(
              initialState: AuthState(user: user),
              loadStoredUser: false,
            ),
          ),
          agencySafetyRollupsProvider.overrideWith(
            (ref) async => [
              const AgencySafetyRollup(
                id: 'rollup-1',
                agencyName: 'Safe Transit',
                status: 'trusted',
                confidence: 0.9,
                journeyCount: 20,
                violationJourneyCount: 0,
                deterministicSummary: 'Reviewed evidence is within threshold.',
              ),
            ],
          ),
          speedBoardEntriesProvider.overrideWith((ref) async => [
                const SpeedBoardEntry(
                  id: 'entry-1',
                  resultType: 'violator',
                  agencyName: 'Example Agency',
                  mode: 'bus',
                  vehicleReg: 'LT 123 AA',
                  evidence: {
                    'peakSpeedKph': 85,
                    'speedLimitKph': 60,
                    'episodeCount': 1,
                    'sampleCount': 30,
                  },
                  summary: 'Sustained speed violation detected.',
                ),
              ]),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ScoreboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Speed Board'), findsOneWidget);
    expect(find.text('Trusted agencies'), findsWidgets);
    expect(find.text('Trusted'), findsOneWidget);

    await tester.tap(find.text('Speeding vehicles'));
    await tester.pumpAndSettle();

    expect(find.text('+25 km/h over'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow admin bottom navigation does not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          bottomNavigationBar: BottomNav(
            currentIndex: 1,
            role: 'admin',
            isGuest: false,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Speed Board'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
