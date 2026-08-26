import 'package:arrive_alive/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position position({
  required double latitude,
  required double longitude,
  required DateTime timestamp,
  double speed = 0,
  double speedAccuracy = 1,
  double accuracy = 5,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: speedAccuracy,
  );
}

void main() {
  group('LocationService.calculateVehicleSpeed', () {
    final start = DateTime.utc(2026, 8, 26, 12);

    test('rejects normal stationary GPS drift', () {
      final previous = position(
        latitude: 53.4510,
        longitude: -2.0800,
        timestamp: start,
      );
      final current = position(
        latitude: 53.451004,
        longitude: -2.080004,
        timestamp: start.add(const Duration(seconds: 1)),
      );

      expect(
        LocationService.calculateVehicleSpeed(previous, current),
        equals(0),
      );
    });

    test('rejects low reported speed while stationary', () {
      final previous = position(
        latitude: 53.4510,
        longitude: -2.0800,
        timestamp: start,
      );
      final current = position(
        latitude: 53.4510,
        longitude: -2.0800,
        timestamp: start.add(const Duration(seconds: 1)),
        speed: 0.8,
      );

      expect(
        LocationService.calculateVehicleSpeed(previous, current),
        equals(0),
      );
    });

    test('accepts reliable vehicle movement', () {
      final previous = position(
        latitude: 53.4510,
        longitude: -2.0800,
        timestamp: start,
      );
      final current = position(
        latitude: 53.45109,
        longitude: -2.0800,
        timestamp: start.add(const Duration(seconds: 1)),
        speed: 10,
      );

      expect(
        LocationService.calculateVehicleSpeed(previous, current),
        closeTo(36, 0.01),
      );
    });

    test('rejects impossible GPS speed jumps', () {
      final previous = position(
        latitude: 53.4510,
        longitude: -2.0800,
        timestamp: start,
      );
      final current = position(
        latitude: 53.4520,
        longitude: -2.0800,
        timestamp: start.add(const Duration(seconds: 1)),
        speed: 90,
      );

      expect(
        LocationService.calculateVehicleSpeed(previous, current),
        equals(0),
      );
    });
  });
}
