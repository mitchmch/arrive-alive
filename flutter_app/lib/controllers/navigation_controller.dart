import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/navigation_geometry.dart';
import '../services/navigation_service.dart';
import '../services/tts_service.dart';

typedef RouteFetcher = Future<RouteResult?> Function({
  required LatLng origin,
  required LatLng destination,
  String? destinationName,
});

/// State for traffic-aware, road-snapped turn-by-turn navigation.
class NavigationState {
  final bool isNavigating;
  final bool isSearching;
  final bool isFetchingRoute;
  final bool isRerouting;
  final String? errorMessage;
  final List<DestinationSuggestion> searchResults;
  final DestinationSuggestion? destination;
  final RouteResult? route;
  final int currentStepIndex;
  final String? nextInstruction;
  final String? nextManeuver;
  final String? nextStepDistance;
  final int remainingDistanceMeters;
  final int remainingDurationSeconds;
  final bool routeComplete;
  final LatLng? snappedPosition;
  final double routeProgressMeters;
  final double distanceFromRouteMeters;
  final double routeBearing;

  NavigationState({
    this.isNavigating = false,
    this.isSearching = false,
    this.isFetchingRoute = false,
    this.isRerouting = false,
    this.errorMessage,
    this.searchResults = const [],
    this.destination,
    this.route,
    this.currentStepIndex = 0,
    this.nextInstruction,
    this.nextManeuver,
    this.nextStepDistance,
    this.remainingDistanceMeters = 0,
    this.remainingDurationSeconds = 0,
    this.routeComplete = false,
    this.snappedPosition,
    this.routeProgressMeters = 0,
    this.distanceFromRouteMeters = 0,
    this.routeBearing = 0,
  });

  NavigationState copyWith({
    bool? isNavigating,
    bool? isSearching,
    bool? isFetchingRoute,
    bool? isRerouting,
    String? errorMessage,
    List<DestinationSuggestion>? searchResults,
    DestinationSuggestion? destination,
    RouteResult? route,
    int? currentStepIndex,
    String? nextInstruction,
    String? nextManeuver,
    String? nextStepDistance,
    int? remainingDistanceMeters,
    int? remainingDurationSeconds,
    bool? routeComplete,
    LatLng? snappedPosition,
    double? routeProgressMeters,
    double? distanceFromRouteMeters,
    double? routeBearing,
    bool clearError = false,
    bool clearDestination = false,
  }) {
    return NavigationState(
      isNavigating: isNavigating ?? this.isNavigating,
      isSearching: isSearching ?? this.isSearching,
      isFetchingRoute: isFetchingRoute ?? this.isFetchingRoute,
      isRerouting: isRerouting ?? this.isRerouting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchResults: searchResults ?? this.searchResults,
      destination: clearDestination ? null : (destination ?? this.destination),
      route: clearDestination ? null : (route ?? this.route),
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      nextInstruction: nextInstruction ?? this.nextInstruction,
      nextManeuver: nextManeuver ?? this.nextManeuver,
      nextStepDistance: nextStepDistance ?? this.nextStepDistance,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      remainingDurationSeconds:
          remainingDurationSeconds ?? this.remainingDurationSeconds,
      routeComplete: routeComplete ?? this.routeComplete,
      snappedPosition: snappedPosition ?? this.snappedPosition,
      routeProgressMeters: routeProgressMeters ?? this.routeProgressMeters,
      distanceFromRouteMeters:
          distanceFromRouteMeters ?? this.distanceFromRouteMeters,
      routeBearing: routeBearing ?? this.routeBearing,
    );
  }

  NavigationStep? get currentStep =>
      route != null && currentStepIndex < route!.steps.length
          ? route!.steps[currentStepIndex]
          : null;

  NavigationStep? get nextStep =>
      route != null && currentStepIndex + 1 < route!.steps.length
          ? route!.steps[currentStepIndex + 1]
          : null;
}

class NavigationController extends StateNotifier<NavigationState> {
  Timer? _searchDebounce;
  final RouteFetcher _fetchRoute;
  final DateTime Function() _now;
  final NavigationSafetyTracker _safety = NavigationSafetyTracker();
  bool _routeFetchInProgress = false;

  NavigationController({RouteFetcher? routeFetcher, DateTime Function()? now})
      : _fetchRoute = routeFetcher ?? NavigationService.fetchRoute,
        _now = now ?? DateTime.now,
        super(NavigationState());

  void searchDestination(String query) {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: [], isSearching: false);
      return;
    }
    state = state.copyWith(isSearching: true, clearError: true);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await NavigationService.searchDestination(query);
        state = state.copyWith(searchResults: results, isSearching: false);
      } catch (error) {
        state = state.copyWith(
          isSearching: false,
          errorMessage: 'Search failed: $error',
        );
      }
    });
  }

  Future<void> setDestinationAndRoute(
    DestinationSuggestion destination,
    LatLng origin,
  ) async {
    if (_routeFetchInProgress) return;
    _routeFetchInProgress = true;
    state = state.copyWith(
      destination: destination,
      isFetchingRoute: true,
      clearError: true,
    );

    try {
      final route = await _fetchRoute(
        origin: origin,
        destination: destination.latLng,
        destinationName: destination.name,
      );
      if (route == null || route.polylinePoints.length < 2) {
        state = state.copyWith(
          isFetchingRoute: false,
          errorMessage: 'No route found to this destination',
        );
        return;
      }
      _safety.reset();
      _applyRoute(route, speakFirstInstruction: true);
    } catch (error) {
      state = state.copyWith(
        isFetchingRoute: false,
        errorMessage: 'Failed to fetch route: $error',
      );
    } finally {
      _routeFetchInProgress = false;
    }
  }

  /// Applies a GPS fix to the route only when navigation is active.
  ///
  /// [isMoving] must come from the existing stationary-safe speed filter.
  /// Accuracy is used to suppress off-route decisions from noisy fixes.
  void updatePosition(
    LatLng position, {
    required bool isMoving,
    required double accuracyMeters,
    required Duration activeJourneyTime,
  }) {
    final route = state.route;
    if (!state.isNavigating || route == null) return;
    final projection = projectToRoute(route.polylinePoints, position);
    if (projection == null) return;

    final reliableGps =
        accuracyMeters.isFinite && accuracyMeters >= 0 && accuracyMeters <= 25;
    _safety.recordProgress(
      progressMeters: projection.progressMeters,
      moving: isMoving,
      reliableGps: reliableGps,
    );
    final progress = math
        .max(
          state.routeProgressMeters,
          _safety.maximumProgressMeters.clamp(0, projection.routeLengthMeters),
        )
        .toDouble();
    final routeLength = projection.routeLengthMeters;
    final remaining = math.max(0.0, routeLength - progress);
    final trafficDuration =
        route.trafficDurationSeconds ?? route.durationSeconds;
    final remainingDuration = routeLength <= 0
        ? 0
        : (trafficDuration * remaining / routeLength).round();

    var stepIndex = state.currentStepIndex;
    while (stepIndex < route.steps.length - 1 &&
        progress >= route.steps[stepIndex].routeEndDistanceMeters - 10) {
      stepIndex++;
    }
    final step = route.steps.isEmpty ? null : route.steps[stepIndex];
    final distanceToManeuver = step == null
        ? remaining
        : math.max(0.0, step.routeEndDistanceMeters - progress);
    final stepChanged = stepIndex != state.currentStepIndex;

    state = state.copyWith(
      currentStepIndex: stepIndex,
      nextInstruction: step?.instruction,
      nextManeuver: step?.maneuver,
      nextStepDistance: _formatDistance(distanceToManeuver),
      remainingDistanceMeters: remaining.round(),
      remainingDurationSeconds: remainingDuration,
      snappedPosition: projection.snappedPosition,
      routeProgressMeters: progress,
      distanceFromRouteMeters: projection.distanceFromRouteMeters,
      routeBearing: projection.bearing,
    );

    if (stepChanged && step != null) {
      _speakStep(step);
    }

    final destinationDistance = distanceBetween(
      position,
      state.destination!.latLng,
    );
    if (_safety.canArrive(
      activeJourneyTime: activeJourneyTime,
      routeLengthMeters: routeLength,
      distanceToDestinationMeters: destinationDistance,
    )) {
      _completeNavigation();
      return;
    }

    if (!_routeFetchInProgress &&
        _safety.shouldReroute(
          distanceFromRouteMeters: projection.distanceFromRouteMeters,
          moving: isMoving,
          reliableGps: reliableGps,
          now: _now(),
        )) {
      unawaited(_rerouteFrom(position));
    }
  }

  Future<void> _rerouteFrom(LatLng position) async {
    final destination = state.destination;
    if (destination == null || _routeFetchInProgress) return;
    _routeFetchInProgress = true;
    state = state.copyWith(isRerouting: true, clearError: true);
    try {
      final route = await _fetchRoute(
        origin: position,
        destination: destination.latLng,
        destinationName: destination.name,
      );
      if (route != null && route.polylinePoints.length >= 2) {
        _safety.reset(preserveRerouteCooldown: true);
        _applyRoute(route);
      } else {
        state = state.copyWith(
          isRerouting: false,
          errorMessage: 'Could not find a new route',
        );
      }
    } catch (error) {
      state = state.copyWith(
        isRerouting: false,
        errorMessage: 'Rerouting failed: $error',
      );
    } finally {
      _routeFetchInProgress = false;
    }
  }

  void _applyRoute(RouteResult route, {bool speakFirstInstruction = false}) {
    final firstStep = route.steps.firstOrNull;
    state = state.copyWith(
      route: route,
      isFetchingRoute: false,
      isRerouting: false,
      isNavigating: true,
      routeComplete: false,
      currentStepIndex: 0,
      nextInstruction: firstStep?.instruction,
      nextManeuver: firstStep?.maneuver,
      nextStepDistance: firstStep?.distanceText,
      remainingDistanceMeters: route.distanceMeters,
      remainingDurationSeconds:
          route.trafficDurationSeconds ?? route.durationSeconds,
      snappedPosition: route.polylinePoints.first,
      routeProgressMeters: 0,
      distanceFromRouteMeters: 0,
      routeBearing: calculateBearing(
        route.polylinePoints.first,
        route.polylinePoints[1],
      ),
    );
    if (speakFirstInstruction && firstStep != null) _speakStep(firstStep);
  }

  void _completeNavigation() {
    state = state.copyWith(
      routeComplete: true,
      isNavigating: false,
      nextInstruction: 'You have arrived at your destination',
      remainingDistanceMeters: 0,
      remainingDurationSeconds: 0,
    );
    TtsService().speak('You have arrived at your destination.');
  }

  void stopNavigation() {
    TtsService().stop();
    _safety.reset();
    state = NavigationState();
  }

  void clearSearch() {
    state = state.copyWith(searchResults: [], isSearching: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void toggleVoice() {
    final tts = TtsService();
    tts.enabled = !tts.enabled;
    if (!tts.enabled) tts.stop();
  }

  bool get voiceEnabled => TtsService().enabled;

  void _speakStep(NavigationStep step) {
    final tts = TtsService();
    if (!tts.enabled) return;
    tts.speak(
      step.voiceInstruction ?? 'In ${step.distanceText}, ${step.instruction}',
    );
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final navigationControllerProvider =
    StateNotifierProvider<NavigationController, NavigationState>((ref) {
  return NavigationController();
});
