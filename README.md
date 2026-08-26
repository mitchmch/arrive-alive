# Arrive Alive

Arrive Alive is a responsive road-safety web application for journey recording, live GPS speed monitoring, community hazard reporting, and driver safety feedback. The web client remains a no-build application and uses Mapbox GL first, with MapLibre/OpenStreetMap fallbacks.

## Features

- Registration, PIN login, secret-word PIN recovery, guest access, and admin routing
- Journey setup for car, bus, lorry, and motorbike travel
- Live GPS motion detection and synchronized digital speed recording
- Responsive journey interface for phones, tablets, laptops, and desktops
- Automatic light map during the day and dark map at night
- Manual light and dark theme override
- Realtime-style hazard reporting with pinned locations
- Proximity warnings and “Still there” or “Not there” hazard confirmation
- Journey stopping, restarting, completion, history, scoreboard, and reporting flows
- Automatic, deterministic journey safety assessment and Speed Board publishing
- Evidence-thresholded daily, weekly, and monthly agency safety status
- Deduplicated registered-user trusted/avoid notifications
- Profile photos with client-side type/size validation and accessible preview
- Per-account journey history
- Role-gated administration for users, reports, agencies, speed limits, and sync health
- API-first repository synchronization with explicit local fallback

## Project structure

```text
arrive-alive/
├── api/
│   ├── mapbox-config.js # Public Mapbox runtime configuration
│   └── sync.js          # Proxy to the durable Supabase app API
├── supabase/            # SQL migration and app-api Edge Function
├── tests/               # Static, repository, and endpoint checks
├── index.html           # Application markup, styles, and JavaScript
├── web-repository.js    # Shared API-first data repository
├── logo.jpg             # Arrive Alive brand asset
└── README.md            # Setup and deployment documentation
```

This version has no build step. It can be served from a static host; when `/api/sync` is unavailable it safely falls back to browser-local storage and then in-memory state.

## Data architecture and persistence

`web-repository.js` owns the web data contract for public user records, profiles, journeys, incidents, agencies, and speed limits. Every record has an ID, version, creation timestamp, and update timestamp. Snapshot merges use the newest `updatedAt` value, with `version` as the tie-breaker. Writes are local-first and the client then attempts `/api/sync`; the current status is visible in Administration.

`api/sync.js` now proxies only to the configured durable Supabase Edge API. It keeps no process-memory snapshot and returns HTTP 503 when `SUPABASE_APP_API_URL` is absent. The Edge API supplies server-verified opaque sessions, ownership/admin authorization, Postgres persistence, idempotency, audit records, and private profile-photo storage. See `BACKEND.md` for required environment variables and the operator-run setup sequence. When the web API meta tag is empty, authentication remains an explicitly local-only demo and no hard-coded administrator path should be used in production.

## Requirements

- A modern browser with JavaScript enabled
- Node.js 18 or newer for the recommended local server and deployment commands
- Internet access for MapLibre and CARTO map assets
- HTTPS in production so browser geolocation works reliably

The application should be tested on a real GPS-capable phone before production use. Desktop browsers may provide low-accuracy, delayed, or simulated location readings.

## Local setup

### Clone the repository

```bash
git clone https://github.com/mitchmch/arrive-alive.git
cd arrive-alive
```

If the repository is private, the GitHub account cloning it must have access.

### Start the local server

Run:

```bash
npx serve . -l 3000 --no-clipboard --single
```

Then open:

```text
http://127.0.0.1:3000
```

Do not open `index.html` directly with a `file://` URL. Map resources, browser permissions, and geolocation behave more reliably through an HTTP server.

## Map configuration

The app uses bundled Mapbox GL JS as its primary map renderer and Mapbox Navigation styles as its default maps:

- `mapbox://styles/mapbox/navigation-day-v1`
- `mapbox://styles/mapbox/navigation-night-v1`

MapLibre GL and OpenStreetMap remain bundled as an automatic last-resort fallback. A transient Mapbox style failure is retried once before the app switches to OpenStreetMap and then to a limited route canvas. Returning to the journey screen, restoring the tab, retrying, or reloading starts with Mapbox again.

### Mapbox access token

Create a Mapbox public access token beginning with `pk.`. Give it the public read scopes required for maps, including `styles:read` and `fonts:read`. Never use a secret `sk.` token in the browser.

For Vercel, add the token as an environment variable:

```text
MAPBOX_ACCESS_TOKEN=pk.your_public_token
```

Add it to Production, Preview, and Development, then redeploy the project. The serverless endpoint at `api/mapbox-config.js` supplies the public browser token at runtime. No Mapbox token is committed to the browser or Flutter source.

If the token has URL restrictions, include every hostname from which the app is loaded, for example:

```text
https://arrive-alive.vercel.app/*
https://arrivealive.pplx.app/*
http://localhost:3000/*
http://127.0.0.1:3000/*
```

Use the exact Vercel production and preview domains assigned to the project. A missing allowed domain commonly appears as a blank or permanently loading map on deployed mobile browsers.

For local Mapbox development, use Vercel's local runtime so the serverless configuration endpoint and environment variable are available:

```bash
npx vercel dev
```

Running `npx serve` still works for interface development, but Mapbox requires a server that provides `/api/mapbox-config`. Use Vercel development or a compatible local endpoint for full map testing.

### Day and night maps

The application selects its map from the device’s local time:

- Light map from 06:00 through 17:59
- Dark map from 18:00 through 05:59

The theme is checked automatically while the app remains open. Using a visible theme control changes the session to a manual override.

Map styles are configured in `getMapStyle()`:

```javascript
return mapTheme === 'light'
  ? 'mapbox://styles/mapbox/navigation-day-v1'
  : 'mapbox://styles/mapbox/navigation-night-v1';
```

Route and hazard layers are restored after every map-style change.

## Geolocation and speed recording

The digital speedometer must only respond to real device movement after the user starts a journey.

For reliable results:

- Test production deployments over HTTPS.
- Grant precise location permission when prompted.
- Enable the device’s location services.
- Test outdoors or in an environment with a reliable GPS signal.
- Keep battery-saving restrictions disabled during the test.
- Use a real mobile device for final accuracy validation.

Setting a destination or opening the journey screen must not create speed. A stationary vehicle should remain at `0 KM/H`, even after the Start button is selected. Speed, maximum speed, distance, duration, and violations should remain synchronized throughout the journey.

## Testing

### Static checks

Check repository formatting:

```bash
git diff --check
```

Extract the inline JavaScript and validate its syntax:

```bash
python - <<'PY'
from pathlib import Path
import re

html = Path("index.html").read_text()
scripts = re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>", html, re.S)
Path("/tmp/arrive_alive_inline.js").write_text("\n".join(scripts))
PY

node --check /tmp/arrive_alive_inline.js
node --check web-repository.js
node --check api/sync.js
node tests/static-web-check.js
node tests/repository-check.js
node tests/sync-api-check.js
node tests/backend-contract-check.js
```

The safety backend deliberately keeps classification separate from generated
text. Admin speed limits and fixed rules determine `trusted`, `avoid`, or
`insufficient_evidence`; OpenAI is optional, server-side only, and can only
rewrite an allowlisted aggregate summary. See `BACKEND.md` for thresholds,
fallback behavior, scheduler authentication, migration order, and API routes.

### Authentication E2E checklist

Verify these flows in a clean browser session:

1. Sign in before registering and confirm the “No account found” error.
2. Register with name, phone, PIN, confirmed PIN, and secret word.
3. Confirm successful registration and redirection to sign in.
4. Attempt login with an incorrect PIN and confirm the specific error.
5. Login with the correct PIN and confirm navigation to the journey wizard.
6. Reset the PIN with an incorrect secret word and confirm it is rejected.
7. Reset with the correct secret word and confirm the new PIN works.
8. Confirm admin login routes to the protected Administration page.
9. Confirm guest access routes to the journey wizard.

### Journey and speed E2E checklist

1. Select a travel mode and complete every wizard step.
2. Set a destination and verify the speed remains `0 KM/H`.
3. Start the journey while stationary and verify the speed remains `0 KM/H`.
4. Move with a real GPS-capable device and verify speed begins responding.
5. Compare the digital speedometer with the recorded speed, maximum speed, distance, and violation data.
6. Stop the journey and confirm speed returns to zero and recording pauses.
7. Restart and confirm recording resumes without losing prior journey data.
8. End the journey and confirm the completion screen renders correctly.

### Map and hazard E2E checklist

1. Verify the light map appears during daytime hours.
2. Verify the dark map appears during nighttime hours.
3. Toggle light → dark → light and confirm the route remains visible.
4. Report a road hazard and pin it to a map location.
5. Confirm the hazard marker appears without stopping the active journey.
6. Approach the hazard while moving and confirm the advance warning appears once.
7. Select “Still there” and confirm the hazard remains active.
8. Select “Not there” and confirm the marker is removed.
9. Repeat the checks at phone and desktop viewport sizes.

## Deployment

### Vercel

The repository can be deployed directly because `index.html` is at its root.

Install or run the Vercel CLI:

```bash
npx vercel
```

Follow the prompts and keep the project root as the deployment directory. To deploy the current version to production:

```bash
npx vercel --prod
```

After deployment:

1. Open the HTTPS deployment.
2. Grant precise location permission.
3. Run the authentication, speed, map-theme, and hazard E2E checklists.

### Vercel Git integration

The repository can also be imported from GitHub in Vercel:

1. Create a new Vercel project.
2. Import `mitchmch/arrive-alive`.
3. Select the default static configuration.
4. Leave the build command empty.
5. Set the output directory to the repository root.
6. Deploy and test the resulting HTTPS hostname on a physical phone.

Future pushes to the configured production branch can then trigger automatic deployments.

### Other static hosts

GitHub Pages, Cloudflare Pages, Netlify, Firebase Hosting, and equivalent static hosts can serve the same files. Ensure the service publishes the repository root and provides HTTPS.

## Updating the application

```bash
git checkout master
git pull origin master
# Make and test changes
git add index.html logo.jpg README.md
git commit -m "Describe the change"
git push origin master
```

Run the relevant E2E flows before every production deployment.

## Troubleshooting

### The map is blank

- Confirm MapLibre GL JS and its stylesheet can load from `unpkg.com`.
- Confirm CARTO style, font, sprite, and tile requests can load from `basemaps.cartocdn.com`.
- Check whether a content blocker, restrictive network, VPN, or browser privacy setting is blocking map resources.
- Use the on-screen retry control after connectivity returns.

### Location or speed does not update

- Use HTTPS or localhost.
- Grant precise location permission.
- Confirm location services are enabled.
- Test on a physical phone with a reliable GPS signal.
- Start the journey before moving.

### Speed changes while stationary

- Confirm the browser is not using a mocked location feed.
- Test outdoors and wait for GPS accuracy to stabilize.
- Check that only live geolocation readings update journey speed.
- Do not treat destination selection, route animation, or map movement as vehicle movement.

### Route disappears after switching themes

Reload the latest version of the application and clear any stale site cache. The current implementation restores route and hazard layers after MapLibre completes each style transition.

## Security notes

- Never commit API secrets, passwords, private keys, or service-account credentials.
- The repository attempts the Vercel sync function first and safely retains data locally when it is unavailable, but the included function uses ephemeral process memory only.
- Browser-local data is scoped to that browser/profile and may be cleared by the user or browser.
- The demo auth flow is client-side and is not a security boundary. Production requires server-verified sessions and authorization.
