import 'dart:convert';

import 'api_service.dart';
import '../models/journey.dart';
import '../core/config.dart';
import 'local_database.dart';

class JourneyService {
  static Future<Map<String, dynamic>> startJourney({
    int? userId,
    required String mode,
    required Map<String, dynamic> vehicleDetails,
    required List<String> assets,
    required List<String> defects,
    String? driverName,
    int passengerCount = 1,
    int? agencyId,
  }) async {
    return await ApiService.post('/api/journeys', {
      'userId': userId,
      'mode': mode,
      'vehicleDetails': jsonEncode(vehicleDetails),
      'assets': jsonEncode(assets),
      'defects': jsonEncode(defects),
      'driverName': driverName,
      'passengerCount': passengerCount,
      'agencyId': agencyId,
    });
  }

  static Future<void> completeJourney({
    required int journeyId,
    required double maxSpeed,
    required double distance,
    required int violationCount,
    required int score,
    String? path,
    String? violations,
  }) async {
    await ApiService.patch('/api/journeys/$journeyId', {
      'status': 'completed',
      'endTime': DateTime.now().toIso8601String(),
      'maxSpeed': maxSpeed,
      'distance': distance,
      'violationCount': violationCount,
      'score': score,
      'path': path,
      'violations': violations,
    });
  }

  static Future<List<Journey>> getUserJourneys(int userId) async {
    final localRows = await LocalDatabase().getLocalJourneys(userId);
    final byIdentity = <String, Journey>{
      for (final row in localRows)
        _identity(row): Journey.fromJson({
          ...row,
          'id': row['remoteId'] ?? 0,
        }),
    };

    if (AppConfig.hasBackend) {
      try {
        final data = await ApiService.get('/api/journeys/user/$userId');
        for (final raw in (data as List)) {
          final row = Map<String, dynamic>.from(raw as Map);
          final identity = _identity(row);
          final remote = Journey.fromJson(row);
          final local = byIdentity[identity];
          byIdentity[identity] =
              local == null ? remote : _preferNewest(local, remote);
        }
      } catch (_) {
        // Local history remains usable and truthfully marked as pending.
      }
    }
    final journeys = byIdentity.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return journeys;
  }

  static String _identity(Map<String, dynamic> row) {
    final remoteId = row['remoteId'] ?? row['id'];
    if (remoteId != null && remoteId != 0) return 'remote:$remoteId';
    return 'local:${row['localId']}';
  }

  static Journey _preferNewest(Journey local, Journey remote) {
    if (remote.version != local.version) {
      return remote.version > local.version ? remote : local;
    }
    final localTime = DateTime.tryParse(local.updatedAt ?? '');
    final remoteTime = DateTime.tryParse(remote.updatedAt ?? '');
    if (remoteTime == null) return local;
    if (localTime == null || remoteTime.isAfter(localTime)) return remote;
    return local;
  }

  static Future<void> createViolation({
    required int journeyId,
    required String vehicleReg,
    required String mode,
    int? agencyId,
    required double speed,
    required double speedLimit,
    required double lat,
    required double lng,
    int reportCount = 1,
  }) async {
    await ApiService.post('/api/violations', {
      'journeyId': journeyId,
      'vehicleReg': vehicleReg,
      'mode': mode,
      'agencyId': agencyId,
      'speed': speed,
      'speedLimit': speedLimit,
      'lat': lat,
      'lng': lng,
      'reportCount': reportCount,
    });
  }

  static Future<void> createIncident({
    required String type,
    String? description,
    double? lat,
    double? lng,
    String? vehicleReg,
    String? driverName,
  }) async {
    await ApiService.post('/api/incidents', {
      'type': type,
      'description': description,
      'lat': lat,
      'lng': lng,
      'vehicleReg': vehicleReg,
      'driverName': driverName,
    });
  }
}
