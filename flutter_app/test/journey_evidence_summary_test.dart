import 'package:arrive_alive/core/theme.dart';
import 'package:arrive_alive/models/journey_evidence_summary.dart';
import 'package:arrive_alive/screens/journey_evidence_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('journey end shows evidence and registered board action',
      (tester) async {
    const summary = JourneyEvidenceSummary(
      journeyLocalId: 'journey-1',
      violationCount: 2,
      sampleCount: 42,
      maxSpeed: 82,
      speedLimit: 60,
      distanceMeters: 3600,
      duration: Duration(minutes: 9, seconds: 5),
      score: 70,
      queuedForSync: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: JourneyEvidenceSummaryScreen(
          summary: summary,
          canOpenSpeedBoard: true,
          onDone: () {},
          onOpenSpeedBoard: () {},
        ),
      ),
    );

    expect(find.text('2 violation episodes'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('82 km/h'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-speed-board')), findsOneWidget);
  });

  testWidgets('guest summary does not expose Speed Board', (tester) async {
    const summary = JourneyEvidenceSummary(
      journeyLocalId: 'journey-2',
      violationCount: 0,
      sampleCount: 5,
      maxSpeed: 40,
      speedLimit: 60,
      distanceMeters: 500,
      duration: Duration(minutes: 1),
      score: 100,
      queuedForSync: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: JourneyEvidenceSummaryScreen(
          summary: summary,
          canOpenSpeedBoard: false,
          onDone: () {},
        ),
      ),
    );
    expect(find.text('No violation episodes recorded'), findsOneWidget);
    expect(find.byKey(const Key('open-speed-board')), findsNothing);
  });
}
