# Arrive Alive durable backend

This directory contains a production-oriented Supabase data plane. It was created without deploying, applying migrations, creating credentials, or calling an external service.

## Architecture

- `supabase/migrations/20260826190000_durable_backend.sql` creates normalized durable tables, indexes, version/timestamp metadata, idempotency state, a transactional incident-confirmation RPC, an audit log, and a private `profile-photos` bucket.
- Every application table has RLS enabled and no permissive `anon` or `authenticated` policies. Direct browser/mobile database access is intentionally denied. Only the `app-api` Edge Function uses the service role.
- `supabase/functions/app-api/index.ts` exposes the REST contract used by Flutter plus `/api/sync` snapshot pull/push/merge for the web repository.
- `api/sync.js` is a narrow Vercel proxy to `/api/sync`; it returns an honest 503 when `SUPABASE_APP_API_URL` is absent and never keeps process-memory data.

## Required environment variables

Supabase Edge Function secrets/runtime:

```text
SUPABASE_URL=https://PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...             # server-side Edge secret only
APP_ALLOWED_ORIGINS=https://arrive-alive-virid.vercel.app,https://cp.arrivealive.app
APP_SESSION_TTL_DAYS=30                   # optional, clamped to 1-90
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

Web direct authentication uses the public Edge Function URL in the `arrive-alive-api-url` meta tag in `index.html`. The production Vercel hostname and planned `cp.arrivealive.app` control-panel hostname are safe default CORS origins; configure `APP_ALLOWED_ORIGINS` when adding more production hostnames. The URL is an endpoint, not a secret. Do not place `SUPABASE_SERVICE_ROLE_KEY`, an anon key, or an administrator credential in web/Flutter code.

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

Public before custom session authentication: `GET /health`, `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/reset-pin`.

Authenticated: profile/logout, `/api/sync`, journeys, incidents/confirmation, violations, agencies, and speed limits. Administrative: users, stats/overview, violation moderation/reports, speed-limit settings, and `/api/admin/sync-health`. Ownership is enforced on personal journeys and violations. Public-looking data routes still require a valid app session to limit anonymous bulk access.

## Local checks

```sh
node --check api/sync.js
node --check web-repository.js
node tests/repository-check.js
node tests/sync-api-check.js
deno test --no-config supabase/functions/app-api/helpers_test.ts

dart format --set-exit-if-changed flutter_app/lib flutter_app/test
flutter analyze flutter_app
flutter test flutter_app
```

The final three commands require Flutter/Dart to be installed. Full Edge type-checking also requires resolving the pinned npm Supabase client import; avoid doing that in an offline/no-network review environment.
