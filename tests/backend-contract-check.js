const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20260826190000_durable_backend.sql'), 'utf8');
const edge = fs.readFileSync(path.join(root, 'supabase/functions/app-api/index.ts'), 'utf8');
const helpers = fs.readFileSync(path.join(root, 'supabase/functions/app-api/helpers.ts'), 'utf8');
const flutterApi = fs.readFileSync(path.join(root, 'flutter_app/lib/services/api_service.dart'), 'utf8');
const webRepository = fs.readFileSync(path.join(root, 'web-repository.js'), 'utf8');

for (const table of ['users','app_sessions','journeys','incidents','incident_confirmations','violations','agencies','speed_limits','audit_log']) {
  assert.match(migration, new RegExp(`create table public\\.${table} \\(`));
  assert.match(migration, new RegExp(`alter table public\\.${table} enable row level security;`));
}
assert.match(migration, /revoke all on all tables in schema public from anon, authenticated/);
assert.match(migration, /create or replace function public\.confirm_incident/);
assert.match(edge, /SUPABASE_SERVICE_ROLE_KEY/);
assert.match(helpers, /PBKDF2/);
assert.match(edge, /token_hash/);
assert.match(edge, /Administrator access required/);
assert.match(edge, /https:\/\/cp\.arrivealive\.app/);
for (const route of ['/api/auth/register','/api/auth/login','/api/auth/reset-pin','/api/profile','/api/sync','/api/stats','/api/users','/api/admin/sync-health']) {
  assert.ok(edge.includes(route), `Edge API route missing: ${route}`);
}
assert.match(flutterApi, /'Authorization': 'Bearer \$token'/);
assert.match(webRepository, /'Authorization': `Bearer \$\{tokenProvider\(\)\}`/);
assert.doesNotMatch(edge, /service_role\s*[:=]\s*['"][A-Za-z0-9]/i);
console.log('Backend contract checks passed.');
