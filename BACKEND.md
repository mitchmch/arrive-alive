# Arrive Alive durable backend

This directory contains a production-oriented Supabase data plane. It was created without deploying, applying migrations, creating credentials, or calling an external service.

## Architecture

- `supabase/migrations/20260826190000_durable_backend.sql` creates normalized durable tables, indexes, version/timestamp metadata, idempotency state, a transactional incident-confirmation RPC, an audit log, and a private `profile-photos` bucket.
- Every application table has RLS enabled and no permissive `anon` or `authenticated` policies. Direct browser/mobile database access is intentionally denied. Only the `app-api` Edge Function uses the service role.
- `supabase/functions/app-api/index.ts` exposes the REST contract used by Flutter plus `/api/sync` snapshot pull/push/merge for the web repository.
- `supabase/migrations/20260826223000_safety_intelligence.sql` adds immutable speed samples, deterministic assessments and agency rollups, Speed Board entries, and deduplicated user notifications. Flutter details are documented in `flutter_app/SPEED_SAFETY_API_CONTRACT.md`.
- `api/sync.js` is a narrow Vercel proxy to `/api/sync`; it returns an honest 503 when `SUPABASE_APP_API_URL` is absent and never keeps process-memory data.

## Required environment variables

Supabase Edge Function secrets/runtime:

```text
SUPABASE_URL=https://PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...             # server-side Edge secret only
APP_ALLOWED_ORIGINS=https://arrive-alive-virid.vercel.app,https://arrivealive.app,https://cp.arrivealive.app
APP_SESSION_TTL_DAYS=30                   # optional, clamped to 1-90
OPENAI_API_KEY=...                        # optional; server-side summaries only
OPENAI_SUMMARY_MODEL=gpt-5-mini           # optional
SAFETY_SCHEDULER_SECRET=...               # required by the rollup scheduler route
```

Vercel:

```text
SUPABASE_APP_API_URL=https://PROJECT.supabase.co/functions/v1/app-api
```

Flutter (public endpoint, never a service key; this production endpoint is now
the source default and can still be overridden):

```sh
flutter run --dart-define=API_BASE_URL=https://otbbyvdhqbnjvswrwzft.supabase.co/functions/v1/app-api
```

Web direct authentication uses the public Edge Function URL in the `arrive-alive-api-url` meta tag in `index.html`. The production Vercel hostname, `arrivealive.app` main-app hostname, and `cp.arrivealive.app` control-panel hostname are safe default CORS origins; configure `APP_ALLOWED_ORIGINS` when adding more production hostnames. The URL is an endpoint, not a secret. Do not place `SUPABASE_SERVICE_ROLE_KEY`, an anon key, or an administrator credential in web/Flutter code.

## Setup sequence (operator-run, not performed here)

1. Review and apply the SQL migration to the intended Supabase project.
2. Configure the Edge Function secrets above and deploy `app-api` with JWT verification disabled as declared in `supabase/config.toml`. The function uses its own opaque bearer sessions.
3. Register the initial administrator through the normal API, then promote that specific row out-of-band in the SQL editor: `update public.users set role='admin' where phone='NORMALIZED_PHONE';`. Never add a hard-coded admin PIN to client code.
4. Configure allowed production/preview origins exactly. An empty allowlist rejects browser preflights; non-browser/mobile requests without an Origin header still work.
5. Set only the public Edge URL in Vercel/web/Flutter and run the contract/E2E checks.
6. Add an upstream rate limiter/WAF (for example at the hosting gateway) for login, reset, registration, incident creation, and confirmations; monitor `audit_log` and session volume.

## Authentication and security properties

Registration and PIN reset use PBKDF2-HMAC-SHA-256 with a random per-credential salt and 210,000 iterations. Opaque 256-bit session tokens are returned once; only their SHA-256 digest is stored. Reset revokes all sessions. Session lookup writes `last_seen_at` at most every five minutes to avoid one database write per request. Admin authorization is always checked again in the Edge Function; UI gating is not trusted. The web keeps its token only in `sessionStorage`. Flutter currently uses `SharedPreferences` because that is the existing persistence dependency; a production mobile release should migrate the token to Keychain/Keystore-backed secure storage and revoke existing sessions during that migration. Both clients still require normal XSS/device-compromise protections.

PINs have low entropy even when PBKDF2-protected. Four-digit PINs are retained for current client compatibility, so gateway-level per-IP and per-account throttling, alerting, and preferably a stronger second factor are required before high-risk use. The reset secret is also knowledge-based and should eventually be replaced by verified SMS/email recovery. The function adds a small failed-login delay but does not claim that per-instance memory is a durable rate limiter.

Profile photos are private, limited to JPEG/PNG/WebP and 2 MB, stored under a per-user prefix, and returned with a one-hour signed URL. Flutter currently retains its local image for offline display; the upload route is ready for a later multipart client integration.

## Main routes

Public before custom session authentication: `GET /health`, `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/reset-pin`, and read-only `GET /api/public-reports/:slug`.

Public reads are limited to slug-addressed sanitized agency-report snapshots, the sanitized active-only `/api/public-hazards` feed, and `/api/public-speed-limits`. The hazard feed exposes only an opaque/stable ID, bounded type and label, cleaned description, validated rounded coordinates, bounded confirmation counts, and timestamps; it omits reporter, driver, and vehicle identity. The speed-limit feed exposes only allowlisted vehicle modes, bounded kilometre-per-hour limits, and update timestamps so first-time guests receive the current administrator values. Authenticated routes include profile/logout, `/api/sync`, journeys and atomic safety completion, Speed Board, agency rollups, speed reports, notifications, incident creation/confirmation, violations, agencies, and speed limits. Administrative routes include users, stats/overview, violation moderation/reports, speed-limit settings, rollup execution, public report publishing, and `/api/admin/sync-health`. Ownership is enforced on personal journeys, samples, and violations.

## Deterministic safety intelligence

Apply `20260826223000_safety_intelligence.sql` after the durable-backend
migrations. It creates the speed-sample table and adds violation episodes,
independent reports, evidence correlations, journey assessments, Speed Board
entries, agency rollups, notifications, RLS, and the atomic completion RPC.
`20260826222000_speed_safety_evidence.sql` is an intentionally empty
compatibility placeholder and adds no overlapping schema.

The Edge Function always loads the current admin-managed limit for the journey
mode. It rejects implausible samples (over 220 km/h), invalid timestamps, and
location accuracy worse than 65 metres while retaining each rejection reason.
A violation episode requires speed above `limit + 2 km/h` for at least three
accepted samples or two seconds; gaps over ten seconds split episodes.
Completing a journey writes samples, episodes, the assessment, the journey
status, an audit event, and one `violator` or `within_limit` Speed Board entry
through an idempotent transaction.

Independent reports are unique per reporter, agency, vehicle, and UTC-hour
bucket. Correlation anchors telemetry at weight `1.0`, weights each unique
reporter at `0.35`, caps total report influence, limits each report to ±25
km/h of telemetry, and applies median/MAD winsorization. Outlier and capped
counts are recorded rather than discarded silently.

Agency rollups are computed daily, weekly, and monthly. A label requires at
least 10 journeys, five distinct users, and 3,600 seconds of telemetry.
`avoid` additionally requires at least three violating journeys and a 20%
violation-journey rate. `trusted` requires a rate no greater than 5%.
Everything else is `insufficient_evidence`. Every row stores the thresholds,
confidence, and reasons used.

OpenAI is optional and only writes display prose through the server-side
Responses API. Its input is an allowlist of aggregate numeric facts with no
names, phones, plates, birth years, precise locations, or other
personal/protected attributes. The prompt forbids deciding or modifying the
status. Missing credentials produce `ai_status=fallback`; unavailable or
invalid responses produce `ai_status=failed`; both use the deterministic
summary. No successful OpenAI call is assumed.

Safety routes:

- `POST /api/journeys/complete-safety` — authenticated, idempotent completion
  and automatic board publication.
- `GET /api/speed-board` and `GET /api/agency-safety-rollups` — registered-user
  evidence feeds.
- `POST /api/speed-reports` — deduplicated independent observations and
  correlation.
- `GET /api/notifications` and
  `PATCH /api/notifications/:uuid/read` — deduplicated personal feed.
- `POST /api/admin/safety-rollups` — administrator-triggered computation.
- `POST /api/safety/rollups/run` — scheduler-only route using
  `Authorization: Bearer $SAFETY_SCHEDULER_SECRET`.

Schedule the last route daily. Re-runs are safe because rollups upsert by
agency/period/start date and notifications have unique event keys.

## Local checks

```sh
node --check api/sync.js
node --check web-repository.js
node tests/repository-check.js
node tests/sync-api-check.js
node tests/hazards-api-check.js
node tests/hazard-alerts-check.js
node tests/public-speed-limits-api-check.js
deno test --no-config supabase/functions/app-api/helpers_test.ts

dart format --set-exit-if-changed flutter_app/lib flutter_app/test
flutter analyze flutter_app
flutter test flutter_app
```

The final three commands require Flutter/Dart to be installed. Full Edge type-checking also requires resolving the pinned npm Supabase client import; avoid doing that in an offline/no-network review environment.

## Public agency report deployment

Agency sharing publishes an immutable, sanitized snapshot to
`public.public_agency_reports`. The payload contains agency identity, aggregate
safety metrics, vehicle-type breakdowns, and report rows. It excludes user
phones, PINs, session tokens, profiles, driver names, and precise journey
coordinates.

Operator steps:

1. Apply `supabase/migrations/20260826213000_public_agency_reports.sql`.
2. Deploy the updated `supabase/functions/app-api` Edge Function.
3. Keep `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` configured and ensure
   `APP_ALLOWED_ORIGINS` includes `https://cp.arrivealive.app`.
4. Confirm the `arrive-alive-api-url` meta value points to this function.
5. Verify an administrator can `POST /api/public-reports` with a bearer token
   and an unauthenticated visitor can `GET /api/public-reports/:slug`.

No external deployment was performed. Until the migration and Edge Function
are deployed together, publishing fails visibly and the client does not create
a misleading local-only public URL.
