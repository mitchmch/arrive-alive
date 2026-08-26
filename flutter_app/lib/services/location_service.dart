import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:geolocator/geolocator.dart';

/// Location service with support for background tracking via Android foreground
/// notification and iOS background location indicator.
class LocationService {
  static const double motionThresholdKmh = 4.0;
  StreamSubscription<Position>? _subscription;
  bool _isBackgroundTracking = false;

  static Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
  }

  /// Request background location permission (Android: "Allow all the time").
  /// Must be requested separately after whileInUse is granted.
  static Future<bool> requestBackgroundPermission() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always) return true;

    // On Android, requestPermission() won't upgrade to "always" directly.
    // The user must go to settings. On iOS, requestPermission() handles it.
    if (perm == LocationPermission.whileInUse) {
      // This will prompt the user for background location on Android 11+
      final newPerm = await Geolocator.requestPermission();
      return newPerm == LocationPermission.always;
    }

    return false;
  }

  static Future<Position?> getCurrentPosition() async {
    if (!await requestPermissions()) return null;
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  /// Start foreground (active) GPS tracking with high accuracy.
  /// Use while the app is in the foreground.
  Stream<Position> startTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // Update every 1 meter
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  /// Start background GPS tracking with a persistent notification on Android.
  /// This keeps the GPS active even when the app is backgrounded.
  ///
  /// On Android, this shows a foreground service notification that cannot be dismissed.
  /// On iOS, this enables the background location indicator.
  Stream<Position> startBackgroundTracking() {
    _isBackgroundTracking = true;

    // Android-specific settings with foreground notification
    final androidSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Arrive Alive — Recording Journey',
        notificationText: 'Monitoring vehicle speed for road safety',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    // iOS-specific settings
    final appleSettings = AppleSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
      activityType: ActivityType.automotiveNavigation,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
    );

    // Use platform-appropriate settings — AndroidSettings on Android, AppleSettings on iOS
    // Both extend LocationSettings so either can be passed to getPositionStream
    if (Platform.isAndroid) {
      return Geolocator.getPositionStream(locationSettings: androidSettings);
    } else {
      return Geolocator.getPositionStream(locationSettings: appleSettings);
    }
  }

  /// Stop all tracking
  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _isBackgroundTracking = false;
  }

  bool get isBackgroundTracking => _isBackgroundTracking;

  /// Returns a motion-safe vehicle speed in km/h.
  ///
  /// A destination or route never affects this value. It comes only from
  /// reliable GPS movement, with low-speed jitter and impossible jumps
  /// rejected before the journey controller sees them.
  static double calculateVehicleSpeed(Position prev, Position curr) {
    final elapsedSeconds =
        curr.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
    if (elapsedSeconds <= 0 || elapsedSeconds > 10) return 0;

    final distanceMeters = calculateDistanceMeters(
      prev.latitude,
      prev.longitude,
      curr.latitude,
      curr.longitude,
    );

    final reportedKmh = curr.speed * 3.6;
    final hasReliableReportedSpeed = curr.speed >= 0 &&
        curr.speedAccuracy >= 0 &&
        curr.speedAccuracy <= 2.5 &&
        curr.accuracy <= 25 &&
        reportedKmh >= motionThresholdKmh &&
        reportedKmh <= 220;
    if (hasReliableReportedSpeed) return reportedKmh;

    // Fallback to displacement only when it exceeds normal stationary GPS
    // drift and both fixes are reasonably accurate.
    if (distanceMeters < 2 || prev.accuracy > 25 || curr.accuracy > 25) {
      return 0;
    }

    final calculatedKmh = (distanceMeters / elapsedSeconds) * 3.6;
    if (calculatedKmh < motionThresholdKmh || calculatedKmh > 220) return 0;
    return calculatedKmh;
  }

  /// Backwards-compatible alias used by older callers.
  static double calculateSpeed(Position prev, Position curr) {
    return calculateVehicleSpeed(prev, curr);
  }

  /// Calculate speed in km/h between two positions without motion filtering.
  static double calculateRawSpeed(Position prev, Position curr) {
    final distance = calculateDistance(
      prev.latitude,
      prev.longitude,
      curr.latitude,
      curr.longitude,
    );
    final timeDiff =
        curr.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
    if (timeDiff <= 0) return 0;
    return (distance / timeDiff) * 3600; // km/h
  }

  /// Haversine distance in km
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371; // km
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Haversine distance in meters
  static double calculateDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return calculateDistance(lat1, lng1, lat2, lng2) * 1000;
  }

  static double _toRad(double deg) => deg * pi / 180;
}
