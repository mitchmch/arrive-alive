# Arrive Alive Flutter Store Deployment Guide

This guide prepares Arrive Alive 3.0.0 for Android Studio development, Google
Play delivery, and Apple App Store delivery. It assumes the source folder is
`flutter_app`, the Android application ID is
`com.kutinacommunity.arrive_alive`, and the iOS bundle ID is
`com.kutinacommunity.arriveAlive`.

## Release status

- App version: `3.0.0`
- Build number: `3`
- Production API: `https://arrivealive.app`
- Voice API: `https://arrivealive.app/api/voice`
- Primary map: Mapbox
- Fallback map: Google Maps
- Android minimum SDK: 21
- iOS minimum version: 15.0
- Release credentials: intentionally excluded from source control

Before every later store update, increase the build number in `pubspec.yaml`.
For example, change `3.0.0+3` to `3.0.1+4`. A store will reject a build number
that it has already processed.

## Required accounts and computers

### Both platforms

- Install the current stable Flutter SDK and run `flutter doctor -v`.
- Install Android Studio with the Flutter and Dart plugins.
- Use a Firebase project for push notifications.
- Use a Mapbox account with a public runtime token and a secret SDK-download
  token.
- Keep every API secret outside the repository.

### Google Play

- Create a Google Play Console developer account.
- Complete the developer identity and payment profile.
- New personal developer accounts created after 13 November 2023 must complete
  a closed test with at least 12 opted-in testers for 14 continuous days before
  production access is available
  ([Google Play testing requirement](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)).
- Google Play requires new apps and updates submitted from 31 August 2026 to
  target Android 16, API level 36, or higher
  ([Google Play target API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)).
  Confirm `flutter.targetSdkVersion` resolves to 36 or later before submission.

### Apple App Store

- Use a Mac with a current macOS release and Xcode.
- Join the Apple Developer Program.
- App Store uploads from 28 April 2026 must use Xcode 26 or later and the iOS
  26 SDK
  ([Apple submission requirements](https://developer.apple.com/news/upcoming-requirements/)).
- Configure a real iPhone for final GPS, notification, audio, and background
  location testing.

## Open and validate in Android Studio

1. Extract the source ZIP to a normal development folder.
2. In Android Studio, choose **Open** and select the folder containing
   `pubspec.yaml`.
3. Select the stable Flutter SDK if prompted.
4. Open the built-in terminal and run:

```bash
flutter clean
flutter pub get
flutter doctor -v
flutter analyze
flutter test
```

5. Connect a physical Android phone with developer mode and USB debugging
   enabled.
6. Run the app with development configuration:

```bash
flutter run \
  --dart-define=API_BASE_URL=https://arrivealive.app \
  --dart-define=VOICE_API_URL=https://arrivealive.app/api/voice \
  --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_PUBLIC_MAPBOX_TOKEN \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_RESTRICTED_GOOGLE_MAPS_KEY \
  --dart-define=GOOGLE_DIRECTIONS_API_KEY=YOUR_RESTRICTED_DIRECTIONS_KEY
```

Use PowerShell backticks instead of backslashes on Windows, or place the
command on one line.

## Configure production services

### Mapbox

1. Put the Mapbox secret downloads token in the developer machine's
   `~/.gradle/gradle.properties`:

```properties
MAPBOX_DOWNLOADS_TOKEN=YOUR_SECRET_DOWNLOADS_TOKEN
```

2. On macOS, add the SDK-download credentials to `~/.netrc` as documented by
   Mapbox.
3. Pass only the public `pk.` token to the app using
   `MAPBOX_ACCESS_TOKEN`.
4. Restrict the public token to the URLs and applications required for Arrive
   Alive.

Never commit the Mapbox secret downloads token.

### Firebase Cloud Messaging

1. Register the Android app with package name
   `com.kutinacommunity.arrive_alive`.
2. Place `google-services.json` in `android/app/`.
3. Register the iOS app with bundle ID
   `com.kutinacommunity.arriveAlive`.
4. Place `GoogleService-Info.plist` in `ios/Runner/` using Xcode so it is added
   to the Runner target.
5. In Apple Developer, create an APNs authentication key and add it to Firebase
   Cloud Messaging.
6. Enable Push Notifications and Background Modes in Xcode. Retain
   `remote-notification` and `location`.
7. Test foreground, background, terminated, and notification-tap behavior on
   real devices.

Do not put a Firebase server key or service-account JSON inside the mobile app.

### Google Maps fallback and routing

Create separate restricted keys for Android and iOS. Restrict Android by
package name and signing certificate fingerprint. Restrict iOS by bundle ID.
Enable only the required Maps, Directions, Geocoding, and Places APIs. The
Mapbox map remains the primary renderer.

## Google Play release

### Create the upload key

Run this once and back up the keystore securely:

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Copy `android/key.properties.example` to `android/key.properties`, then replace
the placeholders. The included Gradle configuration reads this file for
release signing. Both `key.properties` and keystore files are ignored by Git.
Google's recommended Flutter signing flow is documented in the
[Flutter Android release guide](https://docs.flutter.dev/deployment/android).

### Produce the Android App Bundle

Run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://arrivealive.app \
  --dart-define=VOICE_API_URL=https://arrivealive.app/api/voice \
  --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_PUBLIC_MAPBOX_TOKEN \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_RESTRICTED_GOOGLE_MAPS_KEY \
  --dart-define=GOOGLE_DIRECTIONS_API_KEY=YOUR_RESTRICTED_DIRECTIONS_KEY
```

The bundle is created at:

```text
build/app/outputs/bundle/release/app-release.aab
```

Inspect the final target SDK:

```bash
apkanalyzer manifest target-sdk build/app/outputs/bundle/release/app-release.aab
```

### Configure Play Console

1. Create the app in Play Console with the final name, default language,
   app/game selection, and free/paid status.
2. Enable Play App Signing.
3. Complete App access. Provide working reviewer credentials for authenticated
   areas and clear instructions for reaching the admin and safety features.
4. Add the privacy policy URL.
5. Complete Data safety based on actual collection and sharing behavior,
   including precise/background location, identifiers, user content,
   diagnostics, and account data.
6. Complete Content rating, Ads, Target audience, News, and any other applicable
   declarations.
7. Add the store listing: short description, full description, app icon,
   feature graphic, phone screenshots, tablet screenshots if supported, support
   email, and website.
8. Upload the AAB first to Internal testing.
9. Test installation, sign-in, guest mode, Mapbox, GPS journey recording,
   hazards, speed breach alert/reporting, push notifications, background
   location, voice fallback, and offline recovery.
10. Promote to Closed testing, then Production when the account and release
    satisfy testing and policy requirements.

Google documents the complete release sequence in its
[Play Console rollout guide](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en)
and the required app declarations in
[Play Console app-content guidance](https://support.google.com/googleplay/android-developer/answer/10788890?hl=en).

## Apple App Store release

### Configure identifiers and signing

1. On a Mac, open `ios/Runner.xcworkspace`, not the `.xcodeproj`.
2. Select Runner, then **Signing & Capabilities**.
3. Select the Apple Developer team.
4. Confirm the bundle identifier is globally unique. If
   `com.kutinacommunity.arriveAlive` is not owned by your team, change it once
   before creating the App Store Connect record.
5. Enable Automatically manage signing unless your organization requires
   manual profiles.
6. Add capabilities for Push Notifications and Background Modes.
7. Confirm background modes include Location updates and Remote notifications.
8. Confirm the deployment target is iOS 15.0 or later.

### Create the App Store Connect record

1. In App Store Connect, create a new iOS app using the exact bundle ID.
2. Set the SKU and primary language.
3. Add the privacy policy URL, support URL, marketing URL if available,
   category, age rating, description, keywords, screenshots, and app icon.
4. Complete App Privacy accurately. Arrive Alive may process precise location,
   background location, identifiers, user content, diagnostics, and account
   data depending on the enabled production configuration.
5. Add App Review notes explaining:
   - why continuous location is needed during a journey;
   - how to reach guest and authenticated flows;
   - how to test hazard alerts and the Speed Board safely;
   - that speed reports are safety evidence, not emergency-service dispatch;
   - working review credentials for restricted features.

### Build and upload

From the Flutter project on the Mac:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://arrivealive.app \
  --dart-define=VOICE_API_URL=https://arrivealive.app/api/voice \
  --dart-define=MAPBOX_ACCESS_TOKEN=YOUR_PUBLIC_MAPBOX_TOKEN \
  --dart-define=GOOGLE_MAPS_API_KEY=YOUR_RESTRICTED_GOOGLE_MAPS_KEY \
  --dart-define=GOOGLE_DIRECTIONS_API_KEY=YOUR_RESTRICTED_DIRECTIONS_KEY
```

The archive and IPA are written under `build/ios/archive/` and
`build/ios/ipa/`. Upload through Xcode Organizer or Apple's Transporter app.
Flutter's current iOS workflow is documented in the
[Flutter iOS deployment guide](https://docs.flutter.dev/deployment/ios).

### TestFlight and review

1. Wait for App Store Connect processing to complete.
2. Complete export-compliance questions.
3. Add internal testers.
4. Test on at least one older supported iPhone and one current iPhone.
5. Verify location permission progression, background journey recording,
   battery behavior, map rendering, navigation audio, push notifications,
   hazard proximity alerts, SOS alarm stopping below the limit, and account
   deletion/support paths.
6. Add external TestFlight testers if broader validation is required.
7. Select the validated build, complete review information, and submit.

Apple requires privacy manifests and signatures for a list of commonly used
third-party SDKs. Review Flutter, Firebase, geolocator, sqflite, and every
shipped plugin against Apple's
[third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
before the final archive.

## Required privacy and safety materials

Prepare and publish:

- Privacy policy.
- Terms of use.
- Account deletion instructions and in-app deletion route if accounts are
  created in the app.
- Location-use explanation.
- Retention and deletion policy for journeys, speed samples, hazards, and
  reports.
- Contact and escalation route for incorrect agency or vehicle classifications.
- Statement that AI-generated summaries are explanatory only and deterministic
  evidence rules control safety classifications.
- Statement that Arrive Alive is not an emergency service.

The store declarations must match actual runtime behavior and backend
retention. Do not copy a generic privacy answer.

## Final release gate

Do not submit until every item passes:

- `flutter analyze` has no issues.
- `flutter test` passes.
- Android AAB is signed with the upload key, not a debug key.
- iOS archive is signed with the distribution identity.
- Production API, public speed limits, public hazards, and voice endpoint work.
- Mapbox is the primary map and renders on physical Android and iPhone devices.
- Google Maps fallback works with restricted platform keys.
- GPS speed uses the selected vehicle's persisted administrator limit.
- The speed breach icon is grey and disabled below the limit, active during a
  breach, and returns to grey when speed falls below the limit.
- The breach alarm stops below the limit and at journey end.
- 800 m and 500 m hazard alerts deduplicate correctly.
- Push notifications work in foreground, background, and terminated states.
- Guest and authenticated permissions are correct.
- No API secret, keystore, service account, or private certificate is present
  in the repository or source ZIP.
- Store screenshots reflect the submitted build.
- Reviewer credentials and test instructions work.
- Privacy and data-safety disclosures match production.

## Rollback and support

Keep the previous store version available during staged rollout. Start with a
small production percentage, monitor crashes, ANRs, API failures, map startup,
GPS permission failures, notification delivery, and battery reports, then
increase gradually. Google Play supports staged rollout and halting a release.
For iOS, use phased release and pause it if a serious issue appears.

Tag the exact submitted commit and record:

- version and build number;
- Android AAB checksum;
- iOS archive/IPA checksum;
- Mapbox and Firebase project identifiers;
- backend deployment identifier;
- store submission date;
- reviewer account used;
- release owner and rollback decision.
