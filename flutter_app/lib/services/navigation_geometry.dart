import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

const double _earthRadiusMeters = 6371000;

/// The closest point on a route, including distance travelled along its shape.
class RouteProjection {
  final LatLng snappedPosition;
  final double distanceFromRouteMeters;
  final double progressMeters;
  final double routeLengthMeters;
  final int segmentIndex;
  final double segmentFraction;
  final double bearing;

  const RouteProjection({
    required this.snappedPosition,
    required this.distanceFromRouteMeters,
    required this.progressMeters,
    required this.routeLengthMeters,
    required this.segmentIndex,
    required this.segmentFraction,
    required this.bearing,
  });
}

/// Stateful navigation safety gates, kept independent of widgets and plugins.
class NavigationSafetyTracker {
  static const int fixesBeforeReroute = 3;
  static const double offRouteThresholdMeters = 45;
  static const Duration rerouteCooldown = Duration(seconds: 20);
  static const Duration minimumArrivalJourneyTime = Duration(seconds: 15);
  static const double arrivalRadiusMeters = 25;

  int consecutiveOffRouteFixes = 0;
  DateTime? lastRerouteAt;
  bool movementObserved = false;
  double maximumProgressMeters = 0;

  void reset({bool preserveRerouteCooldown = false}) {
    consecutiveOffRouteFixes = 0;
    if (!preserveRerouteCooldown) lastRerouteAt = null;
    movementObserved = false;
    maximumProgressMeters = 0;
  }

  void recordProgress({
    required double progressMeters,
    required bool moving,
    required bool reliableGps,
  }) {
    maximumProgressMeters = math.max(maximumProgressMeters, progressMeters);
    if (moving && reliableGps && maximumProgressMeters >= 5) {
      movementObserved = true;
    }
  }

  bool shouldReroute({
    required double distanceFromRouteMeters,
    required bool moving,
    required bool reliableGps,
    required DateTime now,
  }) {
    if (!moving || !reliableGps) {
      consecutiveOffRouteFixes = 0;
      return false;
    }

    if (distanceFromRouteMeters > offRouteThresholdMeters) {
      consecutiveOffRouteFixes++;
    } else {
      consecutiveOffRouteFixes = 0;
      return false;
    }

    if (consecutiveOffRouteFixes < fixesBeforeReroute) return false;
    if (lastRerouteAt != null &&
        now.difference(lastRerouteAt!) < rerouteCooldown) {
      return false;
    }

    consecutiveOffRouteFixes = 0;
    lastRerouteAt = now;
    return true;
  }

  bool canArrive({
    required Duration activeJourneyTime,
    required double routeLengthMeters,
    required double distanceToDestinationMeters,
  }) {
    final requiredProgress = math.min(50.0, routeLengthMeters * 0.8);
    return movementObserved &&
        activeJourneyTime >= minimumArrivalJourneyTime &&
        maximumProgressMeters >= requiredProgress &&
        distanceToDestinationMeters <= arrivalRadiusMeters;
  }
}

double distanceBetween(LatLng a, LatLng b) {
  final dLat = _toRadians(b.latitude - a.latitude);
  final dLng = _toRadians(b.longitude - a.longitude);
  final lat1 = _toRadians(a.latitude);
  final lat2 = _toRadians(b.latitude);
  final value = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return _earthRadiusMeters *
      2 *
      math.atan2(math.sqrt(value), math.sqrt(1 - value));
}

double routeLength(List<LatLng> route) {
  var total = 0.0;
  for (var i = 0; i < route.length - 1; i++) {
    total += distanceBetween(route[i], route[i + 1]);
  }
  return total;
}

/// Projects [position] onto every segment and returns the true nearest point.
///
/// Segment math uses a local equirectangular plane, which is stable for road
/// segment distances while retaining geodesic distances for cumulative
/// progress.
RouteProjection? projectToRoute(List<LatLng> route, LatLng position) {
  if (route.length < 2) return null;

  var cumulative = 0.0;
  var bestDistance = double.infinity;
  var bestProgress = 0.0;
  var bestSegment = 0;
  var bestFraction = 0.0;
  var bestPoint = route.first;
  var bestBearing = 0.0;

  for (var i = 0; i < route.length - 1; i++) {
    final start = route[i];
    final end = route[i + 1];
    final segmentLength = distanceBetween(start, end);
    if (segmentLength == 0) continue;

    final referenceLat = _toRadians(
      (start.latitude + end.latitude + position.latitude) / 3,
    );
    final ax = _toRadians(start.longitude) *
        math.cos(referenceLat) *
        _earthRadiusMeters;
    final ay = _toRadians(start.latitude) * _earthRadiusMeters;
    final bx =
        _toRadians(end.longitude) * math.cos(referenceLat) * _earthRadiusMeters;
    final by = _toRadians(end.latitude) * _earthRadiusMeters;
    final px = _toRadians(position.longitude) *
        math.cos(referenceLat) *
        _earthRadiusMeters;
    final py = _toRadians(position.latitude) * _earthRadiusMeters;
    final dx = bx - ax;
    final dy = by - ay;
    final fraction = (((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))
        .clamp(0.0, 1.0)
        .toDouble();
    final snapped = LatLng(
      start.latitude + (end.latitude - start.latitude) * fraction,
      start.longitude + (end.longitude - start.longitude) * fraction,
    );
    final distance = distanceBetween(position, snapped);

    if (distance < bestDistance) {
      bestDistance = distance;
      bestProgress = cumulative + segmentLength * fraction;
      bestSegment = i;
      bestFraction = fraction;
      bestPoint = snapped;
      bestBearing = calculateBearing(start, end);
    }
    cumulative += segmentLength;
  }

  return RouteProjection(
    snappedPosition: bestPoint,
    distanceFromRouteMeters: bestDistance,
    progressMeters: bestProgress,
    routeLengthMeters: cumulative,
    segmentIndex: bestSegment,
    segmentFraction: bestFraction,
    bearing: bestBearing,
  );
}

double calculateBearing(LatLng from, LatLng to) {
  final lat1 = _toRadians(from.latitude);
  final lat2 = _toRadians(to.latitude);
  final dLng = _toRadians(to.longitude - from.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _toRadians(double degrees) => degrees * math.pi / 180;
