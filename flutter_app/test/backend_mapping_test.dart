import 'package:arrive_alive/models/agency.dart';
import 'package:arrive_alive/services/speed_limit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('backend data mappings', () {
    test('agency accepts canonical and legacy score aliases', () {
      final canonical = Agency.fromJson({
        'id': '7',
        'name': 'Safe Travel',
        'safetyScore': 85,
        'violation_count': 4,
        'total_journeys': 22,
      });
      final legacy = Agency.fromJson({
        'id': 8,
        'name': 'Trusted Travel',
        'score': 100,
        'violations': 1,
      });

      expect(canonical.id, 7);
      expect(canonical.safetyScore, 85);
      expect(canonical.violationCount, 4);
      expect(canonical.totalJourneys, 22);
      expect(legacy.safetyScore, 100);
      expect(legacy.violationCount, 1);
    });

    test('vehicle modes use the backend motorbike key', () {
      expect(SpeedLimitService.normalizeMode('bike'), 'motorbike');
      expect(SpeedLimitService.normalizeMode('motorcycle'), 'motorbike');
      expect(SpeedLimitService.normalizeMode('car'), 'car');
    });
  });
}
