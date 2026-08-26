import 'package:arrive_alive/services/navigation_geometry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  const route = [
    LatLng(0, 0),
    LatLng(0, 0.001),
    LatLng(0.001, 0.001),
  ];

  group('route projection and progress', () {
    test('snaps to the nearest point on a segment', () {
      final projection = projectToRoute(
        route,
        const LatLng(0.0002, 0.0005),
      )!;

      expect(projection.segmentIndex, 0);
      expect(projection.snappedPosition.latitude, closeTo(0, 1e-8));
      expect(projection.snappedPosition.longitude, closeTo(0.0005, 1e-7));
      expect(projection.distanceFromRouteMeters, closeTo(22.2, 0.5));
      expect(projection.progressMeters, closeTo(55.6, 0.5));
      expect(projection.bearing, closeTo(90, 0.1));
    });

    test('progress includes all completed route segments', () {
      final projection = projectToRoute(
        route,
        const LatLng(0.0005, 0.0011),
      )!;

      expect(projection.segmentIndex, 1);
      expect(projection.progressMeters, closeTo(166.8, 1));
      expect(projection.routeLengthMeters, closeTo(222.4, 1));
      expect(projection.bearing, closeTo(0, 0.1));
    });
  });

  group('reroute safety', () {
    test('requires consecutive reliable moving off-route fixes', () {
      final tracker = NavigationSafetyTracker();
      final now = DateTime.utc(2026, 8, 26, 12);

      expect(
        tracker.shouldReroute(
          distanceFromRouteMeters: 100,
          moving: false,
          reliableGps: true,
          now: now,
        ),
        isFalse,
      );
      expect(
        tracker.shouldReroute(
          distanceFromRouteMeters: 100,
          moving: true,
          reliableGps: false,
          now: now,
        ),
        isFalse,
      );
      for (var i = 0; i < 2; i++) {
        expect(
          tracker.shouldReroute(
            distanceFromRouteMeters: 100,
            moving: true,
            reliableGps: true,
            now: now,
          ),
          isFalse,
        );
      }
      expect(
        tracker.shouldReroute(
          distanceFromRouteMeters: 100,
          moving: true,
          reliableGps: true,
          now: now,
        ),
        isTrue,
      );
    });

    test('enforces cooldown after another run of off-route fixes', () {
      final tracker = NavigationSafetyTracker();
      final now = DateTime.utc(2026, 8, 26, 12);

      for (var i = 0; i < 3; i++) {
        tracker.shouldReroute(
          distanceFromRouteMeters: 100,
          moving: true,
          reliableGps: true,
          now: now,
        );
      }
      for (var i = 0; i < 3; i++) {
        expect(
          tracker.shouldReroute(
            distanceFromRouteMeters: 100,
            moving: true,
            reliableGps: true,
            now: now.add(const Duration(seconds: 10)),
          ),
          isFalse,
        );
      }
      expect(
        tracker.shouldReroute(
          distanceFromRouteMeters: 100,
          moving: true,
          reliableGps: true,
          now: now.add(const Duration(seconds: 21)),
        ),
        isTrue,
      );
    });
  });

  group('arrival safety', () {
    test('destination selection while stationary cannot trigger arrival', () {
      final tracker = NavigationSafetyTracker();
      tracker.recordProgress(
        progressMeters: 100,
        moving: false,
        reliableGps: true,
      );

      expect(
        tracker.canArrive(
          activeJourneyTime: const Duration(minutes: 1),
          routeLengthMeters: 100,
          distanceToDestinationMeters: 0,
        ),
        isFalse,
      );
    });

    test('requires elapsed journey, route progress, movement, and proximity',
        () {
      final tracker = NavigationSafetyTracker();
      tracker.recordProgress(
        progressMeters: 90,
        moving: true,
        reliableGps: true,
      );

      expect(
        tracker.canArrive(
          activeJourneyTime: const Duration(seconds: 10),
          routeLengthMeters: 100,
          distanceToDestinationMeters: 5,
        ),
        isFalse,
      );
      expect(
        tracker.canArrive(
          activeJourneyTime: const Duration(seconds: 20),
          routeLengthMeters: 100,
          distanceToDestinationMeters: 40,
        ),
        isFalse,
      );
      expect(
        tracker.canArrive(
          activeJourneyTime: const Duration(seconds: 20),
          routeLengthMeters: 100,
          distanceToDestinationMeters: 5,
        ),
        isTrue,
      );
    });
  });
}
