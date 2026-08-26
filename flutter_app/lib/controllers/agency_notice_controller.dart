import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agency_notice.dart';
import '../services/agency_notice_service.dart';

final agencyNoticeServiceProvider = Provider<AgencyNoticeService>(
  (_) => AgencyNoticeService(),
);

final unseenAgencyNoticesProvider =
    FutureProvider.family<List<AgencyNotice>, int>((ref, userId) {
  return ref.read(agencyNoticeServiceProvider).fetchUnseen(userId);
});
