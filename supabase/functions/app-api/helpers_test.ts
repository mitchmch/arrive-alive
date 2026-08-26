function assertEquals(actual: unknown, expected: unknown) { if (actual !== expected) throw new Error(`Expected ${expected}, got ${actual}`); }
function assertNotEquals(actual: unknown, expected: unknown) { if (actual === expected) throw new Error(`Values should differ: ${actual}`); }
async function assertRejects(fn: () => Promise<unknown>, type: new (...args: any[]) => Error) { try { await fn(); } catch (error) { if (error instanceof type) return; throw error; } throw new Error('Expected rejection'); }
import {ApiError, assessJourneySamples, decideAgencyRollup, deriveSecret, normalizePhone, randomToken, robustWeightedSpeed, routePath, safeEqual, sha256, stableUuid} from './helpers.ts';

Deno.test('opaque tokens have entropy and store a one-way digest', async () => {
  const first = randomToken();
  const second = randomToken();
  assertNotEquals(first, second);
  assertEquals(first.length >= 43, true);
  assertNotEquals(await sha256(first), first);
});

Deno.test('PBKDF2 is deterministic for a salt and separates salts', async () => {
  const first = await deriveSecret('1234', 'salt-one', 100000);
  assertEquals(first, await deriveSecret('1234', 'salt-one', 100000));
  assertNotEquals(first, await deriveSecret('1234', 'salt-two', 100000));
  assertEquals(safeEqual(first, first), true);
  assertEquals(safeEqual(first, `${first.slice(0, -1)}0`), false);
});

Deno.test('phone and function routes are normalized safely', () => {
  assertEquals(normalizePhone('+237 699-123-456'), '+237699123456');
  assertEquals(routePath('https://example.test/functions/v1/app-api/api/sync'), '/api/sync');
  assertRejects(() => Promise.resolve(normalizePhone('not-a-phone')), ApiError);
});

Deno.test('stable UUIDs are deterministic and journey episodes require sustained evidence', async () => {
  assertEquals(await stableUuid('test','same'),await stableUuid('test','same'));
  const base=Date.parse('2026-08-26T10:00:00.000Z');
  const result=await assessJourneySamples('journey-test',[
    {timestamp:new Date(base).toISOString(),speedKph:61,accuracyM:5},
    {timestamp:new Date(base+1000).toISOString(),speedKph:64,accuracyM:5},
    {timestamp:new Date(base+2000).toISOString(),speedKph:66,accuracyM:5},
    {timestamp:new Date(base+3000).toISOString(),speedKph:65,accuracyM:5},
    {timestamp:new Date(base+4000).toISOString(),speedKph:58,accuracyM:5},
    {timestamp:new Date(base+5000).toISOString(),speedKph:250,accuracyM:5},
  ],60);
  assertEquals(result.episodes.length,1);
  assertEquals(result.episodes[0].sampleCount,3);
  assertEquals(result.episodes[0].durationSeconds,2);
  // The first reading is inside the 2 km/h tolerance and the last is rejected.
  assertEquals(result.assessment.acceptedSampleCount,5);
  assertEquals(result.assessment.rejectedSampleCount,1);
  assertEquals(result.assessment.resultType,'violator');
});

Deno.test('legacy web speedKmh samples remain readable during rollout', async () => {
  const base=Date.parse('2026-08-26T11:00:00.000Z');
  const result=await assessJourneySamples('journey-web-compat',[
    {timestamp:new Date(base).toISOString(),speedKmh:72,accuracyM:4},
    {timestamp:new Date(base+1000).toISOString(),speedKmh:73,accuracyM:4},
    {timestamp:new Date(base+2000).toISOString(),speedKmh:74,accuracyM:4},
  ],60);
  assertEquals(result.assessment.acceptedSampleCount,3);
  assertEquals(result.episodes.length,1);
});

Deno.test('robust evidence correlation deduplicates reporters and caps outliers', () => {
  const result=robustWeightedSpeed(80,[
    {reporterId:'a',speedKph:82},{reporterId:'a',speedKph:200},
    {reporterId:'b',speedKph:84},{reporterId:'c',speedKph:250},
  ]);
  assertEquals(result.independentReporterCount,3);
  assertEquals(result.outlierCount,1);
  assertEquals(result.cappedReportCount,1);
  assertEquals(result.valueKph<100,true);
});

Deno.test('agency rollups enforce explicit evidence thresholds before labels', () => {
  assertEquals(decideAgencyRollup({journeyCount:9,distinctUserCount:10,totalDurationSeconds:9999,violationJourneyCount:0}).status,'insufficient_evidence');
  assertEquals(decideAgencyRollup({journeyCount:20,distinctUserCount:8,totalDurationSeconds:7200,violationJourneyCount:0}).status,'trusted');
  assertEquals(decideAgencyRollup({journeyCount:20,distinctUserCount:8,totalDurationSeconds:7200,violationJourneyCount:5}).status,'avoid');
});
