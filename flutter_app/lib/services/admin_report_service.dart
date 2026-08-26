import 'package:flutter/services.dart';

import '../models/agency.dart';

enum AdminReportActionStatus { completed, unavailable, failed }

class AdminReportActionResult {
  const AdminReportActionResult(this.status, this.message);

  final AdminReportActionStatus status;
  final String message;
}

/// Platform boundary for administrator report delivery.
///
/// Sharing is dependency-free and copies a ready-to-send summary. PDF export is
/// intentionally exposed through the same interface so an app-specific
/// implementation can later use `printing`/`pdf` without coupling the admin UI
/// to platform plugins.
abstract interface class AdminReportService {
  Future<AdminReportActionResult> shareAgencyReport(Agency agency);

  Future<AdminReportActionResult> exportAgencyPdf(Agency agency);
}

class ClipboardAdminReportService implements AdminReportService {
  const ClipboardAdminReportService();

  @override
  Future<AdminReportActionResult> shareAgencyReport(Agency agency) async {
    try {
      await Clipboard.setData(ClipboardData(text: agency.reportSummary));
      return const AdminReportActionResult(
        AdminReportActionStatus.completed,
        'Report copied. Paste it into your preferred sharing app.',
      );
    } catch (_) {
      return const AdminReportActionResult(
        AdminReportActionStatus.failed,
        'The report could not be copied on this device.',
      );
    }
  }

  @override
  Future<AdminReportActionResult> exportAgencyPdf(Agency agency) async {
    return const AdminReportActionResult(
      AdminReportActionStatus.unavailable,
      'PDF export needs a platform implementation. See README_FLUTTER_SETUP.md.',
    );
  }
}
