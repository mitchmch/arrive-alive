import 'package:arrive_alive/controllers/auth_controller.dart';
import 'package:arrive_alive/core/theme.dart';
import 'package:arrive_alive/models/journey.dart';
import 'package:arrive_alive/models/user.dart';
import 'package:arrive_alive/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('personal history displays local pending journey data',
      (tester) async {
    final user = AppUser(id: 7, phone: '670000000', role: 'user');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthController(
              initialState: AuthState(user: user),
              loadStoredUser: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: HistoryScreen(
            loadJourneys: (_) async => [
              Journey(
                id: 0,
                localId: 'stable-local-id',
                userId: 7,
                mode: 'car',
                vehicleDetails: '{}',
                startTime: '2026-08-26T10:00:00Z',
                status: 'completed',
                distance: 12.5,
                maxSpeed: 64,
                score: 92,
                isSynced: false,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12.5 km'), findsOneWidget);
    expect(find.text('92'), findsWidgets);
    expect(find.byKey(const Key('history-pending-sync')), findsOneWidget);
  });
}
