import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/config.dart';
import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../models/incident.dart';

double incidentDistanceMeters(LatLng origin, Incident incident) {
  if (incident.lat == null || incident.lng == null) {
    return double.infinity;
  }
  const earthRadiusMeters = 6371000.0;
  double radians(double degrees) => degrees * math.pi / 180;
  final dLat = radians(incident.lat! - origin.latitude);
  final dLng = radians(incident.lng! - origin.longitude);
  final lat1 = radians(origin.latitude);
  final lat2 = radians(incident.lat!);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

List<Incident> incidentsWithinRadius(
  Iterable<Incident> incidents,
  LatLng origin, {
  double radiusMeters = 700,
}) {
  final nearby = incidents
      .where(
        (incident) =>
            incident.isActive &&
            incident.lat != null &&
            incident.lng != null &&
            incidentDistanceMeters(origin, incident) <= radiusMeters,
      )
      .toList();
  nearby.sort(
    (a, b) => incidentDistanceMeters(
      origin,
      a,
    ).compareTo(incidentDistanceMeters(origin, b)),
  );
  return nearby;
}

/// State for the community hazard map
class HazardState {
  final List<Incident> incidents;
  final bool isLoading;
  final bool isFromCache;
  final String? errorMessage;
  final DateTime? lastUpdated;

  HazardState({
    this.incidents = const [],
    this.isLoading = false,
    this.isFromCache = false,
    this.errorMessage,
    this.lastUpdated,
  });

  HazardState copyWith({
    List<Incident>? incidents,
    bool? isLoading,
    bool? isFromCache,
    String? errorMessage,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return HazardState(
      incidents: incidents ?? this.incidents,
      isLoading: isLoading ?? this.isLoading,
      isFromCache: isFromCache ?? this.isFromCache,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Controller that fetches active community incidents for the live hazard map.
/// Loads cached incidents immediately (offline-first), then fetches fresh data
/// from the server every 30 seconds while the map is visible.
class HazardController extends StateNotifier<HazardState> {
  Timer? _refreshTimer;
  final LocalDatabase _db = LocalDatabase();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _syncService = SyncService();
  int _nextLocalId = -1;

  HazardController() : super(HazardState());

  /// Start fetching incidents periodically. Call when the hazard map becomes visible.
  void startPolling() {
    // Load cached incidents first for instant display
    _loadCachedIncidents();

    // Immediately fetch fresh data
    refresh();

    // Set up periodic refresh
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: AppConfig.hazardRefreshSeconds),
      (_) => refresh(),
    );
  }

  /// Stop periodic fetching. Call when the hazard map is no longer visible.
  void stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Load incidents from the local SQLite cache (offline-first)
  Future<void> _loadCachedIncidents() async {
    try {
      final cached = await _db.getCachedIncidents();
      if (cached.isNotEmpty && state.incidents.isEmpty) {
        final incidents = cached
            .map((data) {
              // Normalize the cached data for the Incident model
              return Incident.fromJson(Map<String, dynamic>.from(data));
            })
            .where((i) => i.isActive && i.lat != null && i.lng != null)
            .toList();

        state = state.copyWith(
          incidents: incidents,
          isFromCache: true,
          lastUpdated: DateTime.now(),
        );
      }
    } catch (_) {
      // Ignore cache errors — will try API
    }
  }

  /// Fetch fresh incidents from the server
  Future<void> refresh() async {
    final isOnline = await _connectivity.checkOnline();
    if (!isOnline) {
      // Just update cache indicator
      await _loadCachedIncidents();
      if (state.incidents.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          isFromCache: true,
          errorMessage: 'Offline — showing cached data',
        );
      }
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final data = await ApiService.get('/api/incidents');
      final incidents = (data as List)
          .map((j) => Incident.fromJson(j as Map<String, dynamic>))
          .where((i) => i.isActive && i.lat != null && i.lng != null)
          .toList();

      // Cache the incidents for offline use
      final cacheData = incidents.map((i) => i.toJson()).toList();

      await _db.cacheIncidents(cacheData);
      await _db.clearOldIncidents();

      state = state.copyWith(
        incidents: _mergeWithLocalIncidents(incidents),
        isLoading: false,
        isFromCache: false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      // Fall back to cache
      await _loadCachedIncidents();
      state = state.copyWith(
        isLoading: false,
        isFromCache: true,
        errorMessage: 'Failed to fetch live data — showing cache',
      );
    }
  }

  /// Adds a report immediately so it appears on the map before network sync.
  Incident addLocalIncident({
    required String type,
    required double lat,
    required double lng,
    String? description,
    String? vehicleReg,
    String? driverName,
  }) {
    while (state.incidents.any((incident) => incident.id == _nextLocalId)) {
      _nextLocalId--;
    }
    final incident = Incident(
      id: _nextLocalId--,
      type: type,
      description: description,
      lat: lat,
      lng: lng,
      vehicleReg: vehicleReg,
      driverName: driverName,
      timestamp: DateTime.now().toIso8601String(),
      isLocal: true,
    );
    state = state.copyWith(
      incidents: [incident, ...state.incidents],
      lastUpdated: DateTime.now(),
    );
    return incident;
  }

  /// Replaces an optimistic local report with the server response.
  void replaceLocalIncident(int localId, Incident remoteIncident) {
    state = state.copyWith(
      incidents: [
        for (final incident in state.incidents)
          if (incident.id == localId)
            remoteIncident.copyWith(isLocal: false)
          else
            incident,
      ].where((incident) => incident.isActive).toList(),
    );
  }

  Incident? incidentById(int id) {
    for (final incident in state.incidents) {
      if (incident.id == id) return incident;
    }
    return null;
  }

  List<Incident> incidentsNear(LatLng current, {double radiusMeters = 700}) {
    return incidentsWithinRadius(
      state.incidents,
      current,
      radiusMeters: radiusMeters,
    );
  }

  /// Optimistically applies confirmation state, then sends or queues the write.
  Future<void> confirmIncident(int id, bool stillThere) async {
    final incident = incidentById(id);
    if (incident == null) return;
    final updated = incident.withConfirmation(stillThere);
    state = state.copyWith(
      incidents: [
        for (final item in state.incidents)
          if (item.id == id) updated else item,
      ].where((item) => item.isActive).toList(),
      lastUpdated: DateTime.now(),
      clearError: true,
    );
    try {
      if (id >= 0) {
        if (stillThere) {
          await _db.updateCachedIncident(id, {
            'status': updated.status,
            'confirmationCount': updated.confirmationCount,
            'notThereCount': updated.notThereCount,
            'lastConfirmedAt': updated.lastConfirmedAt,
            'userConfirmedStillThere':
                updated.userConfirmedStillThere == true ? 1 : 0,
          });
        } else {
          await _db.removeCachedIncident(id);
        }
      }
    } catch (_) {
      // A cache write must never block the network/queue confirmation.
    }
    try {
      await _syncService.confirmIncidentOfflineFirst(
        id,
        stillThere: stillThere,
      );
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Confirmation saved locally and will retry later',
      );
    }
  }

  List<Incident> _mergeWithLocalIncidents(List<Incident> remote) {
    final local = state.incidents.where((incident) => incident.isLocal);
    final unmatched = local.where((candidate) {
      return !remote.any((serverIncident) {
        if (candidate.type != serverIncident.type) return false;
        final distance = incidentDistanceMeters(
          LatLng(candidate.lat!, candidate.lng!),
          serverIncident,
        );
        DateTime? localTime;
        DateTime? serverTime;
        try {
          localTime = DateTime.parse(candidate.timestamp);
          serverTime = DateTime.parse(serverIncident.timestamp);
        } catch (_) {}
        final closeInTime = localTime == null ||
            serverTime == null ||
            localTime.difference(serverTime).abs() <
                const Duration(minutes: 10);
        return distance <= 30 && closeInTime;
      });
    });
    return [...unmatched, ...remote];
  }

  /// Get the incidents as Google Maps markers
  Set<Marker> getMarkers(
    BitmapDescriptor Function(Incident) iconBuilder, {
    void Function(Incident)? onTap,
  }) {
    return state.incidents
        .where((i) => i.isActive && i.lat != null && i.lng != null)
        .map((incident) {
      return Marker(
        markerId: MarkerId('incident_${incident.id}'),
        position: LatLng(incident.lat!, incident.lng!),
        icon: iconBuilder(incident),
        infoWindow: InfoWindow(
          title: _getIncidentLabel(incident.type),
          snippet: incident.description ?? _formatTimeAgo(incident.timestamp),
        ),
        onTap: onTap == null ? null : () => onTap(incident),
      );
    }).toSet();
  }

  String _getIncidentLabel(String type) {
    const labels = {
      'accident': 'Accident',
      'hazard': 'Road Hazard',
      'pothole': 'Pothole',
      'police': 'Police Checkpoint',
      'speed_camera': 'Speed Camera',
      'roadworks': 'Roadworks',
      'conduct_phone': 'Driver on Phone',
      'conduct_drinking': 'Driver Drinking',
      'conduct_sleeping': 'Driver Sleeping',
      'conduct_distracted': 'Distracted Driver',
      'conduct_flipflops': 'Driver in Flip-flops',
      'conduct_smoking': 'Driver Smoking',
    };
    return labels[type] ?? type;
  }

  String _formatTimeAgo(String timestamp) {
    try {
      final time = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(time);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final hazardProvider = StateNotifierProvider<HazardController, HazardState>((
  ref,
) {
  return HazardController();
});
