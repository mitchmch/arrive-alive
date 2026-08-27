const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20260826190000_durable_backend.sql'), 'utf8');
const publicReportsMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20260826213000_public_agency_reports.sql'), 'utf8');
const flutterEvidenceMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20260826222000_speed_safety_evidence.sql'), 'utf8');
const safetyMigration = fs.readFileSync(path.join(root, 'supabase/migrations/20260826223000_safety_intelligence.sql'), 'utf8');
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
assert.match(edge, /https:\/\/arrivealive\.app/);
assert.match(edge, /function publicHazard\(/, 'Public hazard output must pass through an explicit sanitizer');
assert.match(edge, /path==='\/api\/public-hazards'&&method==='GET'/, 'The guest-readable active hazard route must exist');
assert.match(edge, /function publicSpeedLimit\(/, 'Public speed limits must pass through an explicit sanitizer');
assert.match(edge, /path==='\/api\/public-speed-limits'&&method==='GET'/, 'The guest-readable speed-limit route must exist before authentication');
assert.match(edge, /\.select\('mode,limit_kph,updated_at'\)\.is\('deleted_at',null\)/, 'Public speed limits must expose only the safe read fields from active records');
assert.match(edge, /if\(!modes\.includes\(mode\)\|\|!Number\.isFinite\(limitKph\)\|\|limitKph<1\|\|limitKph>300\)return null/, 'Public speed-limit values must be allowlisted and bounded');
assert.match(edge, /\.eq\('status','active'\)\.is\('deleted_at',null\)/, 'The public route must return active, non-deleted hazards only');
assert.doesNotMatch(
  edge.match(/function publicHazard\([\s\S]*?\n\}/)?.[0] || '',
  /reporter|vehicle_reg|driver_name/,
  'Public hazard output must not expose reporter or vehicle identity',
);
for (const route of ['/api/auth/register','/api/auth/login','/api/auth/reset-pin','/api/profile','/api/sync','/api/stats','/api/users','/api/admin/sync-health']) {
  assert.ok(edge.includes(route), `Edge API route missing: ${route}`);
}
assert.match(publicReportsMigration, /create table public\.public_agency_reports/);
assert.match(publicReportsMigration, /alter table public\.public_agency_reports enable row level security/);
assert.match(publicReportsMigration, /revoke all on public\.public_agency_reports from anon, authenticated/);
assert.match(edge, /publicReportSnapshot/);
assert.match(edge, /\/api\/public-reports/);
assert.match(edge, /admin\(identity\).*publicReportSnapshot/s, 'Publishing must require an administrator');
assert.match(flutterApi, /'Authorization': 'Bearer \$token'/);
assert.match(webRepository, /'Authorization': `Bearer \$\{tokenProvider\(\)\}`/);
assert.doesNotMatch(edge, /service_role\s*[:=]\s*['"][A-Za-z0-9]/i);
assert.match(safetyMigration, /create table if not exists public\.speed_samples/, 'Safety migration must remain compatible when the Flutter migration is present or reserved');
assert.doesNotMatch(flutterEvidenceMigration, /create table public\.speed_samples/, 'Flutter compatibility migration must not recreate the shared speed sample table');
for (const table of ['violation_episodes','speed_reports','evidence_correlations','journey_safety_assessments','speed_board_entries','agency_safety_rollups','user_notifications']) {
  assert.match(safetyMigration, new RegExp(`create table public\\.${table}`));
  assert.match(safetyMigration, new RegExp(`'${table}'`), `${table} must be included in the RLS deny loop`);
}
assert.match(safetyMigration, /create or replace function public\.finalize_journey_safety/);
assert.match(safetyMigration, /on conflict \(journey_id\)/, 'Journey completion must be idempotent');
assert.match(edge, /assessJourneySamples/);
assert.match(edge, /robustWeightedSpeed/);
assert.match(edge, /OPENAI_API_KEY/);
assert.match(edge, /Never decide, revise, recommend, or infer trusted\/avoid status/);
assert.match(edge, /SAFETY_SCHEDULER_SECRET/);
for (const route of ['/api/journeys/complete-safety','/api/speed-board','/api/speed-reports','/api/notifications','/api/admin/safety-rollups','/api/safety/rollups/run','/api/admin/safety-summary-check']) {
  assert.ok(edge.includes(route), `Safety API route missing: ${route}`);
}
console.log('Backend contract checks passed.');
