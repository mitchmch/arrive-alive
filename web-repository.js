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

  function normaliseRecord(record, collection, previous) {
    const timestamp = record.updatedAt || nowIso();
    return {
      ...(previous || {}),
      ...record,
      id: String(record.id || previous?.id || makeId(collection.slice(0, 3))),
      version: Math.max(Number(record.version) || 0, Number(previous?.version) || 0) + 1,
      createdAt: record.createdAt || previous?.createdAt || timestamp,
      updatedAt: timestamp,
    };
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
      for (const record of base?.collections?.[collection] || []) records.set(record.id, record);
      for (const record of incoming?.collections?.[collection] || []) {
        records.set(record.id, winner(records.get(record.id), record));
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
      const index = items.findIndex(item => item.id === record.id);
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

  return {COLLECTIONS, SCHEMA_VERSION, emptySnapshot, mergeSnapshots, normaliseRecord, createRepository};
});
