import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../services/local_database.dart';
import '../services/connectivity_service.dart';
import '../services/api_service.dart';
import '../core/config.dart';
import '../models/sync_record.dart';

/// Handles offline-first writes: queues operations locally and syncs to the server
/// when connectivity is restored. Manages localId -> remoteId mapping for journeys
/// and their dependent violations.
class SyncService {
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;
  SyncService._();

  final LocalDatabase _db = LocalDatabase();
  final ConnectivityService _connectivity = ConnectivityService();
  final _uuid = const Uuid();

  StreamSubscription<bool>? _connectivitySub;
  bool _syncing = false;
  bool _initialized = false;
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  DateTime? _lastSuccessAt;
  String? _lastError;

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  bool get isSyncing => _syncing;

  /// Initialize the sync service — call once at app startup (idempotent)
  void init() {
    if (_initialized) return;
    _initialized = true;
    if (!AppConfig.hasBackend) return;
    _connectivity.init();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        syncAll();
      }
    });
    // Attempt initial sync if already online
    _connectivity.checkOnline().then((online) {
      if (online) syncAll();
    });
  }

  /// Create a journey locally (offline-first). Returns the local ID.
  /// The journey will be synced to the server when online.
  Future<String> createJourneyLocal(Map<String, dynamic> journeyData) async {
    final localId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    final journey = {
      'localId': localId,
      'remoteId': null,
      'userId': journeyData['userId'],
      'mode': journeyData['mode'] ?? 'car',
      'vehicleDetails': jsonEncode(journeyData['vehicleDetails'] ?? {}),
      'assets': jsonEncode(journeyData['assets'] ?? []),
      'defects': jsonEncode(journeyData['defects'] ?? []),
      'driverName': journeyData['driverName'],
      'passengerCount': journeyData['passengerCount'] ?? 1,
      'agencyId': journeyData['agencyId'],
      'startTime': journeyData['startTime'] ?? now,
      'endTime': null,
      'status': 'active',
      'maxSpeed': 0.0,
      'distance': 0.0,
      'violationCount': 0,
      'score': 100,
      'path': jsonEncode([]),
      'violations': jsonEncode([]),
      'synced': 0,
      'updatedAt': now,
      'version': 1,
    };

    await _db.insertJourney(journey);

    // Queue the create operation for sync — match backend API contract
    // (vehicleDetails, assets, defects are JSON strings)
    await _db.enqueueSync({
      'operationId': 'create_journey:$localId',
      'operation': 'create_journey',
      'endpoint': '/api/journeys',
      'method': 'POST',
      'body': jsonEncode({
        'localId': localId,
        'userId': journeyData['userId'],
        'mode': journey['mode'],
        'vehicleDetails': jsonEncode(journeyData['vehicleDetails'] ?? {}),
        'assets': jsonEncode(journeyData['assets'] ?? []),
        'defects': jsonEncode(journeyData['defects'] ?? []),
        'driverName': journeyData['driverName'],
        'passengerCount': journeyData['passengerCount'] ?? 1,
        'agencyId': journeyData['agencyId'],
        'startTime': journey['startTime'],
        'updatedAt': now,
        'version': 1,
      }),
      'dependsOn': null,
    });

    _syncStatusController.add(SyncStatus.queued);
    if (AppConfig.hasBackend && await _connectivity.checkOnline()) {
      syncAll();
    }

    return localId;
  }

  /// Complete a journey locally and queue sync.
  /// If the journey hasn't been synced yet (no remoteId), queues a dependent
  /// update that will be resolved after the create_journey sync succeeds.
  Future<void> completeJourneyLocal(
    String localId, {
    required double maxSpeed,
    required double distance,
    required int violationCount,
    required int score,
    List<Map<String, double>>? path,
    List<Map<String, dynamic>>? violations,
  }) async {
    final now = DateTime.now().toIso8601String();
    final pathJson = jsonEncode(path ?? []);
    final violationsJson = jsonEncode(violations ?? []);

    await _db.updateJourney(localId, {
      'status': 'completed',
      'endTime': now,
      'maxSpeed': maxSpeed,
      'distance': distance,
      'violationCount': violationCount,
      'score': score,
      'path': pathJson,
      'violations': violationsJson,
      'updatedAt': now,
      'version':
          ((await _db.getJourneyByLocalId(localId))?['version'] as int? ?? 0) +
              1,
    });

    final journey = await _db.getJourneyByLocalId(localId);
    final remoteId = journey?['remoteId'];

    final updateBody = {
      'status': 'completed',
      'endTime': now,
      'maxSpeed': maxSpeed,
      'distance': distance,
      'violationCount': violationCount,
      'score': score,
      'path': pathJson,
      'violations': violationsJson,
      'updatedAt': now,
      'version': journey?['version'] ?? 1,
    };

    if (remoteId != null) {
      // Journey already synced — queue an update with known endpoint
      await _db.enqueueSync({
        'operationId': 'update_journey:$localId:${journey?['version']}',
        'operation': 'update_journey',
        'endpoint': '/api/journeys/$remoteId',
        'method': 'PATCH',
        'body': jsonEncode(updateBody),
        'dependsOn': null,
      });
    } else {
      // Journey not yet synced — queue a dependent update that will be
      // resolved with the correct endpoint after create_journey succeeds
      await _db.enqueueSync({
        'operationId': 'update_journey:$localId:${journey?['version']}',
        'operation': 'update_journey',
        'endpoint': '', // Will be resolved after create_journey syncs
        'method': 'PATCH',
        'body': jsonEncode(updateBody),
        'dependsOn': 'create_journey:$localId',
      });
    }

    _syncStatusController.add(SyncStatus.queued);
    if (AppConfig.hasBackend && await _connectivity.checkOnline()) {
      syncAll();
    }
  }

  /// Create a violation locally (offline-first)
  Future<String> createViolationLocal({
    required String journeyLocalId,
    int? journeyRemoteId,
    required String vehicleReg,
    required String mode,
    int? agencyId,
    required double speed,
    required double speedLimit,
    required double lat,
    required double lng,
    int reportCount = 1,
  }) async {
    final localId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await _db.insertViolation({
      'localId': localId,
      'remoteId': null,
      'journeyLocalId': journeyLocalId,
      'journeyRemoteId': journeyRemoteId,
      'vehicleReg': vehicleReg,
      'mode': mode,
      'agencyId': agencyId,
      'speed': speed,
      'speedLimit': speedLimit,
      'lat': lat,
      'lng': lng,
      'reportCount': reportCount,
      'timestamp': now,
      'synced': 0,
      'updatedAt': now,
      'version': 1,
    });

    // Queue the violation creation — depends on the journey being synced first
    await _db.enqueueSync({
      'operationId': 'create_violation:$localId',
      'operation': 'create_violation',
      'endpoint': '/api/violations',
      'method': 'POST',
      'body': jsonEncode({
        'localId': localId,
        'journeyLocalId': journeyLocalId,
        'journeyRemoteId': journeyRemoteId,
        'vehicleReg': vehicleReg,
        'mode': mode,
        'agencyId': agencyId,
        'speed': speed,
        'speedLimit': speedLimit,
        'lat': lat,
        'lng': lng,
        'reportCount': reportCount,
        'updatedAt': now,
        'version': 1,
      }),
      'dependsOn':
          journeyRemoteId == null ? 'create_journey:$journeyLocalId' : null,
    });

    _syncStatusController.add(SyncStatus.queued);
    if (AppConfig.hasBackend && await _connectivity.checkOnline()) {
      syncAll();
    }

    return localId;
  }

  /// Create an incident — try API first, fall back to local cache queue
  Future<Map<String, dynamic>?> createIncidentOfflineFirst({
    required String type,
    String? description,
    double? lat,
    double? lng,
    String? vehicleReg,
    String? driverName,
  }) async {
    final localId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final body = {
      'localId': localId,
      'type': type,
      'description': description,
      'lat': lat,
      'lng': lng,
      'vehicleReg': vehicleReg,
      'driverName': driverName,
      'updatedAt': now,
      'version': 1,
    };

    if (AppConfig.hasBackend && await _connectivity.checkOnline()) {
      try {
        final result = await ApiService.post('/api/incidents', body);
        if (result is Map<String, dynamic>) return result;
        if (result is Map) return Map<String, dynamic>.from(result);
        return null;
      } catch (_) {
        // Fall through to queue
      }
    }

    // Queue for sync
    await _db.enqueueSync({
      'operationId': 'create_incident:$localId',
      'operation': 'create_incident',
      'endpoint': '/api/incidents',
      'method': 'POST',
      'body': jsonEncode(body),
      'dependsOn': null,
    });
    _syncStatusController.add(SyncStatus.queued);
    return null;
  }

  /// Confirm whether an incident is still present. The optimistic UI is
  /// handled by HazardController; this helper guarantees the write is queued
  /// if it cannot reach the API.
  Future<void> confirmIncidentOfflineFirst(
    int incidentId, {
    required bool stillThere,
  }) async {
    // A negative ID belongs to an unsynced local report. Its state is already
    // updated locally and there is no remote incident to confirm yet.
    if (incidentId < 0) return;

    final endpoint = '/api/incidents/$incidentId/confirm';
    final body = {'stillThere': stillThere};
    if (AppConfig.hasBackend && await _connectivity.checkOnline()) {
      try {
        await ApiService.post(endpoint, body);
        return;
      } catch (_) {
        // Fall through to the durable queue.
      }
    }

    await _db.enqueueSync({
      'operationId': 'confirm_incident:$incidentId:$stillThere',
      'operation': 'confirm_incident',
      'endpoint': endpoint,
      'method': 'POST',
      'body': jsonEncode(body),
      'dependsOn': null,
    });
    _syncStatusController.add(SyncStatus.queued);
  }

  /// Process the entire sync queue
  Future<void> syncAll() async {
    if (_syncing) return;
    if (!AppConfig.hasBackend) {
      _lastError = 'API_BASE_URL is not configured';
      _syncStatusController.add(SyncStatus.unavailable);
      return;
    }
    if (!await _connectivity.checkOnline()) return;

    _syncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      final queue = await _db.getSyncQueue();

      for (final item in queue) {
        final id = item['id'] as int;
        final dependsOn = item['dependsOn'] as String?;
        final operation = item['operation'] as String;
        var endpoint = item['endpoint'] as String;
        final method = item['method'] as String;
        var bodyStr = item['body'] as String;
        final attempts = (item['attempts'] as int?) ?? 0;
        final operationId =
            item['operationId']?.toString() ?? 'legacy-queue-$id';
        final nextAttemptAt = DateTime.tryParse(
          item['nextAttemptAt']?.toString() ?? '',
        );
        if (nextAttemptAt != null && DateTime.now().isBefore(nextAttemptAt)) {
          continue;
        }

        // Resolve dependencies
        if (dependsOn != null) {
          final depType = dependsOn.split(':')[0];
          final depLocalId = dependsOn.split(':')[1];
          if (depType == 'create_journey') {
            final journey = await _db.getJourneyByLocalId(depLocalId);
            if (journey?['remoteId'] == null) {
              // Dependency not resolved yet, skip
              continue;
            }
            final remoteId = journey!['remoteId'];

            if (operation == 'create_violation') {
              // Update the body with the resolved remoteId
              final body = jsonDecode(bodyStr) as Map<String, dynamic>;
              body['journeyId'] = remoteId;
              bodyStr = jsonEncode(body);
              await _db.updateSyncQueueItem(id, {'body': bodyStr});
            } else if (operation == 'update_journey') {
              // Resolve the endpoint with the remote ID
              endpoint = '/api/journeys/$remoteId';
              await _db.updateSyncQueueItem(id, {'endpoint': endpoint});
            }
          }
        }

        try {
          final body = jsonDecode(bodyStr) as Map<String, dynamic>;
          dynamic result;

          if (method == 'POST') {
            // Remove local-only fields before sending
            final sendBody = Map<String, dynamic>.from(body);
            sendBody.remove('localId');
            sendBody.remove('journeyLocalId');
            sendBody.remove('journeyRemoteId');
            result = await ApiService.post(
              endpoint,
              sendBody,
              idempotencyKey: operationId,
            );
          } else if (method == 'PATCH') {
            result = await ApiService.patch(
              endpoint,
              body,
              idempotencyKey: operationId,
            );
          } else if (method == 'DELETE') {
            result = await ApiService.delete(endpoint);
          }

          // Handle the result — update local records with remote IDs
          if (operation == 'create_journey' && result != null) {
            final localId = body['localId'] as String;
            final remoteId = result['id'];
            await _db.updateJourney(localId, {
              'remoteId': remoteId,
              'synced': 1,
            });
          } else if (operation == 'create_violation' && result != null) {
            final localId = body['localId'] as String;
            final remoteId = result['id'];
            await _db.updateViolation(localId, {
              'remoteId': remoteId,
              'synced': 1,
            });
          }

          // Remove from queue on success
          await _db.removeSyncQueueItem(id);
          _lastSuccessAt = DateTime.now();
          _lastError = null;
        } catch (e) {
          _lastError = e.toString();
          // Retain terminal errors for operator review/manual retry.
          if (attempts >= 4) {
            await _db.markSyncFailed(id, e.toString());
          } else {
            await _db.markSyncRetry(
              id,
              error: e.toString(),
              nextAttemptAt:
                  DateTime.now().add(SyncQueuePolicy.retryDelay(attempts)),
            );
          }
          // Continue to next item
        }
      }
    } finally {
      _syncing = false;
      _syncStatusController.add(SyncStatus.idle);
    }
  }

  /// Get the number of pending sync operations
  Future<int> getPendingCount() async {
    final queue = await _db.getSyncQueue();
    return queue.length;
  }

  Future<SyncHealth> getHealth() async {
    final rows = await _db.getAllSyncQueue();
    int count(String state) =>
        rows.where((row) => (row['state'] ?? 'pending') == state).length;
    return SyncHealth(
      backendConfigured: AppConfig.hasBackend,
      pending: count('pending'),
      retrying: count('retrying'),
      failed: count('failed'),
      lastSuccessAt: _lastSuccessAt,
      lastError: _lastError,
      syncing: _syncing,
    );
  }

  Future<void> retryFailed() async {
    await _db.retryFailedSync();
    await syncAll();
  }

  void dispose() {
    _connectivitySub?.cancel();
    _syncStatusController.close();
    _connectivity.dispose();
  }
}

enum SyncStatus { idle, queued, syncing, unavailable, error }

/// Riverpod provider for SyncService
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService();
  service.init();
  return service;
});

/// Provider that tracks pending sync count
final pendingSyncCountProvider =
    StateNotifierProvider<PendingSyncNotifier, int>((ref) {
  return PendingSyncNotifier(ref);
});

class PendingSyncNotifier extends StateNotifier<int> {
  Timer? _timer;

  PendingSyncNotifier(Ref ref) : super(0) {
    _refresh();
    // Check every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  void _refresh() {
    SyncService().getPendingCount().then((count) {
      if (mounted) state = count;
    });
  }

  void forceRefresh() => _refresh();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final syncHealthProvider = FutureProvider.autoDispose<SyncHealth>((ref) async {
  return SyncService().getHealth();
});
