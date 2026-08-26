import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/violation.dart';
import '../models/agency.dart';
import '../models/speed_board_entry.dart';
import '../services/api_service.dart';

final publishedViolationsProvider = FutureProvider<List<Violation>>((
  ref,
) async {
  final data = await ApiService.get('/api/violations?published=true');
  return (data as List).map((v) => Violation.fromJson(v)).toList();
});

final agenciesProvider = FutureProvider<List<Agency>>((ref) async {
  final data = await ApiService.get('/api/agencies');
  return (data as List).map((a) => Agency.fromJson(a)).toList();
});

final speedBoardEntriesProvider =
    FutureProvider<List<SpeedBoardEntry>>((ref) async {
  final data = await ApiService.get('/api/speed-board');
  return (data as List)
      .map((item) => SpeedBoardEntry.fromJson(
            Map<String, dynamic>.from(item as Map),
          ))
      .toList();
});

final agencySafetyRollupsProvider =
    FutureProvider<List<AgencySafetyRollup>>((ref) async {
  final data = await ApiService.get('/api/agency-safety-rollups');
  return (data as List)
      .map((item) => AgencySafetyRollup.fromJson(
            Map<String, dynamic>.from(item as Map),
          ))
      .toList();
});
