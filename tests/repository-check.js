const assert = require('node:assert/strict');
const {
  COLLECTIONS,
  createRepository,
  emptySnapshot,
  mergeSnapshots,
  canonicalizeRecord,
} = require('../web-repository');

assert.deepEqual(
  COLLECTIONS,
  ['users', 'profiles', 'journeys', 'incidents', 'agencies', 'speedLimits'],
  'The repository exposes the complete shared web-data contract',
);

const canonicalUser = canonicalizeRecord(
  {id: 'remote-user', phone: '625043224', displayName: 'Release QA Updated'},
  'users',
);
assert.equal(canonicalUser.name, 'Release QA Updated');

const canonicalAgency = canonicalizeRecord(
  {id: 'agency-1', safetyScore: 100, violationCount: 3, verified: true},
  'agencies',
);
assert.equal(canonicalAgency.score, 100);
assert.equal(canonicalAgency.violations, 3);
assert.equal(canonicalAgency.verified, true);

const canonicalLimit = canonicalizeRecord(
  {id: 'speed-motorbike', vehicle_type: 'bike', limit_kmh: 60},
  'speedLimits',
);
assert.equal(canonicalLimit.mode, 'motorbike');
assert.equal(canonicalLimit.limit, 60);

const logicalMerge = mergeSnapshots(
  {
    ...emptySnapshot(),
    collections: {
      ...emptySnapshot().collections,
      users: [
        {
          id: 'user-local',
          phone: '678825254',
          name: 'Administrator',
          updatedAt: '2026-08-26T18:00:00.000Z',
          version: 1,
        },
      ],
      speedLimits: [
        {
          id: 'limit-bike',
          mode: 'bike',
          limit: 70,
          updatedAt: '2026-08-26T18:00:00.000Z',
          version: 1,
        },
      ],
    },
  },
  {
    ...emptySnapshot(),
    collections: {
      ...emptySnapshot().collections,
      users: [
        {
          id: 'remote-admin',
          phone: '678825254',
          displayName: 'Administrator',
          updatedAt: '2026-08-26T19:00:00.000Z',
          version: 2,
        },
      ],
      speedLimits: [
        {
          id: 'speed-motorbike',
          mode: 'motorbike',
          limitKph: 60,
          updatedAt: '2026-08-26T19:00:00.000Z',
          version: 2,
        },
      ],
    },
  },
);
assert.equal(logicalMerge.collections.users.length, 1);
assert.equal(logicalMerge.collections.users[0].name, 'Administrator');
assert.equal(logicalMerge.collections.speedLimits.length, 1);
assert.equal(logicalMerge.collections.speedLimits[0].mode, 'motorbike');
assert.equal(logicalMerge.collections.speedLimits[0].limit, 60);

const memoryStorage = (() => {
  const values = new Map();
  return {
    getItem: key => values.get(key) || null,
    setItem: (key, value) => values.set(key, value),
  };
})();

const repository = createRepository({storage: memoryStorage, fetch: null});
const first = repository.upsert('journeys', {id: 'journey-1', ownerId: 'user-1', updatedAt: '2026-08-26T10:00:00.000Z'});
const second = repository.upsert('journeys', {...first, updatedAt: '2026-08-26T11:00:00.000Z'});
assert.equal(first.version, 1);
assert.equal(second.version, 2);
assert.equal(createRepository({storage: memoryStorage, fetch: null}).list('journeys').length, 1);

const local = emptySnapshot();
local.collections.profiles.push({id: 'profile-1', name: 'Local', version: 2, updatedAt: '2026-08-26T12:00:00.000Z'});
const remote = emptySnapshot();
remote.collections.profiles.push({id: 'profile-1', name: 'Older remote', version: 9, updatedAt: '2026-08-26T11:00:00.000Z'});
assert.equal(mergeSnapshots(local, remote).collections.profiles[0].name, 'Local', 'Newer timestamps win');

remote.collections.profiles[0] = {id: 'profile-1', name: 'Same-time higher version', version: 3, updatedAt: '2026-08-26T12:00:00.000Z'};
assert.equal(mergeSnapshots(local, remote).collections.profiles[0].name, 'Same-time higher version', 'Version breaks timestamp ties');

const failingStorage = {getItem() { throw new Error('blocked'); }, setItem() { throw new Error('blocked'); }};
assert.doesNotThrow(() => createRepository({storage: failingStorage, fetch: null}).upsert('users', {id: 'u-1'}));

console.log('Repository checks passed.');
