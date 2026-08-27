# Arrive Alive — Flutter App (v3.0)

Road safety app for Cameroon. Monitor vehicle speeds in real-time, report violations, navigate with turn-by-turn directions, and view community hazard reports — all offline-first.

## What's New in v3.0

- **Mapbox Maps** as default map provider (Waze-style dark navigation, 3D camera with pitch & bearing)
- **Modern speedometer UI** — glassmorphic gauge with colored zones, needle, glow effect, status text
- **African cloud voice guidance** through the Arrive Alive voice API, with native flutter_tts fallback
- Falls back to Google Maps automatically if no Mapbox token is set

## What's New in v2.0

- **Turn-by-turn navigation** via Google Directions API (Cameroon road-optimized)
- **Background location tracking** with persistent notification
- **Offline-first** with local SQLite caching and automatic sync
- **Real-time community hazard map** with live incident pins

## Tech Stack

- Flutter + Dart
- Riverpod (state management)
- Mapbox Maps Flutter (default) + Google Maps Flutter (fallback)
- Google Directions API (routing)
- Geolocator (foreground + background GPS)
- Firebase Cloud Messaging (push notifications)
- SQLite (sqflite — offline-first local database)
- connectivity_plus (online/offline detection)
- flutter_tts (voice guidance)

## Store release guide

For production signing, release builds, testing tracks, App Store Connect,
privacy declarations, and submission steps, follow
[`STORE_DEPLOYMENT_GUIDE.md`](STORE_DEPLOYMENT_GUIDE.md). The guide is written
for this repository and covers both Google Play and Apple App Store delivery.

## Administrator report export

The administrator workspace keeps report delivery behind
`AdminReportService`. The default implementation uses Flutter's built-in
clipboard support for **Share report**, so it has no additional platform
dependency. **Export PDF** intentionally returns a clear unavailable state
until a product-specific PDF renderer is configured.

To enable native PDF export:

1. Add compatible `pdf`, `printing`, and (if direct sharing is required)
   `share_plus` versions to `pubspec.yaml`.
2. Implement `AdminReportService.exportAgencyPdf` by rendering
   `Agency.reportSummary` and its vehicle breakdown to bytes, then call
   `Printing.sharePdf`.
3. Override `adminReportServiceProvider` with that implementation at the app
   composition root.
4. Follow the packages' current Android `minSdk`, iOS deployment target,
   file-provider, and share-sheet setup, then test both physical platforms.

Keeping the plugin boundary outside the screen lets widget tests and platforms
without a native share sheet use the administrator workspace safely.

## Setup

### 1. Flutter Project

```bash
# Android and iOS platform folders are already included.
# Install dependencies from the folder containing pubspec.yaml.
flutter pub get
```

### 2. Mapbox Configuration (Default Map Provider)

Get a Mapbox access token from [Mapbox Account](https://account.mapbox.com/):

1. Create a free Mapbox account
2. Copy your **public token** (starts with `pk.`)
3. Create a **secret token** with `Downloads: Read` scope (needed for SDK download during build)
4. Add the secret token to `~/.gradle/gradle.properties`:
   ```properties
   MAPBOX_DOWNLOADS_TOKEN=your_secret_token_here
   ```
5. For iOS, add to `~/.netrc`:
   ```
   machine api.mapbox.com
   login your_mapbox_username
   password your_secret_token
   ```

### 3. Google Cloud Console (Fallback Map + Routing)

Enable these APIs in [Google Cloud Console](https://console.cloud.google.com/):

- **Directions API** (required for routing)
- **Maps SDK for Android** (fallback map)
- **Maps SDK for iOS** (fallback map)
- **Geocoding API**
- **Places API** (optional, for better destination search)

Create an API key and restrict it to your app's package name / bundle ID.

### 4. Run with API keys

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5000 \
  --dart-define=VOICE_API_URL=https://arrivealive.app/api/voice \
  --dart-define=MAPBOX_ACCESS_TOKEN=your_mapbox_pk_token \
  --dart-define=GOOGLE_MAPS_API_KEY=your_maps_key \
  --dart-define=GOOGLE_DIRECTIONS_API_KEY=your_directions_key
```

> If MAPBOX_ACCESS_TOKEN is empty, the app falls back to Google Maps automatically.
> You can also customize the Mapbox style with --dart-define=MAPBOX_STYLE_URI=mapbox://styles/mapbox/navigation-day-v1
> `VOICE_API_URL` is optional and defaults to `https://arrivealive.app/api/voice`.
> Voice-provider API keys belong on that server endpoint and must not be added to the app.

### 5. Android Configuration

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Location permissions -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

    <!-- Foreground service for background GPS -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

    <!-- Notifications (Android 13+) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <!-- Internet -->
    <uses-permission android:name="android.permission.INTERNET" />

    <application>
        <!-- Google Maps API key -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_GOOGLE_MAPS_API_KEY" />

        <!-- Firebase Messaging default notification channel -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="arrive_alive_alerts" />
    </application>
</manifest>
```

**Background location permission flow on Android:**
- The app first requests `ACCESS_FINE_LOCATION` (while in use).
- When the user starts a journey, the app requests `ACCESS_BACKGROUND_LOCATION` ("Allow all the time").
- A persistent foreground notification appears while recording, showing "Arrive Alive — Recording Journey".
- The notification cannot be dismissed while the journey is active.
- The user can stop recording from within the app to dismiss the notification.

### 6. iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<dict>
    <!-- Location usage descriptions -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Arrive Alive uses your location to monitor vehicle speed and detect violations for road safety.</string>

    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>Arrive Alive needs background location to continue monitoring speed even when your phone is locked, ensuring continuous safety recording during your journey.</string>

    <!-- Background modes -->
    <key>UIBackgroundModes</key>
    <array>
        <string>location</string>
        <string>fetch</string>
        <string>remote-notification</string>
    </array>
</dict>
```

Add the Google Maps API key to `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import GoogleMaps
import Firebase

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

Add to `ios/Podfile` (if not already present):

```ruby
target 'Runner' do
  use_frameworks!
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

### 7. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com/)
2. Add Android and iOS apps with your package name / bundle ID
3. Download `google-services.json` → `android/app/`
4. Download `GoogleService-Info.plist` → `ios/Runner/`
5. Enable Cloud Messaging in Firebase Console

Add to `android/app/build.gradle`:

```gradle
apply plugin: 'com.google.gms.google-services'
```

Add to `android/build.gradle`:

```gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}
```

## Features

### Turn-by-Turn Navigation

- Search for destinations anywhere in Cameroon
- Google Directions API with `region=cm` for Cameroon-optimized routes
- Real-time traffic data with `departure_time=now`
- Step-by-step voice-ready instructions with maneuver icons
- Route polyline on the map (green)
- ETA and remaining distance/duration
- Auto-advances to next instruction as you drive
- Popular Cameroon cities as quick suggestions

**How to use:** Tap the navigation button on the journey screen → search for a destination → select from results → route appears with instruction card.

### Background Location Tracking

- GPS tracking continues when the app is backgrounded or the phone is locked
- Persistent notification on Android (cannot be dismissed while recording)
- Background location indicator on iOS
- Uses `activityType: automotiveNavigation` for driving-optimized GPS
- Wake lock enabled to prevent device sleep during long journeys

**How it works:** When you start recording a journey, the app switches to background tracking mode. The GPS stream stays active, speed violations are still detected, and the journey continues to record path data even if you switch to another app.

### Offline-First with SQLite

- All journeys, violations, and incidents are saved locally first
- If the server is unreachable, operations are queued in a sync queue
- Automatic sync when connectivity is restored
- Local ID → Remote ID mapping for proper sync ordering
- Cached incidents and agencies available offline
- Cached routes for previously searched destinations
- Old cached data is automatically cleaned up (7-day retention for incidents)

**How it works:** Every write operation (create journey, record violation, submit incident) goes through the SyncService. If online, it sends to the API immediately. If offline, it queues locally and retries when connectivity returns. The sync queue handles dependency ordering — violations are not synced until their parent journey has a remote ID.

### Community Hazard Map

- Live incident pins on the map showing all reported hazards
- Auto-refreshes every 30 seconds while the map is visible
- Cached incidents displayed immediately when offline
- Color-coded markers by incident type:
  - Red: Accidents
  - Orange: Hazards, potholes
  - Blue: Police checkpoints, speed cameras
  - Yellow: Roadworks
  - Violet: Driver conduct reports
- Tap any pin for details and time reported
- Toggle hazard visibility with the warning button
- Badge shows count of active hazards when hidden

## Architecture

```
lib/
├── core/
│   ├── config.dart          # App configuration constants
│   └── theme.dart           # Material theme (light/dark)
├── models/
│   ├── agency.dart
│   ├── incident.dart
│   ├── journey.dart
│   ├── user.dart
│   └── violation.dart
├── services/
│   ├── api_service.dart       # HTTP client for backend API
│   ├── auth_service.dart      # Authentication (register, login, guest)
│   ├── connectivity_service.dart  # Online/offline detection
│   ├── journey_service.dart   # Journey API calls
│   ├── local_database.dart    # SQLite offline cache
│   ├── location_service.dart  # GPS tracking (foreground + background)
│   ├── navigation_service.dart # Google Directions API + polyline decoding
│   ├── notification_service.dart # Firebase FCM push notifications
│   └── sync_service.dart      # Offline-first write queuing + sync
├── controllers/
│   ├── admin_controller.dart
│   ├── auth_controller.dart
│   ├── hazard_controller.dart       # Live incident polling + caching
│   ├── journey_controller.dart     # Journey recording + speed detection
│   ├── navigation_controller.dart  # Turn-by-turn navigation state
│   ├── notification_service.dart
│   └── scoreboard_controller.dart
├── screens/
│   ├── access_screen.dart
│   ├── admin_screen.dart
│   ├── history_screen.dart
│   ├── journey_screen.dart     # Main map + speedometer + navigation
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── report_screen.dart
│   ├── scoreboard_screen.dart
│   └── travel_flow_screen.dart
└── widgets/
    ├── bottom_nav.dart
    ├── hazard_map.dart           # Incident markers + hazard UI
    ├── map_overlay.dart
    ├── navigation_overlay.dart   # Destination search + instruction card
    ├── speedometer_widget.dart
    └── sync_indicator.dart       # Pending sync count badge
```

## Backend API

The app expects an Express.js backend with these endpoints:

- `POST /api/auth/register` — Register with phone, birthYear, pin
- `POST /api/auth/login` — Login with phone, pin
- `POST /api/auth/reset-pin` — Reset PIN with birthYear verification
- `GET /api/journeys/user/:userId` — Get user's journey history
- `POST /api/journeys` — Create a new journey
- `PATCH /api/journeys/:id` — Update/complete a journey
- `POST /api/violations` — Create a speed violation
- `POST /api/incidents` — Create an incident/conduct report
- `GET /api/incidents` — Get all active incidents (for hazard map)
- `GET /api/agencies` — Get agency scoreboard
- `GET /api/violations` — Get published violations
- `POST /api/devices/register` — Register FCM device token
- `DELETE /api/devices/:token` — Unregister FCM device token

## Admin Access

- Phone: `admin`
- PIN: `1234`

## Speed Limits (Default)

| Vehicle | Limit (km/h) |
|---------|-------------|
| Car     | 90          |
| Bus     | 80          |
| Lorry   | 70          |
| Bike    | 50          |

## Deployment

### Google Play Store

1. Build a release APK: `flutter build appbundle --release`
2. Upload to [Google Play Console](https://play.google.com/console)
3. Set up app signing, store listing, and content rating

### Apple App Store

1. Build a release: `flutter build ipa --release`
2. Open `build/ios/archive/Runner.xcarchive` in Xcode
3. Upload to App Store Connect
4. Set up App Store listing, screenshots, and review notes

## Important Notes

- **Background location**: Mobile OS battery optimization can still throttle or kill backgrounded apps. The persistent notification helps prevent this on Android, but is not a guarantee. iOS is more restrictive — background location may stop if the app is force-quit.
- **Google Directions API**: Requires a billing-enabled Google Cloud project. The API has a free tier ($200/month credit) but usage beyond that incurs charges.
- **Offline-first**: The app works fully offline for journey recording and incident reporting. Data syncs automatically when connectivity returns. The scoreboard and hazard map show cached data when offline.
- **Firebase**: Push notifications require Firebase setup. The app works without Firebase — FCM is a safe no-op until configured.
