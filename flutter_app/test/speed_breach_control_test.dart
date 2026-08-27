import 'package:arrive_alive/controllers/journey_controller.dart';
import 'package:arrive_alive/core/config.dart';
import 'package:arrive_alive/core/theme.dart';
import 'package:arrive_alive/services/speed_breach_alert_service.dart';
import 'package:arrive_alive/widgets/speed_breach_report_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('report control is inactive, active, then visibly reported',
      (tester) async {
    var taps = 0;

    Future<void> pump({
      required bool violating,
      required bool reported,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpeedBreachReportControl(
              isViolating: violating,
              isReported: reported,
              onReport: () => taps++,
            ),
          ),
        ),
      );
    }

    await pump(violating: false, reported: false);
    await tester.tap(find.byKey(const Key('speed-breach-report-control')));
    expect(taps, 0);
    expect(find.text('REPORT'), findsOneWidget);

    await pump(violating: true, reported: false);
    await tester.tap(find.byKey(const Key('speed-breach-report-control')));
    expect(taps, 1);

    await pump(violating: true, reported: true);
    expect(find.text('REPORTED'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.byKey(const Key('speed-breach-report-control')));
    expect(taps, 1);
  });

  test('reported state persists only for the current continuous breach', () {
    expect(
      breachReportedForNextSample(isViolating: true, wasReported: true),
      isTrue,
    );
    expect(
      breachReportedForNextSample(isViolating: false, wasReported: true),
      isFalse,
    );
  });

  testWidgets('breach alert repeats and stops immediately below limit',
      (tester) async {
    var pulses = 0;
    final alert = SpeedBreachAlertService(
      interval: const Duration(seconds: 1),
      pulse: () => pulses++,
    );

    alert.update(isRecording: true, isViolating: true);
    expect(pulses, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(pulses, 3);

    alert.update(isRecording: true, isViolating: false);
    expect(alert.isActive, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(pulses, 3);
    alert.dispose();
  });

  test('Mapbox remains the preferred map whenever it is configured', () {
    expect(
      AppConfig.useMapbox,
      AppConfig.mapboxAccessToken.isNotEmpty,
    );
    expect(AppConfig.mapboxStyleUri, startsWith('mapbox://'));
    expect(AppTheme.destructive, isNot(Colors.grey));
  });
}
