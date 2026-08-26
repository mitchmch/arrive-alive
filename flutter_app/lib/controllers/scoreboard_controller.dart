import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/violation.dart';
import '../models/agency.dart';
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
