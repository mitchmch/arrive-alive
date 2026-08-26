# Arrive Alive Flutter app

## First-launch guide sound

The guide uses Flutter's soft `SystemSoundType.click` for step transitions.
The included `assets/sounds/guide-bubble.wav` remains declared in the asset
manifest for future native playback, but the app intentionally does not add an
audio package solely for one short UI cue. This keeps first launch reliable and
avoids another platform plugin dependency.

## Backend and synchronization

The default build is intentionally local-only. Supply a REST backend explicitly:

```sh
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

Without `API_BASE_URL`, writes remain in the durable SQLite queue and the admin
sync-health section says that no upload has occurred. Queued writes use stable
UUIDs, `updatedAt`, `version`, dependency ordering, exponential retry state,
retained terminal errors, and an `Idempotency-Key` request header. The backend
must preserve client stable IDs or idempotency keys and return an integer `id`
for created journeys and violations.

## Profile photos

`image_picker` is the only added media dependency. It selects a bounded,
quality-reduced gallery image. The app copies that file into its documents
directory and persists only the local path with the profile. This is device
storage, not a claim of cloud upload; a backend photo-upload contract can be
added later without storing image bytes in preferences or SQLite.

### Durable Supabase API

For the included backend, `API_BASE_URL` is the public Edge Function endpoint (ending in `/functions/v1/app-api`), not the Supabase project root. The app persists the opaque per-user token returned by register/login and sends it as `Authorization: Bearer ...`; it never embeds a service-role or anon key. When a backend is configured, authentication failures are not silently downgraded to the local account store. See `../BACKEND.md` for migration, CORS, bootstrap, and security requirements.
