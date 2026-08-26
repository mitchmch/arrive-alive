// Basic smoke test for Arrive Alive app.
//
// To run: flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arrive_alive/main.dart';

void main() {
  testWidgets('App initializes without error', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(child: ArriveAliveApp()),
    );
    await tester.pump(const Duration(seconds: 3));

    // Verify the app renders without throwing.
    expect(find.byType(ArriveAliveApp), findsOneWidget);
  });
}
