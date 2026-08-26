import 'package:arrive_alive/controllers/auth_controller.dart';
import 'package:arrive_alive/core/theme.dart';
import 'package:arrive_alive/models/user.dart';
import 'package:arrive_alive/screens/scoreboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guest sees sign-in-required state instead of scoreboard data',
      (tester) async {
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
          home: const ScoreboardScreen(),
        ),
      ),
    );

    expect(
      find.byKey(const Key('scoreboard-sign-in-required')),
      findsOneWidget,
    );
    expect(find.text('Registered access required'), findsOneWidget);
    expect(find.text('Trusted agencies'), findsNothing);
  });
}
