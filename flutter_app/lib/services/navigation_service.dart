import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import '../core/config.dart';
import 'navigation_geometry.dart' as nav_geometry;

/// Turn-by-turn routing using Mapbox's traffic-aware driving profile.
class NavigationService {
  static const String _baseUrl =
      'https://api.mapbox.com/directions/v5/mapbox/driving-traffic';
  static final Geocoding _geocoding = Geocoding();

  /// Search for a destination by name, biased toward Cameroon.
  /// Returns a list of location suggestions with coordinates.
  static Future<List<DestinationSuggestion>> searchDestination(
    String query,
  ) async {
    final results = <DestinationSuggestion>[];

    // Try geocoding with Cameroon bias
    try {
      final locations = await _geocoding.locationFromAddress(
        '$query, Cameroon',
      );
      for (final loc in locations) {
        results.add(
          DestinationSuggestion(
            name: query,
            lat: loc.latitude,
            lng: loc.longitude,
            country: 'Cameroon',
          ),
        );
      }
    } catch (_) {}

    // Also check known Cameroon cities for quick matching
    final lowerQuery = query.toLowerCase().trim();
    for (final city in AppConfig.cameroonCities) {
      if (city.toLowerCase().contains(lowerQuery) && lowerQuery.isNotEmpty) {
        try {
          final locations = await _geocoding.locationFromAddress(
            '$city, Cameroon',
          );
          if (locations.isNotEmpty) {
            final loc = locations.first;
            results.add(
              DestinationSuggestion(
                name: city,
                lat: loc.latitude,
                lng: loc.longitude,
                country: 'Cameroon',
              ),
            );
          }
        } catch (_) {}
      }
    }

    // Deduplicate
    final seen = <String>{};
    return results.where((r) {
      final key = '${r.lat.toStringAsFixed(4)},${r.lng.toStringAsFixed(4)}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  /// Fetch a traffic-aware route with full GeoJSON step geometry.
  static Future<RouteResult?> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    String? destinationName,
  }) async {
    const accessToken = AppConfig.mapboxAccessToken;
    if (accessToken.isEmpty) {
      throw Exception(
        'Mapbox access token not configured. '
        'Set --dart-define=MAPBOX_ACCESS_TOKEN=your_token',
      );
    }

    final params = <String, String>{
      'access_token': accessToken,
      'geometries': 'geojson',
      'overview': 'full',
      'steps': 'true',
      'banner_instructions': 'true',
      'voice_instructions': 'true',
      'language': 'en',
      'voice_units': 'metric',
    };
    final coordinates = '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';
    final uri = Uri.parse(
      '$_baseUrl/$coordinates?${_buildQueryString(params)}',
    );
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Mapbox Directions error: ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok' ||
        data['routes'] == null ||
        (data['routes'] as List).isEmpty) {
      return null;
    }

    final route = (data['routes'] as List).first as Map<String, dynamic>;
    final leg = (route['legs'] as List).first as Map<String, dynamic>;
    final polylinePoints = _parseGeoJsonLine(route['geometry']);

    // Parse steps for turn-by-turn instructions
    final steps = <NavigationStep>[];
    var priorStepEnd = 0.0;
    for (final stepData in leg['steps'] as List) {
      final step = stepData as Map<String, dynamic>;
      final geometry = _parseGeoJsonLine(step['geometry']);
      final maneuver = step['maneuver'] as Map<String, dynamic>? ?? const {};
      final maneuverLocation =
          _coordinate(maneuver['location']) ?? geometry.lastOrNull;
      final start = geometry.firstOrNull ?? maneuverLocation ?? origin;
      final end = geometry.lastOrNull ?? maneuverLocation ?? destination;
      final endProjection = nav_geometry.projectToRoute(polylinePoints, end);
      final routeEnd = endProjection?.progressMeters ??
          (priorStepEnd + ((step['distance'] as num?)?.toDouble() ?? 0));
      final bannerInstruction = _firstBannerText(step['banner_instructions']);
      final voiceInstruction = _firstVoiceText(step['voice_instructions']);
      final instruction = (maneuver['instruction'] as String?) ??
          bannerInstruction ??
          'Continue';
      final distance = (step['distance'] as num?)?.toDouble() ?? 0;
      final duration = (step['duration'] as num?)?.round() ?? 0;
      steps.add(
        NavigationStep(
          instruction: instruction,
          voiceInstruction: voiceInstruction,
          distance: distance,
          distanceText: _formatDistance(distance),
          duration: duration,
          durationText: _formatDuration(duration),
          maneuver: _mapManeuver(maneuver),
          startLat: start.latitude,
          startLng: start.longitude,
          endLat: end.latitude,
          endLng: end.longitude,
          polylinePoints: geometry,
          routeStartDistanceMeters: priorStepEnd,
          routeEndDistanceMeters: routeEnd,
        ),
      );
      priorStepEnd = routeEnd;
    }

    final distance = (route['distance'] as num).round();
    final duration = (route['duration'] as num).round();
    final typicalDuration = (route['duration_typical'] as num?)?.round();
    return RouteResult(
      polylinePoints: polylinePoints,
      distanceMeters: distance,
      distanceText: _formatDistance(distance.toDouble()),
      durationSeconds: duration,
      durationText: _formatDuration(duration),
      // With driving-traffic, duration is the live-traffic duration. Mapbox's
      // optional duration_typical is the no-current-traffic comparison.
      trafficDurationSeconds: duration,
      trafficDurationText: _formatDuration(duration),
      typicalDurationSeconds: typicalDuration,
      steps: steps,
      destinationName: destinationName ?? 'Destination',
      originAddress: 'Current location',
    );
  }

  static List<LatLng> _parseGeoJsonLine(dynamic geometry) {
    final coordinates =
        (geometry as Map<String, dynamic>?)?['coordinates'] as List? ??
            const [];
    return coordinates
        .whereType<List>()
        .where((coordinate) => coordinate.length >= 2)
        .map(
          (coordinate) => LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          ),
        )
        .toList();
  }

  static LatLng? _coordinate(dynamic value) {
    if (value is! List || value.length < 2) return null;
    return LatLng((value[1] as num).toDouble(), (value[0] as num).toDouble());
  }

  static String? _firstBannerText(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    final first = value.first as Map<String, dynamic>;
    final primary = first['primary'] as Map<String, dynamic>?;
    return primary?['text'] as String?;
  }

  static String? _firstVoiceText(dynamic value) {
    if (value is! List || value.isEmpty) return null;
    return (value.first as Map<String, dynamic>)['announcement'] as String?;
  }

  static String? _mapManeuver(Map<String, dynamic> maneuver) {
    final type = maneuver['type'] as String?;
    final modifier = maneuver['modifier'] as String?;
    if (type == null) return modifier;
    if (type == 'turn' && modifier != null) return 'turn-$modifier';
    if (type == 'roundabout' || type == 'rotary') return 'roundabout';
    if (modifier != null && type != 'arrive' && type != 'depart') {
      return '$type-$modifier';
    }
    return type;
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String _formatDuration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} hr ${minutes % 60} min';
  }

  /// Build URL query string
  static String _buildQueryString(Map<String, String> params) {
    return params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  /// Calculate the bearing (heading) between two points for map rotation
  static double calculateBearing(LatLng from, LatLng to) {
    return nav_geometry.calculateBearing(from, to);
  }

  /// Get the maneuver icon name for a given maneuver type
  static String getManeuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'turn-left':
        return 'turn_slight_left';
      case 'turn-slight-left':
        return 'turn_slight_left';
      case 'turn-sharp-left':
        return 'turn_sharp_left';
      case 'turn-right':
        return 'turn_right';
      case 'turn-slight-right':
        return 'turn_slight_right';
      case 'turn-sharp-right':
        return 'turn_sharp_right';
      case 'straight':
        return 'straight';
      case 'uturn':
        return 'u_turn_right';
      case 'merge':
        return 'merge';
      case 'roundabout-left':
      case 'roundabout-right':
      case 'roundabout':
        return 'roundabout';
      case 'fork-left':
        return 'fork_left';
      case 'fork-right':
        return 'fork_right';
      case 'ramp-left':
      case 'ramp-right':
        return 'ramp_right';
      case 'keep-left':
        return 'keep_left';
      case 'keep-right':
        return 'keep_right';
      default:
        return 'straight';
    }
  }
}

/// A destination suggestion from geocoding search
class DestinationSuggestion {
  final String name;
  final double lat;
  final double lng;
  final String? country;

  const DestinationSuggestion({
    required this.name,
    required this.lat,
    required this.lng,
    this.country,
  });

  LatLng get latLng => LatLng(lat, lng);
}

/// A complete route result from the Directions API
class RouteResult {
  final List<LatLng> polylinePoints;
  final int distanceMeters;
  final String distanceText;
  final int durationSeconds;
  final String durationText;
  final int? trafficDurationSeconds;
  final String? trafficDurationText;
  final int? typicalDurationSeconds;
  final List<NavigationStep> steps;
  final String destinationName;
  final String originAddress;

  const RouteResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
    this.trafficDurationSeconds,
    this.trafficDurationText,
    this.typicalDurationSeconds,
    required this.steps,
    required this.destinationName,
    required this.originAddress,
  });

  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();
  int? get trafficDurationMinutes => trafficDurationSeconds != null
      ? (trafficDurationSeconds! / 60).round()
      : null;
}

/// A single navigation step (turn-by-turn instruction)
class NavigationStep {
  final String instruction;
  final String? voiceInstruction;
  final double distance;
  final String distanceText;
  final int duration;
  final String durationText;
  final String? maneuver;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final List<LatLng> polylinePoints;
  final double routeStartDistanceMeters;
  final double routeEndDistanceMeters;

  const NavigationStep({
    required this.instruction,
    this.voiceInstruction,
    required this.distance,
    required this.distanceText,
    required this.duration,
    required this.durationText,
    this.maneuver,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.polylinePoints,
    this.routeStartDistanceMeters = 0,
    this.routeEndDistanceMeters = 0,
  });

  LatLng get startLocation => LatLng(startLat, startLng);
  LatLng get endLocation => LatLng(endLat, endLng);
}
