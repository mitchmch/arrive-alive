export const CONTRACT_VERSION = 2;
export const COLLECTIONS = ['users', 'profiles', 'journeys', 'incidents', 'agencies', 'speedLimits'] as const;

const encoder = new TextEncoder();
export function bytesToHex(bytes: Uint8Array): string { return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join(''); }
export function bytesToBase64Url(bytes: Uint8Array): string {
  let value = ''; for (const byte of bytes) value += String.fromCharCode(byte);
  return btoa(value).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}
export function randomToken(bytes = 32): string { const value = new Uint8Array(bytes); crypto.getRandomValues(value); return bytesToBase64Url(value); }
export async function sha256(value: string): Promise<string> { return bytesToHex(new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(value)))); }
export async function deriveSecret(secret: string, salt: string, iterations = 210000): Promise<string> {
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits({name: 'PBKDF2', hash: 'SHA-256', salt: encoder.encode(salt), iterations}, key, 256);
  return bytesToHex(new Uint8Array(bits));
}
export function safeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false; let difference = 0;
  for (let index = 0; index < left.length; index++) difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return difference === 0;
}
export function normalizePhone(value: unknown): string {
  const phone = String(value ?? '').trim();
  if (phone === 'admin') return phone;
  const normalized = phone.replace(/[\s()-]/g, '');
  if (!/^\+?[0-9]{8,15}$/.test(normalized)) throw new ApiError(400, 'Enter a valid phone number');
  return normalized;
}
export function requireString(value: unknown, name: string, min = 1, max = 500): string {
  if (typeof value !== 'string') throw new ApiError(400, `${name} must be a string`);
  const result = value.trim(); if (result.length < min || result.length > max) throw new ApiError(400, `${name} must be ${min}-${max} characters`); return result;
}
export function optionalNumber(value: unknown, name: string, min: number, max: number): number | null {
  if (value === null || value === undefined || value === '') return null; const result = Number(value);
  if (!Number.isFinite(result) || result < min || result > max) throw new ApiError(400, `${name} is out of range`); return result;
}
export function parseJsonValue(value: unknown, fallback: unknown): unknown {
  if (value === undefined || value === null || value === '') return fallback;
  if (typeof value !== 'string') return value;
  try { return JSON.parse(value); } catch { throw new ApiError(400, 'A JSON field is malformed'); }
}
export function camel(row: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(row)) out[key.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase())] = value;
  if ('createdAt' in out && !('timestamp' in out)) out.timestamp = out.createdAt;
  return out;
}
export function routePath(url: string): string {
  let path = new URL(url).pathname.replace(/\/+$/, '') || '/';
  const marker = '/app-api'; const at = path.indexOf(marker); if (at >= 0) path = path.slice(at + marker.length) || '/';
  return path;
}
export class ApiError extends Error { constructor(public status: number, message: string, public code = 'request_error') { super(message); } }
