import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import 'api_service.dart';

/// Manages speed limits from the admin backend with offline caching.
/// Falls back to [AppConfig.defaultSpeedLimit] when backend is unavailable.
class SpeedLimitService {
  static const String _cacheKey = 'aa_speed_limits_cache';

  static String normalizeMode(String mode) {
    final value = mode.trim().toLowerCase();
    if (value == 'bike' || value == 'motorcycle') return 'motorbike';
    return value;
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static bool _valid(double? value) =>
      value != null && value.isFinite && value > 0;

  /// Fetch speed limits from backend, cache locally for offline use.
  /// Returns a map of vehicle_type -> limit_kmh.
  static Future<Map<String, double>> fetchSpeedLimits() async {
    try {
      final data = await ApiService.get('/api/speed-limits');
      final limits = <String, double>{};
      if (data is Map) {
        for (final entry in data.entries) {
          final limit = _number(entry.value);
          if (_valid(limit)) {
            limits[normalizeMode(entry.key.toString())] = limit!;
          }
        }
      } else if (data is List) {
        for (final item in data) {
          if (item is Map) {
            final type = item['mode'] ?? item['vehicle_type'];
            final limit =
                _number(item['limitKph'] ?? item['limit_kmh'] ?? item['limit']);
            if (type != null && _valid(limit)) {
              limits[normalizeMode(type.toString())] = limit!;
            }
          }
        }
      }
      // Do not replace a useful persisted admin configuration with a malformed
      // or unexpectedly empty response.
      if (limits.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(limits));
      }
      return limits;
    } catch (_) {
      // Backend unavailable — use cached or default
      return _getCachedLimits();
    }
  }

  /// Get speed limit for a vehicle mode, falling back to default 70.
  static Future<double> getLimitForMode(String mode) async {
    final limits = await fetchSpeedLimits();
    final key = normalizeMode(mode);
    if (limits.containsKey(key)) return limits[key]!;
    return getCachedLimitForMode(mode);
  }

  /// Reads the persisted admin value without waiting for the network. This is
  /// used to populate the map as soon as a customer selects a vehicle.
  static Future<double> getCachedLimitForMode(String mode) async {
    final limits = await _getCachedLimits();
    return limits[normalizeMode(mode)] ?? AppConfig.defaultSpeedLimit;
  }

  /// Admin: update speed limit for a vehicle type via backend.
  static Future<void> updateSpeedLimit(String mode, double limit) async {
    final key = normalizeMode(mode);
    await ApiService.post('/api/admin/speed-limits', {
      'mode': key,
      'vehicle_type': key,
      'limit': limit,
      'limit_kmh': limit,
    });
    // Refresh cache
    await fetchSpeedLimits();
  }

  /// Load cached speed limits from SharedPreferences (offline fallback).
  static Future<Map<String, double>> _getCachedLimits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final limits = <String, double>{};
        for (final entry in decoded.entries) {
          final value = _number(entry.value);
          if (_valid(value)) limits[normalizeMode(entry.key)] = value!;
        }
        if (limits.isNotEmpty) return limits;
      }
    } catch (_) {}
    // Fall back to config defaults
    return {
      for (final entry in AppConfig.speedLimits.entries)
        normalizeMode(entry.key): entry.value,
    };
  }
}
