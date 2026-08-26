const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const flutterConfig = fs.readFileSync(
  path.join(root, 'flutter_app', 'lib', 'core', 'config.dart'),
  'utf8',
);

function matchOne(source, pattern, message) {
  const match = source.match(pattern);
  assert.ok(match, message);
  return match[1];
}

assert.match(html, /--aa-amber:#4361ee;/, 'The original Arrive Alive blue must remain the light primary');
assert.match(html, /--aa-bg:#F3F6FF;/, 'Light surfaces must use the blue-tinted palette');
assert.match(html, /--aa-bg:#071126;/, 'Dark surfaces must use the deep navy palette');
assert.doesNotMatch(html, /\.btn-primary\{background:#fff/, 'Primary buttons must not revert to white');

const accessHero = matchOne(
  html,
  /<div class="access-hero">([\s\S]*?)<\/div>/,
  'The landing hero must exist',
);
assert.match(accessHero, /Drive aware\.<br>Arrive safe\./, 'The landing headline must be preserved');
assert.doesNotMatch(accessHero, /<p\b/, 'The landing description must be removed');
assert.doesNotMatch(html, /Road awareness ready/, 'The under-title route status must be removed');

for (const icon of ['play', 'navigation', 'hazard', 'report']) {
  assert.match(
    html,
    new RegExp(`${icon}:'<`),
    `The ${icon} guide step must have an outline SVG`,
  );
}
assert.match(html, /guide-progress-step/, 'Guide progress must use icons');
assert.match(html, /Step \$\{index\+1\}: \$\{item\.title\}/, 'Guide progress must retain accessible labels');
assert.match(
  html,
  /<span class="sr-only" id="guideStepLabel"[^>]*>Step 1 of 4<\/span>/,
  'The numeric step label must remain available to assistive technology only',
);
assert.doesNotMatch(html, /id="guideStepNumber"/, 'The numeric guide card indicator must be removed');

assert.doesNotMatch(html, /pk\.eyJ[A-Za-z0-9._-]+/, 'The web bundle must not embed a Mapbox token');
assert.match(
  flutterConfig,
  /'MAPBOX_ACCESS_TOKEN',\s*defaultValue:\s*''/,
  'Flutter must receive its public Mapbox token at build time',
);
assert.doesNotMatch(html, /(?:^|[^a-z])sk\.[A-Za-z0-9_-]+/, 'No secret Mapbox token may be exposed');
assert.match(
  html,
  /fetch\('\/api\/mapbox-config',\{cache:'no-store'\}\)/,
  'Vercel runtime Mapbox configuration must remain preferred',
);
assert.match(html, /MAPBOX_STYLE_RETRY_LIMIT=1/, 'Mapbox styles must retry before fallback');
assert.match(
  html,
  /if\(mapProvider!=='mapbox'\|\|mapFallbackStage!==0\)restoreMapboxDefault\(\)/,
  'Returning to a visible journey must restore Mapbox as the default',
);
assert.match(html, /loadMapboxConfig\(\);\s*if\(window\.speechSynthesis\)/, 'Reload must prepare Mapbox');

assert.match(html, /id="screen-profile"[^>]*data-testid="screen-profile"/, 'A stable protected profile screen must exist');
assert.match(html, /const screens=\[[^\]]*'profile'[^\]]*\]/, 'Profile must participate in screen navigation and history');
assert.match(html, /\['profile','score'\]\.includes\(name\)&&!isRegisteredAccessAllowed\(\)/, 'Profile and Speed Board must share the registered access guard');
assert.match(html, /data-testid="button-profile-wizard"/, 'The wizard must expose the authenticated Profile entry');
assert.match(html, /data-testid="button-profile-journey"/, 'The journey map must expose the authenticated Profile entry');
assert.doesNotMatch(html, /data-testid="button-scoreboard-(?:wizard|journey)"/, 'Direct Scoreboard entries must be replaced by Profile');
assert.match(html, /data-testid="button-save-profile"/, 'Profile save must have a stable test hook');
assert.match(html, /data-testid="button-profile-guide"/, 'Profile guide action must have a stable test hook');
assert.match(html, /data-testid="button-profile-speed-board"/, 'Profile Speed Board action must have a stable test hook');
assert.match(html, /users\[phone\]=\{\.\.\.storedUser,name,phone,role:storedUser\.role\|\|'user'\}/, 'Registered profile edits must update the user record');
assert.match(html, /users\[session\.phone\]=\{\.\.\.storedAdmin,name,phone:session\.phone,role:'admin'\}/, 'Administrator display name edits must preserve the admin identity');
assert.match(html, /saveAAUsers\(users\);\s*setAASession/, 'Profile saves must update aaUsers and aaSession together');
assert.match(html, /setAASession\(\{\.\.\.session,name,phone,role:session\.role\}\)/, 'Profile edits must preserve the authenticated role');
assert.match(html, /journey\.driver=name;/, 'Profile edits must update the current journey driver');
assert.match(html, /session\.role==='admin'\?session\.phone:requestedPhone/, 'Administrator identity must remain fixed');
assert.match(html, /accept="image\/jpeg,image\/png,image\/webp"/, 'Profile photos must use an explicit safe image allowlist');
assert.match(html, /file\.size>1024\*1024/, 'Profile photos must be limited to 1 MB');
assert.match(html, /id="journeyHistory"/, 'Profile must include personal journey history');
assert.match(html, /ownerId:session\?`user-\$\{session\.phone\}`:null/, 'Saved journeys must carry an owner ID');

assert.match(html, /id="screen-admin"[^>]*data-testid="screen-admin"/, 'A stable admin screen must exist');
assert.match(html, /name==='admin'&&!isAdminAccessAllowed\(\)/, 'Admin navigation must enforce the admin role');
for (const heading of ['Overview', 'User management', 'Incident & report moderation', 'Speed Board & trusted agencies', 'Synchronization health']) {
  assert.match(html, new RegExp(`>${heading}<`), `Admin must include the ${heading} section`);
}
assert.match(html, /src="web-repository\.js"/, 'The shared repository module must load before the app');
assert.match(html, /endpoint:APP_API_URL\?`\$\{APP_API_URL\}\/api\/sync`:'\/api\/sync'/, 'The client must use the configured durable API with same-origin proxy fallback');
assert.match(html, /tokenProvider:\(\)=>getAASession\(\)\?\.token\|\|null/, 'Sync must authenticate with the opaque user token');
assert.match(html, /API connected · not durable/, 'The UI must not imply that the current API is durable');

assert.match(html, /data-testid="screen-speed-board"/, 'Speed Board must have a stable screen hook');
assert.match(html, /data-testid="tab-trusted-agencies"[^>]*>Trusted agencies</, 'Trusted agencies tab must be present');
assert.match(html, /data-testid="tab-speeding-vehicles"[^>]*>Speeding vehicles</, 'Speeding vehicles tab must be present');
assert.match(html, /\?'\u2713 Trusted':'Safety score'/, '100-score agencies must be clearly marked as trusted');
for (const label of ['Measured', 'Limit', 'Over by', 'Agency:', 'Route:', 'Time:']) {
  assert.match(html, new RegExp(`>${label}<`), `Speeding vehicle rows must show ${label}`);
}
assert.doesNotMatch(html, />Scoreboard</, 'User-facing Scoreboard labels must be renamed');

console.log('Static web checks passed.');
