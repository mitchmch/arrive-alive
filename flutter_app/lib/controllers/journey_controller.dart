import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/config.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';

class JourneyState {
  final String? mode;
  final Map<String, dynamic> vehicleDetails;
  final List<String> selectedAssets;
  final List<String> selectedDefects;
  final String? driverName;
  final int passengerCount;
  final int? agencyId;
  final String? journeyLocalId; // Local UUID for offline-first
  final int? journeyId; // Remote ID once synced
  final bool isRecording;
  final bool isMoving;
  final double currentSpeed;
  final double currentAccuracy;
  final double currentHeading;
  final double maxSpeed;
  final double distance;
  final int violationCount;
  final Duration duration;
  final List<Map<String, double>> path;
  final bool isViolating;

  JourneyState({
    this.mode,
    this.vehicleDetails = const {},
    this.selectedAssets = const [],
    this.selectedDefects = const [],
    this.driverName,
    this.passengerCount = 1,
    this.agencyId,
    this.journeyLocalId,
    this.journeyId,
    this.isRecording = false,
    this.isMoving = false,
    this.currentSpeed = 0,
    this.currentAccuracy = double.infinity,
    this.currentHeading = 0,
    this.maxSpeed = 0,
    this.distance = 0,
    this.violationCount = 0,
    this.duration = Duration.zero,
    this.path = const [],
    this.isViolating = false,
  });

  JourneyState copyWith({
    String? mode,
    Map<String, dynamic>? vehicleDetails,
    List<String>? selectedAssets,
    List<String>? selectedDefects,
    String? driverName,
    int? passengerCount,
    int? agencyId,
    String? journeyLocalId,
    int? journeyId,
    bool? isRecording,
    bool? isMoving,
    double? currentSpeed,
    double? currentAccuracy,
    double? currentHeading,
    double? maxSpeed,
    double? distance,
    int? violationCount,
    Duration? duration,
    List<Map<String, double>>? path,
    bool? isViolating,
  }) =>
      JourneyState(
        mode: mode ?? this.mode,
        vehicleDetails: vehicleDetails ?? this.vehicleDetails,
        selectedAssets: selectedAssets ?? this.selectedAssets,
        selectedDefects: selectedDefects ?? this.selectedDefects,
        driverName: driverName ?? this.driverName,
        passengerCount: passengerCount ?? this.passengerCount,
        agencyId: agencyId ?? this.agencyId,
        journeyLocalId: journeyLocalId ?? this.journeyLocalId,
        journeyId: journeyId ?? this.journeyId,
        isRecording: isRecording ?? this.isRecording,
        isMoving: isMoving ?? this.isMoving,
        currentSpeed: currentSpeed ?? this.currentSpeed,
        currentAccuracy: currentAccuracy ?? this.currentAccuracy,
        currentHeading: currentHeading ?? this.currentHeading,
        maxSpeed: maxSpeed ?? this.maxSpeed,
        distance: distance ?? this.distance,
        violationCount: violationCount ?? this.violationCount,
        duration: duration ?? this.duration,
        path: path ?? this.path,
        isViolating: isViolating ?? this.isViolating,
      );
}

class JourneyController extends StateNotifier<JourneyState> {
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  DateTime? _startTime;
  Timer? _durationTimer;
  int _speedReadingsAbove = 0;
  int _movingReadings = 0;
  int _stationaryReadings = 0;
  final SyncService _syncService = SyncService();

  JourneyController() : super(JourneyState());

  void setMode(String mode) => state = state.copyWith(mode: mode);

  void setVehicleDetails(Map<String, dynamic> details) =>
      state = state.copyWith(vehicleDetails: details);

  void setDriverName(String name) => state = state.copyWith(driverName: name);

  void setPassengerCount(int count) =>
      state = state.copyWith(passengerCount: count);

  void setAgencyId(int id) => state = state.copyWith(agencyId: id);

  void toggleAsset(String asset) {
    final list = List<String>.from(state.selectedAssets);
    if (list.contains(asset)) {
      list.remove(asset);
    } else {
      list.add(asset);
    }
    state = state.copyWith(selectedAssets: list);
  }

  void toggleDefect(String defect) {
    final list = List<String>.from(state.selectedDefects);
    if (list.contains(defect)) {
      list.remove(defect);
    } else {
      list.add(defect);
    }
    state = state.copyWith(selectedDefects: list);
  }

  Future<void> startRecording(int? userId) async {
    if (state.mode == null || state.isRecording) return;

    // Recording is a deliberate user action. Destination selection and screen
    // initialization must never call this method automatically.
    final hasPermission = await LocationService.requestPermissions();
    if (!hasPermission) {
      state = state.copyWith(
        isRecording: false,
        isMoving: false,
        currentSpeed: 0,
        isViolating: false,
      );
      return;
    }

    await _positionSub?.cancel();
    _durationTimer?.cancel();
    _lastPosition = null;
    _movingReadings = 0;
    _stationaryReadings = 0;

    // Create journey offline-first via SyncService
    final localId = await _syncService.createJourneyLocal({
      'userId': userId,
      'mode': state.mode!,
      'vehicleDetails': state.vehicleDetails,
      'assets': state.selectedAssets,
      'defects': state.selectedDefects,
      'driverName': state.driverName,
      'passengerCount': state.passengerCount,
      'agencyId': state.agencyId,
    });

    state = state.copyWith(
      journeyLocalId: localId,
      isRecording: true,
      isMoving: false,
      currentSpeed: 0,
      isViolating: false,
    );

    _startTime = DateTime.now();
    _speedReadingsAbove = 0;

    // Start duration timer
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime != null) {
        state = state.copyWith(
          duration: DateTime.now().difference(_startTime!),
        );
      }
    });

    // Use background tracking for persistent notification
    _positionSub = LocationService().startBackgroundTracking().listen((
      position,
    ) {
      _handlePosition(position);
    });
  }

  void _handlePosition(Position position) {
    if (!state.isRecording) return;

    double rawSpeed = 0;
    double distDelta = 0;
    if (_lastPosition != null) {
      rawSpeed = LocationService.calculateVehicleSpeed(
        _lastPosition!,
        position,
      );
      distDelta = LocationService.calculateDistance(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
    }
    _lastPosition = position;

    // Require two consecutive reliable readings before declaring motion.
    // Likewise require two stationary readings before returning to zero. This
    // rejects single GPS spikes without making the UI flicker.
    final movingCandidate = rawSpeed >= LocationService.motionThresholdKmh;
    if (movingCandidate) {
      _movingReadings++;
      _stationaryReadings = 0;
    } else {
      _stationaryReadings++;
      _movingReadings = 0;
    }

    var isMoving = state.isMoving;
    if (!isMoving && _movingReadings >= 2) isMoving = true;
    if (isMoving && _stationaryReadings >= 2) isMoving = false;

    final speed = isMoving ? rawSpeed : 0.0;
    final maxSpeed = speed > state.maxSpeed ? speed : state.maxSpeed;
    final limit = AppConfig.speedLimits[state.mode] ?? 90;
    final isViolating = isMoving && speed > limit;

    final nextPath = isMoving
        ? [
            ...state.path,
            {'lat': position.latitude, 'lng': position.longitude},
          ]
        : state.path;
    final nextDistance =
        isMoving && distDelta > 0 ? state.distance + distDelta : state.distance;

    if (isViolating) {
      _speedReadingsAbove++;
      if (_speedReadingsAbove >= AppConfig.violationReadingsThreshold) {
        _recordViolation(position, speed, limit);
        _speedReadingsAbove = 0;
      }
    } else {
      _speedReadingsAbove = 0;
    }

    state = state.copyWith(
      currentSpeed: speed,
      currentAccuracy: position.accuracy,
      currentHeading: position.headingAccuracy >= 0
          ? position.heading
          : state.currentHeading,
      isMoving: isMoving,
      maxSpeed: maxSpeed,
      distance: nextDistance,
      path: nextPath,
      isViolating: isViolating,
    );
  }

  void _recordViolation(Position pos, double speed, double limit) {
    final reg = state.vehicleDetails['reg'] ?? '';
    if (reg.isEmpty) return;

    // Create violation offline-first
    _syncService.createViolationLocal(
      journeyLocalId: state.journeyLocalId ?? '',
      journeyRemoteId: state.journeyId,
      vehicleReg: reg,
      mode: state.mode ?? 'car',
      agencyId: state.agencyId,
      speed: speed,
      speedLimit: limit,
      lat: pos.latitude,
      lng: pos.longitude,
      reportCount: _speedReadingsAbove,
    );

    state = state.copyWith(violationCount: state.violationCount + 1);
  }

  Future<void> stopRecording() async {
    _positionSub?.cancel();
    _durationTimer?.cancel();
    LocationService().stopTracking();
    _positionSub = null;
    _durationTimer = null;
    _lastPosition = null;
    _movingReadings = 0;
    _stationaryReadings = 0;

    final score = state.violationCount == 0
        ? 100
        : (100 - state.violationCount * 15).clamp(0, 100);

    // Complete the journey offline-first
    if (state.journeyLocalId != null) {
      await _syncService.completeJourneyLocal(
        state.journeyLocalId!,
        maxSpeed: state.maxSpeed,
        distance: state.distance,
        violationCount: state.violationCount,
        score: score,
        path: state.path,
      );
    }

    state = JourneyState();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }
}

final journeyProvider = StateNotifierProvider<JourneyController, JourneyState>((
  ref,
) {
  return JourneyController();
});
