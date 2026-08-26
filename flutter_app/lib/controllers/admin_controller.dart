import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/violation.dart';
import '../models/incident.dart';
import '../models/agency.dart';
import '../services/api_service.dart';
import '../services/admin_report_service.dart';
import '../services/speed_limit_service.dart';
import '../core/access_policy.dart';
import 'auth_controller.dart';

void _requireAdmin(Ref ref) {
  if (!AccessPolicy.canAccessAdmin(ref.read(authProvider).user)) {
    throw StateError('Admin access required');
  }
}

final statsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  _requireAdmin(ref);
  return await ApiService.get('/api/stats');
});

final violationsProvider = FutureProvider<List<Violation>>((ref) async {
  _requireAdmin(ref);
  final data = await ApiService.get('/api/violations');
  return (data as List).map((v) => Violation.fromJson(v)).toList();
});

final pendingViolationsProvider = FutureProvider<List<Violation>>((ref) async {
  _requireAdmin(ref);
  final data = await ApiService.get('/api/violations?pending=true');
  return (data as List).map((v) => Violation.fromJson(v)).toList();
});

final incidentsProvider = FutureProvider<List<Incident>>((ref) async {
  _requireAdmin(ref);
  final data = await ApiService.get('/api/incidents');
  return (data as List).map((i) => Incident.fromJson(i)).toList();
});

final agenciesAdminProvider = FutureProvider<List<Agency>>((ref) async {
  _requireAdmin(ref);
  final data = await ApiService.get('/api/agencies');
  return (data as List).map((a) => Agency.fromJson(a)).toList();
});

final adminUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  _requireAdmin(ref);
  final data = await ApiService.get('/api/users');
  return (data as List)
      .map((user) => Map<String, dynamic>.from(user as Map))
      .toList();
});

final speedLimitsAdminProvider =
    FutureProvider<Map<String, double>>((ref) async {
  _requireAdmin(ref);
  return SpeedLimitService.fetchSpeedLimits();
});

final adminReportServiceProvider = Provider<AdminReportService>(
  (ref) => const ClipboardAdminReportService(),
);

Future<void> validateViolation(int id) async {
  await ApiService.patch('/api/violations/$id/validate', {});
}

Future<void> dismissViolation(int id) async {
  await ApiService.patch('/api/violations/$id/dismiss', {});
}

Future<void> saveSpeedLimits(Map<String, int> limits) async {
  await ApiService.patch('/api/settings', {'speedLimits': limits});
}
