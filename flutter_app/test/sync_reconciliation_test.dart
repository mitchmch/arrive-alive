import 'package:arrive_alive/core/config.dart';
import 'package:arrive_alive/models/sync_record.dart';
import 'package:flutter_test/flutter_test.dart';

VersionedRecord record({
  required int version,
  required DateTime updatedAt,
  String value = 'value',
}) {
  return VersionedRecord(
    stableId: 'journey-123',
    updatedAt: updatedAt,
    version: version,
    data: {'value': value},
  );
}

void main() {
  group('reconciliation', () {
    test('newer version wins even when its timestamp is older', () {
      final local = record(
        version: 2,
        updatedAt: DateTime.utc(2026, 8, 26, 12),
        value: 'local',
      );
      final remote = record(
        version: 3,
        updatedAt: DateTime.utc(2026, 8, 26, 11),
        value: 'remote',
      );

      expect(reconcileRecord(local, remote), same(remote));
    });

    test('updatedAt breaks equal-version ties and equal input is idempotent',
        () {
      final local = record(
        version: 2,
        updatedAt: DateTime.utc(2026, 8, 26, 12),
        value: 'local',
      );
      final olderRemote = record(
        version: 2,
        updatedAt: DateTime.utc(2026, 8, 26, 11),
        value: 'remote',
      );

      expect(reconcileRecord(local, olderRemote), same(local));
      expect(reconcileRecord(local, local), same(local));
    });

    test('different stable IDs cannot be reconciled', () {
      final local = record(version: 1, updatedAt: DateTime.utc(2026));
      final other = VersionedRecord(
        stableId: 'other',
        updatedAt: DateTime.utc(2026),
        version: 1,
        data: const {},
      );
      expect(() => reconcileRecord(local, other), throwsArgumentError);
    });
  });

  group('queue policy', () {
    test('deduplicates stable operation IDs in insertion order', () {
      expect(
        SyncQueuePolicy.uniqueOperationIds(['a', 'a', 'b', 'a']),
        ['a', 'b'],
      );
    });

    test('uses capped exponential retry delays', () {
      expect(SyncQueuePolicy.retryDelay(0), const Duration(seconds: 1));
      expect(SyncQueuePolicy.retryDelay(3), const Duration(seconds: 8));
      expect(SyncQueuePolicy.retryDelay(20), const Duration(seconds: 16));
    });
  });

  test('default production build has a valid durable backend', () {
    expect(AppConfig.hasBackend, isTrue);
    expect(AppConfig.apiBaseUrl, startsWith('https://'));
    const health = SyncHealth(
      backendConfigured: false,
      pending: 2,
      retrying: 1,
      failed: 1,
    );
    expect(health.healthy, isFalse);
  });
}
