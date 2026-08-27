import 'package:arrive_alive/controllers/hazard_controller.dart';
import 'package:arrive_alive/models/incident.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Incident incident({
  required int id,
  required double lat,
  required double lng,
  String status = 'active',
}) {
  return Incident(
    id: id,
    type: 'pothole',
    lat: lat,
    lng: lng,
    timestamp: DateTime.utc(2026, 8, 26).toIso8601String(),
    status: status,
  );
}

void main() {
  group('hazard proximity', () {
    const origin = LatLng(3.8480, 11.5021);

    test('returns only active incidents inside the radius, nearest first', () {
      final nearby = incidentsWithinRadius(
        [
          incident(id: 1, lat: 3.8540, lng: 11.5021),
          incident(id: 2, lat: 3.8490, lng: 11.5021),
          incident(
            id: 3,
            lat: 3.8485,
            lng: 11.5021,
            status: 'resolved',
          ),
          incident(id: 4, lat: 3.8700, lng: 11.5021),
        ],
        origin,
        radiusMeters: 750,
      );

      expect(nearby.map((item) => item.id), [2, 1]);
      expect(incidentDistanceMeters(origin, nearby.first), lessThan(150));
    });
  });

  group('incident confirmation state', () {
    test('still-there confirmation keeps incident active and increments count',
        () {
      final confirmed = incident(id: 10, lat: 3.8, lng: 11.5)
          .withConfirmation(true, at: DateTime.utc(2026, 8, 26, 5));

      expect(confirmed.isActive, isTrue);
      expect(confirmed.confirmationCount, 1);
      expect(confirmed.notThereCount, 0);
      expect(confirmed.userConfirmedStillThere, isTrue);
      expect(confirmed.lastConfirmedAt, isNotNull);
    });

    test('not-there confirmation resolves the incident', () {
      final resolved = incident(id: 11, lat: 3.8, lng: 11.5)
          .withConfirmation(false, at: DateTime.utc(2026, 8, 26, 5));

      expect(resolved.isActive, isFalse);
      expect(resolved.status, 'resolved');
      expect(resolved.notThereCount, 1);
      expect(resolved.userConfirmedStillThere, isFalse);
      expect(resolved.resolvedAt, isNotNull);
    });

    test('legacy and snake-case API JSON remains supported', () {
      final parsed = Incident.fromJson({
        'id': '12',
        'type': 'roadworks',
        'latitude': '3.848',
        'longitude': 11.5021,
        'created_at': '2026-08-26T05:00:00Z',
        'confirmation_count': 4,
        'not_there_count': 1,
      });

      expect(parsed.id, 12);
      expect(parsed.lat, 3.848);
      expect(parsed.lng, 11.5021);
      expect(parsed.confirmationCount, 4);
      expect(parsed.isActive, isTrue);
    });

    test('public incident parsing discards reporter identity', () {
      final parsed = Incident.fromPublicJson({
        'id': 'opaque-hazard-id',
        'remoteId': 13,
        'type': 'pothole',
        'lat': 3.848,
        'lng': 11.5021,
        'updatedAt': '2026-08-26T05:00:00Z',
        'stillThere': 4,
        'notThere': 1,
        'vehicleReg': 'PRIVATE',
        'driverName': 'Private Person',
      });

      expect(parsed.id, 13);
      expect(parsed.confirmationCount, 4);
      expect(parsed.notThereCount, 1);
      expect(parsed.vehicleReg, isEmpty);
      expect(parsed.driverName, isEmpty);
    });
  });

  group('journey hazard alerts', () {
    test('emits one 800 m and one 500 m alert per hazard', () {
      final tracker = HazardAlertTracker();

      expect(
        tracker.observe(
          incidentId: 20,
          distanceMeters: 900,
          accuracyMeters: 5,
        ),
        isEmpty,
      );
      expect(
        tracker
            .observe(
              incidentId: 20,
              distanceMeters: 790,
              accuracyMeters: 5,
            )
            .map((alert) => alert.thresholdMeters),
        [800],
      );
      expect(
        tracker
            .observe(
              incidentId: 20,
              distanceMeters: 490,
              accuracyMeters: 5,
            )
            .map((alert) => alert.thresholdMeters),
        [500],
      );
      expect(
        tracker.observe(
          incidentId: 20,
          distanceMeters: 450,
          accuracyMeters: 5,
        ),
        isEmpty,
      );
    });

    test('rejects inaccurate readings and confirms large GPS jumps', () {
      final tracker = HazardAlertTracker();
      tracker.observe(
        incidentId: 21,
        distanceMeters: 1000,
        accuracyMeters: 5,
      );

      expect(
        tracker.observe(
          incidentId: 21,
          distanceMeters: 400,
          accuracyMeters: 120,
        ),
        isEmpty,
      );
      expect(
        tracker.observe(
          incidentId: 21,
          distanceMeters: 400,
          accuracyMeters: 5,
        ),
        isEmpty,
      );
      expect(
        tracker
            .observe(
              incidentId: 21,
              distanceMeters: 390,
              accuracyMeters: 5,
            )
            .map((alert) => alert.thresholdMeters),
        [800, 500],
      );
    });

    test('reset starts a new journey alert lifecycle', () {
      final tracker = HazardAlertTracker();
      expect(
        tracker
            .observe(
              incidentId: 22,
              distanceMeters: 490,
              accuracyMeters: 5,
            )
            .map((alert) => alert.thresholdMeters),
        [800, 500],
      );
      tracker.reset();
      expect(
        tracker
            .observe(
              incidentId: 22,
              distanceMeters: 490,
              accuracyMeters: 5,
            )
            .map((alert) => alert.thresholdMeters),
        [800, 500],
      );
    });
  });
}
