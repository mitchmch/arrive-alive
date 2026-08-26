import 'package:arrive_alive/models/agency.dart';
import 'package:arrive_alive/models/agency_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classification comes from explicit backend field, not score or summary',
      () {
    final agency = Agency.fromJson({
      'id': 1,
      'name': 'Example Transit',
      'safetyScore': 100,
      'classification': 'avoid',
      'summaryText': 'Generated prose claiming everything is safe.',
    });

    expect(agency.shouldAvoid, isTrue);
    expect(agency.isTrusted, isFalse);
  });

  test('notice deduplication key changes only with notice version', () {
    final notice = AgencyNotice.fromJson({
      'id': 'agency-1-trusted',
      'agencyId': 1,
      'agencyName': 'Example Transit',
      'classification': 'trusted',
      'summaryText': 'Reviewed evidence.',
      'version': 3,
    });

    expect(notice.deduplicationKey, 'agency-1-trusted:3');
  });

  test('canonical backend notification maps deterministic agency status', () {
    final notice = AgencyNotice.fromJson({
      'id': 'notice-42',
      'type': 'agency_avoid',
      'title': 'Example Transit',
      'body': 'Published evidence includes journeys with violations.',
      'data': {
        'agencyId': 42,
        'status': 'avoid',
      },
    });

    expect(notice.agencyId, 42);
    expect(notice.agencyName, 'Example Transit');
    expect(notice.classification, AgencyClassification.avoid);
    expect(
      notice.summaryText,
      'Published evidence includes journeys with violations.',
    );
    expect(notice.deduplicationKey, 'notice-42:1');
  });
}
