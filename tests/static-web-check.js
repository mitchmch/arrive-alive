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

for (const icon of ['play', 'speedometer', 'navigation', 'hazard', 'alert', 'confirm', 'breach', 'report', 'profile']) {
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
  /<span class="sr-only" id="guideStepLabel"[^>]*>Step 1 of 9<\/span>/,
  'The numeric step label must remain available to assistive technology only',
);
assert.doesNotMatch(html, /id="guideStepNumber"/, 'The numeric guide card indicator must be removed');
for (const guideCopy of ['administrator-synced limit', 'speedometer', 'African voice', 'hazard triangle', '800 m', '500 m', 'Still there or Not there', 'bottom-right Report button', 'person icon']) {
  assert.ok(html.includes(guideCopy), `The expanded guide must explain ${guideCopy}`);
}
assert.match(html, /style="--guide-color:\$\{item\.color\}"/, 'Each guide icon must retain its feature colour');

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
assert.match(html, /JOURNEY_PREF_STORAGE_KEY='arrive-alive-journey-preferences-v1'/, 'Journey mode preferences must persist safely');
assert.match(html, /PUBLIC_SPEED_LIMIT_CACHE_KEY='arrive-alive-public-speed-limits-v1'/, 'Guest speed limits must have a persistent cache');
assert.match(html, /function sanitizeSpeedLimits\(items\)/, 'Guest speed-limit payloads must be validated');
assert.match(html, /async function startGuest\(\)\{\s*await \(publicSpeedLimitsPromise\|\|loadPublicSpeedLimits\(\)\);/, 'A first-time guest must wait for the public limits before opening setup');
assert.match(html, /APP_API_URL\?`\$\{APP_API_URL\}\/api\/public-speed-limits`:'\/api\/public-speed-limits'/, 'Guest limits must use the public backend route with same-origin fallback');
assert.match(html, /persistPublicSpeedLimitCache\(limits\)/, 'Fresh public speed limits must be cached');
assert.match(html, /Limit \$\{getAdminSpeedLimit\(m\.id\)\} km\/h/, 'Wizard mode cards must use admin-synced limits');
assert.match(html, /if\(currentScreen==='journey'\|\|journeyActive\|\|recording\)return;/, 'Sync refreshes must not change an opened journey limit');
assert.match(html, /function startJourney\(\)\{\s*\/\/[\s\S]*?journey\.limit=getAdminSpeedLimit\(journey\.mode\);/, 'A journey must freeze the current mode limit when opened');
assert.match(html, /hazardAlertTracker=ArriveAliveHazardAlerts\.createTracker\(\[800,500\]\)/, 'Hazard alerts must track 800 m and 500 m stages');
assert.match(html, /buzzer\(\);\s*vibrate\(\);\s*speak\(/, 'Hazard alerts must buzz, vibrate and speak');
assert.match(html, /loadPublicHazards\(\)/, 'Guests must load sanitized active hazards');
assert.match(html, /publicSpeedLimitsPromise=loadPublicSpeedLimits\(\)/, 'Public speed limits must refresh at startup');
assert.match(html, /Sign in to confirm community hazards/, 'Remote hazard writes must require authentication');

assert.match(html, /id="screen-admin"[^>]*data-testid="screen-admin"/, 'A stable admin screen must exist');
assert.match(html, /name==='admin'&&!isAdminAccessAllowed\(\)/, 'Admin navigation must enforce the admin role');
for (const heading of ['Overview', 'User management', 'Incident & report moderation', 'Agencies', 'Vehicles', 'Speed limits', 'Synchronization health']) {
  assert.match(html, new RegExp(`>${heading}<`), `Admin must include the ${heading} section`);
}
assert.match(html, /grid-template-columns:240px minmax\(0,1fr\)/, 'Desktop admin must have a persistent left sidebar');
assert.match(html, /data-testid="admin-primary-scroll"/, 'Admin must expose one stable primary scroll region');
for (const nav of ['overview','users','reports','agencies','vehicles','speed-limits','sync-health']) {
  assert.match(html, new RegExp(`data-testid="nav-admin-${nav}"`), `Admin navigation must include ${nav}`);
}
assert.match(html, /data-testid="button-admin-mobile-profile"/, 'Mobile admin navigation must expose Profile');
assert.match(html, /data-testid="button-admin-mobile-sign-out"/, 'Mobile admin navigation must expose Sign out');
for (const mode of ['car','bus','lorry','motorbike']) {
  assert.match(html, new RegExp(`vehicle-section-\\$\\{mode\\}`), 'Vehicle sections must be generated for all supported modes');
}
assert.match(html, /data-testid="button-export-agency-pdf"/, 'Agency PDF export must have a stable hook');
assert.match(html, /author:'Perplexity Computer'/, 'PDF metadata must identify Perplexity Computer');
assert.match(html, /vendor\/jspdf\.umd\.min\.js/, 'PDF generation must use a local jsPDF bundle');
assert.match(html, /data-testid="button-share-agency-report"/, 'Public report sharing must have a stable hook');
assert.match(html, /#\/reports\/\$\{encodeURIComponent\(slug\)\}/, 'Public reports must use canonical hash routes');
assert.match(html, /function parseAppHash\(\)/, 'Canonical hash routing must parse deep links without clearing sessions');
assert.doesNotMatch(html, /window\.location\.pathname\+window\.location\.search/, 'Deep-link handling must not strip a valid route');
assert.match(html, /src="web-repository\.js"/, 'The shared repository module must load before the app');
assert.match(html, /endpoint:APP_API_URL\?`\$\{APP_API_URL\}\/api\/sync`:'\/api\/sync'/, 'The client must use the configured durable API with same-origin proxy fallback');
assert.match(html, /tokenProvider:\(\)=>getAASession\(\)\?\.token\|\|null/, 'Sync must authenticate with the opaque user token');
assert.match(html, /API connected · not durable/, 'The UI must not imply that the current API is durable');

assert.match(html, /data-testid="screen-speed-board"/, 'Speed Board must have a stable screen hook');
assert.match(html, /data-testid="tab-trusted-agencies"[^>]*>Trusted agencies</, 'Trusted agencies tab must be present');
assert.match(html, /data-testid="tab-speeding-vehicles"[^>]*>Speeding vehicles</, 'Speeding vehicles tab must be present');
assert.match(html, /Trusted':avoid\?'Avoid':'Insufficient evidence'/, 'Agency labels must use evidence statuses instead of inferred scores');
assert.match(html, /without minimum independent evidence remain unclassified/, 'Speed Board must explain the minimum evidence gate');
assert.match(html, /\/api\/journeys\/complete-safety/, 'Journey completion must call the deterministic safety endpoint');
assert.match(html, /speedKph:Math\.round\(liveSpeed\*10\)\/10/, 'Web telemetry must use the backend speedKph contract');
assert.match(html, /agencyId:journey\.agencyId/, 'Journey safety completion must preserve agency attribution');
assert.match(html, /entries\.filter\(item=>item\.resultType==='violator'\)/, 'The speeding tab must exclude compliant journeys');
assert.match(html, /\/api\/speed-reports/, 'Registered users must be able to submit corroborating speed evidence');
assert.match(html, /src="web-voice\.js"/, 'Cloud voice must use the tested browser controller');
assert.match(html, /src="web-speed-breach\.js"/, 'Speed breach state must use the tested controller');
assert.match(html, /data-testid="button-report-speed-breach"/, 'The map must expose the automatic speed-breach report button');
assert.match(html, /src="assets\/warning\.jpg"/, 'The speed-breach control must use the supplied warning icon');
assert.match(html, /\.speed-breach-fab\{[\s\S]*?left:14px;right:auto;/, 'The speed-breach control must be positioned at the bottom left');
assert.match(html, /\.speed-breach-fab\{[\s\S]*?width:48px;height:48px;/, 'The speed-breach control must match the other map controls');
assert.match(html, /\.speed-breach-fab img\{[\s\S]*?filter:grayscale\(1\)/, 'The warning icon must be grey while inactive');
assert.match(html, /\.speed-breach-fab\.is-breaching img\{filter:none;opacity:1\}/, 'The warning icon must use colour while active');
assert.match(html, /speedBreachController\.update\(violating\)/, 'Live telemetry must drive the speed-breach control');
assert.match(html, /speedBreachController\.reset\(\)/, 'Stopping a journey must reset the breach control and alarm');
assert.match(html, /cannot create or change a violation by itself/, 'The report form must explain the telemetry safeguard');
assert.match(html, /data-testid="button-agency-recompute"/, 'Administrators must recompute evidence rather than manually assigning trust');
assert.doesNotMatch(html, /function toggleAgencyTrusted/, 'Safety classifications must not be manually overridden in the client');
assert.match(html, /\/api\/notifications/, 'Registered-user safety notifications must be loaded');
for (const label of ['Measured', 'Limit', 'Over by', 'Agency:', 'Assessment:', 'Published:']) {
  assert.match(html, new RegExp(`>${label}<`), `Speeding vehicle rows must show ${label}`);
}
assert.doesNotMatch(html, />Scoreboard</, 'User-facing Scoreboard labels must be renamed');

console.log('Static web checks passed.');
