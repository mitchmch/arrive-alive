(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.ArriveAliveRepository = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const COLLECTIONS = ['users', 'profiles', 'journeys', 'incidents', 'agencies', 'speedLimits'];
  const STORAGE_KEY = 'arrive-alive-web-data-v1';
  const SCHEMA_VERSION = 1;

  function nowIso() {
    return new Date().toISOString();
  }

  function makeId(prefix) {
    const random = typeof crypto !== 'undefined' && crypto.randomUUID
      ? crypto.randomUUID()
      : Math.random().toString(36).slice(2) + Date.now().toString(36);
    return `${prefix}-${random}`;
  }

  function emptySnapshot() {
    return {
      schemaVersion: SCHEMA_VERSION,
      revision: 0,
      updatedAt: nowIso(),
      collections: Object.fromEntries(COLLECTIONS.map(name => [name, []])),
    };
  }

  function normaliseMode(mode) {
    const value = String(mode || '').trim().toLowerCase();
    if (value === 'bike' || value === 'motorcycle') return 'motorbike';
    return value;
  }

  function canonicalizeRecord(record, collection) {
    const value = {...(record || {})};
    if (value.id != null) value.id = String(value.id);

    if (collection === 'users') {
      value.phone = String(value.phone || '').trim();
      value.name = String(value.name || value.displayName || value.phone || '').trim();
      value.displayName = value.name;
    } else if (collection === 'agencies') {
      const score = Number(value.score ?? value.safetyScore ?? value.safety_score ?? 0);
      const violations = Number(
        value.violations ?? value.violationCount ?? value.violation_count ?? 0,
      );
      value.score = Number.isFinite(score) ? score : 0;
      value.safetyScore = value.score;
      value.violations = Number.isFinite(violations) ? violations : 0;
      value.violationCount = value.violations;
      value.verified = Boolean(value.verified ?? value.trusted ?? value.score === 100);
    } else if (collection === 'speedLimits') {
      value.mode = normaliseMode(value.mode ?? value.vehicle_type);
      const limit = Number(value.limit ?? value.limitKph ?? value.limit_kmh);
      if (Number.isFinite(limit)) {
        value.limit = limit;
        value.limitKph = limit;
        value.limit_kmh = limit;
      }
      value.vehicle_type = value.mode;
    }
    return value;
  }

  function recordKey(record, collection) {
    const value = canonicalizeRecord(record, collection);
    if (collection === 'users' && value.phone) return `phone:${value.phone}`;
    if (collection === 'profiles') {
      const owner = value.ownerId || value.userId || value.phone;
      if (owner) return `owner:${String(owner)}`;
    }
    if (collection === 'speedLimits' && value.mode) return `mode:${value.mode}`;
    if (collection === 'agencies') {
      const agency = value.stableId || value.stable_id || value.id || value.name;
      if (agency) return `agency:${String(agency).toLowerCase()}`;
    }
    return `id:${String(value.stableId || value.stable_id || value.id || '')}`;
  }

  function normaliseRecord(record, collection, previous) {
    const canonical = canonicalizeRecord(record, collection);
    const timestamp = canonical.updatedAt || nowIso();
    return canonicalizeRecord({
      ...(previous || {}),
      ...canonical,
      id: String(previous?.id || canonical.id || makeId(collection.slice(0, 3))),
      version: Math.max(Number(canonical.version) || 0, Number(previous?.version) || 0) + 1,
      createdAt: canonical.createdAt || previous?.createdAt || timestamp,
      updatedAt: timestamp,
    }, collection);
  }

  function winner(local, incoming) {
    if (!local) return incoming;
    if (!incoming) return local;
    const localTime = Date.parse(local.updatedAt || 0) || 0;
    const incomingTime = Date.parse(incoming.updatedAt || 0) || 0;
    if (incomingTime !== localTime) return incomingTime > localTime ? incoming : local;
    return (Number(incoming.version) || 0) >= (Number(local.version) || 0) ? incoming : local;
  }

  function mergeSnapshots(base, incoming) {
    const merged = emptySnapshot();
    for (const collection of COLLECTIONS) {
      const records = new Map();
      for (const source of base?.collections?.[collection] || []) {
        const record = canonicalizeRecord(source, collection);
        records.set(recordKey(record, collection), record);
      }
      for (const source of incoming?.collections?.[collection] || []) {
        const record = canonicalizeRecord(source, collection);
        const key = recordKey(record, collection);
        records.set(key, canonicalizeRecord(winner(records.get(key), record), collection));
      }
      merged.collections[collection] = [...records.values()];
    }
    merged.revision = Math.max(Number(base?.revision) || 0, Number(incoming?.revision) || 0);
    merged.updatedAt = winner(
      { updatedAt: base?.updatedAt || 0, version: base?.revision || 0 },
      { updatedAt: incoming?.updatedAt || 0, version: incoming?.revision || 0 },
    ).updatedAt;
    return merged;
  }

  function createSafeStorage(storage) {
    return {
      read() {
        try {
          const parsed = JSON.parse(storage?.getItem(STORAGE_KEY) || 'null');
          return parsed?.collections ? mergeSnapshots(emptySnapshot(), parsed) : emptySnapshot();
        } catch (_) {
          return emptySnapshot();
        }
      },
      write(snapshot) {
        try {
          storage?.setItem(STORAGE_KEY, JSON.stringify(snapshot));
          return true;
        } catch (_) {
          return false;
        }
      },
    };
  }

  function createRepository(options = {}) {
    const storage = createSafeStorage(options.storage);
    let snapshot = storage.read();
    let status = {
      mode: 'local',
      state: 'idle',
      durable: false,
      lastAttemptAt: null,
      lastSuccessAt: null,
      message: 'Using device-local or in-memory data.',
    };
    const endpoint = options.endpoint || '/api/sync';
    const tokenProvider = options.tokenProvider || (() => null);
    const fetchFn = options.fetch || (typeof fetch === 'function' ? fetch.bind(globalThis) : null);

    function persist() {
      snapshot.updatedAt = nowIso();
      snapshot.revision += 1;
      storage.write(snapshot);
    }

    function list(collection, predicate) {
      if (!COLLECTIONS.includes(collection)) throw new Error(`Unknown collection: ${collection}`);
      const items = snapshot.collections[collection].filter(item => !item.deletedAt);
      return predicate ? items.filter(predicate) : items.slice();
    }

    function upsert(collection, record) {
      if (!COLLECTIONS.includes(collection)) throw new Error(`Unknown collection: ${collection}`);
      const items = snapshot.collections[collection];
      const key = recordKey(record, collection);
      const index = items.findIndex(item => recordKey(item, collection) === key);
      const next = normaliseRecord(record, collection, index >= 0 ? items[index] : null);
      if (index >= 0) items[index] = next;
      else items.push(next);
      persist();
      return next;
    }

    function remove(collection, id) {
      const existing = snapshot.collections[collection]?.find(item => item.id === id);
      if (!existing) return null;
      return upsert(collection, {...existing, deletedAt: nowIso()});
    }

    async function sync(role = 'user') {
      status = {...status, state: 'syncing', lastAttemptAt: nowIso(), message: 'Checking the sync API…'};
      if (!fetchFn) {
        status = {...status, state: 'offline', message: 'Sync API unavailable; changes remain local.'};
        return getStatus();
      }
      try {
        const response = await fetchFn(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            ...(tokenProvider() ? {'Authorization': `Bearer ${tokenProvider()}`} : {}),
          },
          body: JSON.stringify({operation: 'merge', snapshot}),
        });
        if (!response.ok) throw new Error(`Sync API returned ${response.status}`);
        const payload = await response.json();
        snapshot = mergeSnapshots(snapshot, payload.snapshot);
        storage.write(snapshot);
        status = {
          mode: 'api',
          state: 'synced',
          durable: Boolean(payload.persistence?.durable),
          lastAttemptAt: status.lastAttemptAt,
          lastSuccessAt: nowIso(),
          message: payload.persistence?.message || 'API sync completed.',
        };
      } catch (error) {
        status = {
          ...status,
          mode: 'local',
          state: 'offline',
          durable: false,
          message: `Sync unavailable; changes remain local (${error.message}).`,
        };
      }
      return getStatus();
    }

    function getStatus() {
      return {...status};
    }

    return {
      collections: COLLECTIONS.slice(),
      list,
      upsert,
      remove,
      sync,
      getStatus,
      getSnapshot: () => JSON.parse(JSON.stringify(snapshot)),
      replaceSnapshot(next) {
        snapshot = mergeSnapshots(snapshot, next);
        storage.write(snapshot);
      },
    };
  }

  return {
    COLLECTIONS,
    SCHEMA_VERSION,
    emptySnapshot,
    mergeSnapshots,
    normaliseRecord,
    canonicalizeRecord,
    recordKey,
    createRepository,
  };
});
