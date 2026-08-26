enum SyncItemState { pending, retrying, failed }

class VersionedRecord {
  const VersionedRecord({
    required this.stableId,
    required this.updatedAt,
    required this.version,
    required this.data,
  });

  final String stableId;
  final DateTime updatedAt;
  final int version;
  final Map<String, dynamic> data;
}

/// Deterministic last-write reconciliation. Version wins; updatedAt breaks a
/// tie. Equal records keep the local object, making repeated pulls idempotent.
VersionedRecord reconcileRecord(
  VersionedRecord local,
  VersionedRecord remote,
) {
  if (local.stableId != remote.stableId) {
    throw ArgumentError('Records must share a stable ID');
  }
  if (remote.version != local.version) {
    return remote.version > local.version ? remote : local;
  }
  return remote.updatedAt.isAfter(local.updatedAt) ? remote : local;
}

class SyncHealth {
  const SyncHealth({
    required this.backendConfigured,
    required this.pending,
    required this.retrying,
    required this.failed,
    this.lastSuccessAt,
    this.lastError,
    this.syncing = false,
  });

  final bool backendConfigured;
  final int pending;
  final int retrying;
  final int failed;
  final DateTime? lastSuccessAt;
  final String? lastError;
  final bool syncing;

  bool get healthy =>
      backendConfigured && failed == 0 && retrying == 0 && !syncing;
}

abstract final class SyncQueuePolicy {
  static Duration retryDelay(int attempts) {
    return Duration(seconds: 1 << attempts.clamp(0, 4));
  }

  static List<String> uniqueOperationIds(Iterable<String> ids) {
    return ids.toSet().toList(growable: false);
  }
}
