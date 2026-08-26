import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/agency_notice.dart';
import 'api_service.dart';

class AgencyNoticeService {
  static const _seenPrefix = 'aa_seen_agency_notices_';

  Future<List<AgencyNotice>> fetchUnseen(int userId) async {
    final data = await ApiService.get('/api/notifications');
    final notices = (data as List)
        .map((item) => AgencyNotice.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .where((notice) =>
            notice.classification == AgencyClassification.trusted ||
            notice.classification == AgencyClassification.avoid)
        .toList();
    final seen = await _seenKeys(userId);
    return notices
        .where((notice) => !seen.contains(notice.deduplicationKey))
        .toList();
  }

  Future<void> markSeen(int userId, AgencyNotice notice) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = await _seenKeys(userId);
    seen.add(notice.deduplicationKey);
    await prefs.setString(_key(userId), jsonEncode(seen.toList()..sort()));
    try {
      await ApiService.patch('/api/notifications/${notice.id}/read', const {});
    } catch (_) {
      // Local deduplication remains authoritative while offline.
    }
  }

  Future<Set<String>> _seenKeys(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) return <String>{};
    try {
      return Set<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return <String>{};
    }
  }

  String _key(int userId) => '$_seenPrefix$userId';
}
