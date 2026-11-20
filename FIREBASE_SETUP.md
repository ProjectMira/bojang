# Firebase in Bojang

Bojang's backend is its own server (FastAPI + Postgres on Cloud Run, repo `bojang-backend`).
Firebase provides sign-in (Auth) and the services below. The code is in place; each service
needs a one-time console step before it works in production.

Firebase only runs where a real `GoogleService-Info.plist` is bundled (iOS release builds; CI
writes it from the `GOOGLE_SERVICE_INFO_PLIST` secret). Android has no `google-services.json`
yet, so none of this runs on Android (see the last section). Without Firebase every service
below does nothing and the app behaves as before.

## Crashlytics + Performance Monitoring

- Code: `lib/services/crash_reporting.dart`. Crashlytics records Flutter errors, uncaught async
  errors (non-fatal) and native crashes; each report carries the Firebase uid and the current
  `screen`. PostHog's native crash capture is off so the two do not compete for the signal
  handlers; PostHog still gets Dart errors.
- Performance: app start (automatic) and every backend request (`PerformanceHttpClient`,
  query strings dropped).
- Both follow Settings > Privacy > "Share usage analytics". Debug builds send nothing.
- CI uploads dSYMs to Crashlytics after each iOS export (step "Upload dSYMs to Crashlytics";
  it never fails the release).

Console: open Crashlytics and Performance once in the Firebase console so the dashboards
are created. Nothing else is required.

## Remote Config

- Code: `lib/services/remote_settings.dart`. The app starts with the defaults, fetches fresh
  values in the background (at most hourly) and applies console changes live.

| Parameter | Default | Effect |
|---|---|---|
| `tap_capture_enabled` | true | false stops recording taps, swipes and scrolls |
| `backend_events_enabled` | true | false pauses uploads to the backend (events queue, capped) |
| `home_announcement_title` | "" | non-empty shows a news card at the top of Home |
| `home_announcement_body` | "" | card text |
| `home_announcement_url` | "" | link opened when the card is tapped |
| `home_announcement_id` | "" | change it to show a new card to learners who dismissed the old one |
| `exp_<name>` | (none) | experiment: the value is attached to every analytics event as `exp_<name>`, so PostHog can compare groups. Use a "User in random percentile" condition to split learners. |

Console: Remote Config > Create configuration > add the parameters you want to change.

## App Check

- App: `lib/services/app_check_service.dart`. DeviceCheck on iOS (no extra entitlement),
  Play Integrity on Android, debug provider in debug builds. `ApiService` sends the token as
  `X-Firebase-AppCheck` on every request.
- Backend: `api/app_check.py`, `APP_CHECK_MODE` env on Cloud Run:
  `monitor` (default: verify and count, never block), `enforce` (401 without a valid token),
  `off`. Counts per server instance: `GET /admin/app-check/stats` (admin token).

Console:
1. Apple Developer > Keys > create a key with **DeviceCheck** enabled (the APNs key below can
   have both services), download the `.p8`.
2. Firebase > App Check > Apps > iOS app > DeviceCheck > upload the `.p8`, enter the Key ID and
   Team ID `W66Z24ZPWQ`.
3. Watch `/admin/app-check/stats` for a week after the build ships. When `valid_share` is close
   to 1 for current app versions, set `APP_CHECK_MODE=enforce` on Cloud Run. Older app versions
   send no token and are refused from then on, so enforce only once few people still use them.
4. Optional, also after that: enforce App Check for Firebase Authentication in the console.

## Push notifications (Firebase Cloud Messaging)

- App: `lib/services/push_service.dart`. Registers the FCM token with the backend
  (`POST /notifications/devices`) for the signed-in or anonymous learner, re-registers on token
  refresh and account change, shows pushes while the app is open, and a tapped push with
  `data.screen` = home / streak / games / profile opens that tab. Settings > Notifications has a
  "Streak reminders" switch.
- iOS: `aps-environment` in `Runner.entitlements` (CI sets it to `production`), background mode
  `remote-notification`. CI enables the Push Notifications capability on the App ID through the
  App Store Connect API; if the API key cannot, the build ships without push and the run shows
  a warning.
- Backend:
  - `POST /admin/notifications/send` (admin token): `{"title", "body", "uids": [...]}` or
    `"all": true`, optional `"data": {"screen": "home", "campaign": "name"}` and `"dry_run"`.
  - `POST /jobs/streak-reminders`: the streak-at-risk push, run hourly. It checks the
    `X-Cron-Secret` header against `CRON_SECRET`. `STREAK_REMINDER_HOUR` (default 20) is the
    learner's local hour.
  - Set up on 2026-11-21: secret `CRON_SECRET` in Secret Manager (project `bojang-backend`,
    readable by `1042932678350-compute@developer.gserviceaccount.com`), passed to the function by
    `SecretParam("CRON_SECRET")` in `functions/main.py`. Do not set it on the Cloud Run service
    by hand: `firebase deploy` replaces the service's environment. Cloud Scheduler job
    `bojang-streak-reminders` (us-central1, `0 * * * *` UTC) posts to the route with the header.
    To rotate: add a new secret version, redeploy, then
    `gcloud scheduler jobs update http bojang-streak-reminders --location=us-central1 --update-headers=X-Cron-Secret=<new>`.

Console:
1. Apple Developer > Keys > create a key with **Apple Push Notifications service (APNs)**,
   download the `.p8` (the DeviceCheck key above can be the same key).
2. Firebase > Project settings > Cloud Messaging > Apple app configuration > APNs
   authentication key > upload the `.p8` with its Key ID and Team ID `W66Z24ZPWQ`.
3. Done: `CRON_SECRET` and the hourly Cloud Scheduler job (see above).

## App Store privacy label

Firebase adds data the current label (Name, Email, User ID, Product Interaction, Crash Data,
Other Diagnostic Data) does not list. Add these, as App Functionality + Analytics:
- **Performance Data** (Performance Monitoring)
- **Device ID** (Firebase installation IDs used by Crashlytics, Performance, Remote Config and
  FCM tokens), not used for tracking.

## Android (not set up)

Android has no Firebase app config. To turn these services on there: add an Android app with
package `com.bojang.app` in the Firebase console, add the release SHA-256 (also needed for Play
Integrity), have CI write `android/app/google-services.json` from a secret, and add the
`com.google.gms.google-services` and `com.google.firebase.crashlytics` Gradle plugins. Android
releases are paused until the Play upload key is reset anyway.
