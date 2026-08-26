function assertEquals(actual: unknown, expected: unknown) { if (actual !== expected) throw new Error(`Expected ${expected}, got ${actual}`); }
function assertNotEquals(actual: unknown, expected: unknown) { if (actual === expected) throw new Error(`Values should differ: ${actual}`); }
async function assertRejects(fn: () => Promise<unknown>, type: new (...args: any[]) => Error) { try { await fn(); } catch (error) { if (error instanceof type) return; throw error; } throw new Error('Expected rejection'); }
import {ApiError, deriveSecret, normalizePhone, randomToken, routePath, safeEqual, sha256} from './helpers.ts';

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
