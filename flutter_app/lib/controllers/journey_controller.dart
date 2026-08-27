import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import '../models/journey_evidence_summary.dart';
import '../models/speed_sample.dart';
import '../models/violation_episode.dart';
import '../services/location_service.dart';
import '../services/speed_limit_service.dart';
import '../services/sync_service.dart';

typedef SpeedLimitLoader = Future<double> Function(String mode);

bool breachReportedForNextSample({
  required bool isViolating,
  required bool wasReported,
}) =>
    isViolating && wasReported;

class JourneyState {
  final String? mode;
  final Map<String, dynamic> vehicleDetails;
  final List<String> selectedAssets;
  final List<String> selectedDefects;
  final String? driverName;
  final int passengerCount;
  final int? agencyId;
  final int? userId;
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
  final double speedLimit;
  final bool isSpeedLimitLoading;
  final DateTime? speedLimitSelectedAt;
  final int sampleCount;
  final bool isBreachReported;

  JourneyState({
    this.mode,
    this.vehicleDetails = const {},
    this.selectedAssets = const [],
    this.selectedDefects = const [],
    this.driverName,
    this.passengerCount = 1,
    this.agencyId,
    this.userId,
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
    this.speedLimit = AppConfig.defaultSpeedLimit,
    this.isSpeedLimitLoading = false,
    this.speedLimitSelectedAt,
    this.sampleCount = 0,
    this.isBreachReported = false,
  });

  JourneyState copyWith({
    String? mode,
    Map<String, dynamic>? vehicleDetails,
    List<String>? selectedAssets,
    List<String>? selectedDefects,
    String? driverName,
    int? passengerCount,
    int? agencyId,
    int? userId,
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
    double? speedLimit,
    bool? isSpeedLimitLoading,
    DateTime? speedLimitSelectedAt,
    int? sampleCount,
    bool? isBreachReported,
  }) =>
      JourneyState(
        mode: mode ?? this.mode,
        vehicleDetails: vehicleDetails ?? this.vehicleDetails,
        selectedAssets: selectedAssets ?? this.selectedAssets,
        selectedDefects: selectedDefects ?? this.selectedDefects,
        driverName: driverName ?? this.driverName,
        passengerCount: passengerCount ?? this.passengerCount,
        agencyId: agencyId ?? this.agencyId,
        userId: userId ?? this.userId,
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
        speedLimit: speedLimit ?? this.speedLimit,
        isSpeedLimitLoading: isSpeedLimitLoading ?? this.isSpeedLimitLoading,
        speedLimitSelectedAt: speedLimitSelectedAt ?? this.speedLimitSelectedAt,
        sampleCount: sampleCount ?? this.sampleCount,
        isBreachReported: isBreachReported ?? this.isBreachReported,
      );
}

class JourneyController extends StateNotifier<JourneyState> {
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  DateTime? _startTime;
  Timer? _durationTimer;
  int _movingReadings = 0;
  int _stationaryReadings = 0;
  final SyncService _syncService = SyncService();
  final _uuid = const Uuid();
  late SpeedEvidenceTracker _evidenceTracker;
  Future<JourneyEvidenceSummary>? _stopFuture;
  Future<void> _evidenceWrites = Future.value();
  final SpeedLimitLoader _loadSpeedLimit;
  int _speedLimitRequest = 0;

  JourneyController({SpeedLimitLoader? speedLimitLoader})
      : _loadSpeedLimit = speedLimitLoader ?? SpeedLimitService.getLimitForMode,
        super(JourneyState()) {
    _evidenceTracker = SpeedEvidenceTracker(
      requiredReadings: AppConfig.violationReadingsThreshold,
    );
  }

  Future<void> setMode(String mode) async {
    if (state.isRecording) return;
    final normalized = SpeedLimitService.normalizeMode(mode);
    final request = ++_speedLimitRequest;
    state = state.copyWith(
      mode: mode,
      isSpeedLimitLoading: true,
    );
    final cached = await SpeedLimitService.getCachedLimitForMode(normalized);
    if (request != _speedLimitRequest || state.isRecording) return;
    state = state.copyWith(speedLimit: cached);
    try {
      final limit = await _loadSpeedLimit(normalized);
      if (request != _speedLimitRequest || state.isRecording) return;
      state = state.copyWith(
        speedLimit: limit,
        isSpeedLimitLoading: false,
        speedLimitSelectedAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      if (request == _speedLimitRequest && !state.isRecording) {
        state = state.copyWith(
          isSpeedLimitLoading: false,
          speedLimitSelectedAt: DateTime.now().toUtc(),
        );
      }
    }
  }

  /// Refreshes the displayed pre-journey limit. Once recording starts, the
  /// chosen value is immutable and this method intentionally does nothing.
  Future<void> refreshSpeedLimit() async {
    final mode = state.mode;
    if (mode == null || state.isRecording) return;
    await setMode(mode);
  }

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
    _evidenceTracker.reset();
    _stopFuture = null;
    _evidenceWrites = Future.value();

    // Freeze the latest admin-configured limit for the whole journey so every
    // sample and episode is evaluated against the same auditable value.
    final speedLimit = await _loadSpeedLimit(
      SpeedLimitService.normalizeMode(state.mode!),
    );
    final selectedAt = DateTime.now().toUtc();

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
      'speedLimit': speedLimit,
      'speedLimitMode': SpeedLimitService.normalizeMode(state.mode!),
      'speedLimitSelectedAt': selectedAt.toIso8601String(),
    });

    state = state.copyWith(
      journeyLocalId: localId,
      userId: userId,
      isRecording: true,
      isMoving: false,
      currentSpeed: 0,
      isViolating: false,
      speedLimit: speedLimit,
      isSpeedLimitLoading: false,
      speedLimitSelectedAt: selectedAt,
      sampleCount: 0,
      violationCount: 0,
      maxSpeed: 0,
      distance: 0,
      duration: Duration.zero,
      path: const [],
      isBreachReported: false,
    );

    _startTime = DateTime.now();

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
    final limit = state.speedLimit;
    final isViolating = isMoving && speed > limit;

    final nextPath = isMoving
        ? [
            ...state.path,
            {'lat': position.latitude, 'lng': position.longitude},
          ]
        : state.path;
    final nextDistance =
        isMoving && distDelta > 0 ? state.distance + distDelta : state.distance;

    final journeyLocalId = state.journeyLocalId;
    if (journeyLocalId != null) {
      final sample = SpeedSample(
        localId: _uuid.v4(),
        journeyLocalId: journeyLocalId,
        journeyId: state.journeyId,
        recordedAt: DateTime.now(),
        speed: speed,
        speedLimit: limit,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        isMoving: isMoving,
      );
      _evidenceWrites = _evidenceWrites
          .then((_) => _syncService.createSpeedSampleLocal(sample));
      final completedEpisode = _evidenceTracker.add(sample);
      if (completedEpisode != null) {
        _recordViolationEpisode(completedEpisode);
      }
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
      isBreachReported: breachReportedForNextSample(
        isViolating: isViolating,
        wasReported: state.isBreachReported,
      ),
      violationCount: _evidenceTracker.episodeCount,
      sampleCount: state.sampleCount + 1,
    );
  }

  void _recordViolationEpisode(ViolationEpisode episode) {
    final reg = state.vehicleDetails['reg'] ?? '';
    _evidenceWrites = _evidenceWrites.then(
      (_) => _syncService.createViolationLocal(
        journeyLocalId: state.journeyLocalId ?? '',
        journeyRemoteId: state.journeyId,
        vehicleReg: reg.toString(),
        mode: state.mode ?? 'car',
        agencyId: state.agencyId,
        speed: episode.peakSpeed,
        speedLimit: episode.speedLimit,
        lat: episode.latitude,
        lng: episode.longitude,
        reportCount: episode.sampleCount,
        episode: episode,
      ),
    );
  }

  /// Persists one explicit report for the current continuous breach. Automatic
  /// episode tracking continues independently and remains deterministic.
  Future<bool> reportCurrentSpeedBreach() async {
    final position = _lastPosition;
    final journeyLocalId = state.journeyLocalId;
    if (!state.isRecording ||
        !state.isViolating ||
        state.isBreachReported ||
        position == null ||
        journeyLocalId == null) {
      return false;
    }

    state = state.copyWith(isBreachReported: true);
    try {
      await _syncService.createManualSpeedReportLocal(
        journeyLocalId: journeyLocalId,
        journeyRemoteId: state.journeyId,
        userId: state.userId,
        agencyId: state.agencyId,
        vehicleReg: (state.vehicleDetails['reg'] ?? '').toString(),
        mode: state.mode ?? 'car',
        speed: state.currentSpeed,
        speedLimit: state.speedLimit,
        lat: position.latitude,
        lng: position.longitude,
        reportedAt: DateTime.now().toUtc(),
      );
      return true;
    } catch (_) {
      if (state.isViolating) {
        state = state.copyWith(isBreachReported: false);
      }
      return false;
    }
  }

  Future<JourneyEvidenceSummary> stopRecording() {
    return _stopFuture ??= _stopRecordingOnce();
  }

  Future<JourneyEvidenceSummary> _stopRecordingOnce() async {
    final localId = state.journeyLocalId;
    if (localId == null) {
      throw StateError('No active journey to end');
    }
    _positionSub?.cancel();
    _durationTimer?.cancel();
    LocationService().stopTracking();
    _positionSub = null;
    _durationTimer = null;
    _lastPosition = null;
    _movingReadings = 0;
    _stationaryReadings = 0;

    final finalEpisode = _evidenceTracker.finish(DateTime.now());
    if (finalEpisode != null) {
      _recordViolationEpisode(finalEpisode);
    }
    await _evidenceWrites;
    final violationCount = _evidenceTracker.episodeCount;
    final score =
        violationCount == 0 ? 100 : (100 - violationCount * 15).clamp(0, 100);
    final summary = JourneyEvidenceSummary(
      journeyLocalId: localId,
      violationCount: violationCount,
      sampleCount: state.sampleCount,
      maxSpeed: state.maxSpeed,
      speedLimit: state.speedLimit,
      distanceMeters: state.distance,
      duration: state.duration,
      score: score,
      queuedForSync: true,
    );

    // Complete the journey offline-first
    await _syncService.completeJourneyLocal(
      localId,
      maxSpeed: state.maxSpeed,
      distance: state.distance,
      violationCount: violationCount,
      score: score,
      path: state.path,
    );

    state = JourneyState();
    return summary;
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
