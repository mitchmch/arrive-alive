import 'dart:convert';

import 'package:arrive_alive/controllers/journey_controller.dart';
import 'package:arrive_alive/models/journey.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'aa_speed_limits_cache': jsonEncode({
        'car': 52,
        'motorbike': 44,
      }),
    });
  });

  test('vehicle selection displays persisted limit then refreshed admin limit',
      () async {
    final requestedModes = <String>[];
    final controller = JourneyController(
      speedLimitLoader: (mode) async {
        requestedModes.add(mode);
        return 48;
      },
    );

    final loading = controller.setMode('car');
    expect(controller.state.mode, 'car');
    expect(controller.state.isSpeedLimitLoading, isTrue);
    await loading;

    expect(controller.state.speedLimit, 48);
    expect(controller.state.isSpeedLimitLoading, isFalse);
    expect(controller.state.speedLimitSelectedAt, isNotNull);
    expect(requestedModes, ['car']);
  });

  test('bike selection uses the admin motorbike key', () async {
    final requestedModes = <String>[];
    final controller = JourneyController(
      speedLimitLoader: (mode) async {
        requestedModes.add(mode);
        return 44;
      },
    );

    await controller.setMode('bike');

    expect(requestedModes, ['motorbike']);
    expect(controller.state.speedLimit, 44);
  });

  test('journey model retains frozen limit audit fields', () {
    final journey = Journey.fromJson({
      'id': 1,
      'mode': 'bus',
      'vehicleDetails': '{}',
      'startTime': '2026-08-27T00:00:00Z',
      'frozenSpeedLimit': 56,
      'speedLimitMode': 'bus',
      'speedLimitSelectedAt': '2026-08-26T23:59:58Z',
    });

    expect(journey.frozenSpeedLimit, 56);
    expect(journey.speedLimitMode, 'bus');
    expect(journey.speedLimitSelectedAt, '2026-08-26T23:59:58Z');
  });
}
