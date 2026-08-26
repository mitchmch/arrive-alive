# Arrive Alive

Arrive Alive is a responsive road-safety web application for journey recording, live GPS speed monitoring, community hazard reporting, and driver safety feedback. The application runs as a static web app and uses Mapbox GL JS for its map experience.

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

## Project structure

```text
arrive_alive_demo/
├── index.html   # Application markup, styles, and JavaScript
├── logo.jpg     # Arrive Alive brand asset
└── README.md    # Setup and deployment documentation
```

This version has no build step or backend dependency. It can be served from any static web host.

## Requirements

- A modern browser with JavaScript enabled
- Node.js 18 or newer for the recommended local server and deployment commands
- A Mapbox account and public access token for Mapbox-hosted maps
- HTTPS in production so browser geolocation works reliably

The application should be tested on a real GPS-capable phone before production use. Desktop browsers may provide low-accuracy, delayed, or simulated location readings.

## Local setup

### Clone the repository

```bash
git clone https://github.com/GBFBank/arrive_alive_demo.git
cd arrive_alive_demo
```

The repository is private, so the GitHub account cloning it must have access.

### Configure Mapbox

Open `index.html` and find the active `MAPBOX_TOKEN` declaration:

```javascript
const MAPBOX_TOKEN = 'YOUR_PUBLIC_MAPBOX_TOKEN';
```

Replace the value with a Mapbox public token beginning with `pk.`. Never place a Mapbox secret token beginning with `sk.` in browser code.

If `MAPBOX_TOKEN` is left empty, the application falls back to public CARTO light and dark map styles:

```javascript
const MAPBOX_TOKEN = '';
```

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

## Mapbox configuration

### Create a public token

1. Sign in to Mapbox.
2. Open the access-token settings.
3. Create a public token for the web application.
4. Enable only the public scopes required to read Mapbox styles, fonts, sprites, and tiles.
5. Add URL restrictions for the domains that will host the app.

Recommended allowed URLs include:

```text
http://127.0.0.1:3000/*
http://localhost:3000/*
https://your-project.vercel.app/*
https://your-production-domain.example/*
```

Add every Vercel preview or production hostname that needs to load the map. A missing hostname restriction commonly causes a blank map or HTTP 401/403 responses.

### Day and night maps

The application selects its map from the device’s local time:

- Light map from 06:00 through 17:59
- Dark map from 18:00 through 05:59

The theme is checked automatically while the app remains open. Using a visible theme control changes the session to a manual override.

Map styles are configured in `getMapStyle()`:

```javascript
return mapTheme === 'light'
  ? 'mapbox://styles/mapbox/light-v11'
  : 'mapbox://styles/mapbox/dark-v11';
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
```

### Authentication E2E checklist

Verify these flows in a clean browser session:

1. Sign in before registering and confirm the “No account found” error.
2. Register with name, phone, PIN, confirmed PIN, and secret word.
3. Confirm successful registration and redirection to sign in.
4. Attempt login with an incorrect PIN and confirm the specific error.
5. Login with the correct PIN and confirm navigation to the journey wizard.
6. Reset the PIN with an incorrect secret word and confirm it is rejected.
7. Reset with the correct secret word and confirm the new PIN works.
8. Confirm admin login routes to the scoreboard.
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

1. Add the Vercel hostname to the Mapbox token’s allowed URLs.
2. Open the HTTPS deployment.
3. Grant precise location permission.
4. Run the authentication, speed, map-theme, and hazard E2E checklists.

### Vercel Git integration

The repository can also be imported from GitHub in Vercel:

1. Create a new Vercel project.
2. Import `GBFBank/arrive_alive_demo`.
3. Select the default static configuration.
4. Leave the build command empty.
5. Set the output directory to the repository root.
6. Deploy and add the resulting hostname to the Mapbox token restrictions.

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

- Check the browser console for Mapbox 401 or 403 responses.
- Confirm the token starts with `pk.`.
- Confirm the deployment hostname is allowed by the token.
- Confirm Mapbox GL JS and its stylesheet can load from `api.mapbox.com`.

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

Reload the latest version of the application and clear any stale site cache. The current implementation restores route and hazard layers after Mapbox completes each style transition.

## Security notes

- Browser-side Mapbox tokens are public by design. Protect them with minimal scopes and URL restrictions.
- Never commit Mapbox secret tokens, API secrets, passwords, or private keys.
- The current static demo stores application data in browser-managed client state. A production multi-user release should use authenticated backend APIs and a durable database for accounts, incidents, confirmations, journeys, and audit records.

