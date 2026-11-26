# Firebase in Bojang

Bojang's backend is its own server (FastAPI + Postgres on Cloud Run, repo `bojang-backend`).
Firebase provides sign-in (Auth) and the services below. The code is in place; each service
needs a one-time console step before it works in production.

Firebase project: `bojang-backend` (console account ta3tsering@gmail.com, which is `/u/1/` in
Chrome). iOS app `com.bojang.app`, Team ID `W66Z24ZPWQ` and App Store ID `6752509504` set
2026-11-21.

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

Console: the six parameters above were published on 2026-11-21 (template version 1, values equal
to the in-app defaults; announcement fields use the in-app default). Edit them under Remote
Config > Parameters, then Publish changes.

## App Check

- App: `lib/services/app_check_service.dart`. DeviceCheck on iOS (no extra entitlement),
  Play Integrity on Android, debug provider in debug builds. `ApiService` sends the token as
  `X-Firebase-AppCheck` on every request.
- Backend: `api/app_check.py`, `APP_CHECK_MODE` env on Cloud Run:
  `monitor` (default: verify and count, never block), `enforce` (401 without a valid token),
  `off`. Counts per server instance: `GET /admin/app-check/stats` (admin token).

Console: done 2026-11-21. `com.bojang.app` has DeviceCheck (key `3BMNZ7JP4R`, token TTL 1 h)
and App Attest registered.
1. Watch `/admin/app-check/stats` for a week after the build ships. When `valid_share` is close
   to 1 for current app versions, set `APP_CHECK_MODE=enforce` on Cloud Run. Older app versions
   send no token and are refused from then on, so enforce only once few people still use them.
2. Optional, also after that: enforce App Check for Firebase Authentication in the console.

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
    learner's local hour. One streak saver follows at `STREAK_SAVER_HOUR` (default reminder + 2)
    only if the reminder was not opened (`POST /notifications/opened`) and the learner still has
    not practised. At most 2 a day; each push expires at the learner's local midnight (FCM `ttl`,
    APNs `apns-expiration`), and the saver replaces the reminder (tag / `apns-collapse-id`
    `bojang_streak`). Every send is logged in `push_notifications` and as `server_push_sent`.
  - Push copy: Remote Config **server** template (Remote Config > Server tab, not the client
    template), read with `firebase_admin.remote_config`. Defaults are in
    `functions/services/notification_copy.py`, used for any parameter that is missing or invalid.
    The backend service account needs Remote Config read access (Firebase Remote Config Viewer).

    | Server parameter | Value |
    |---|---|
    | `notif_copy_not_started` | JSON list of `{"id", "title", "body"}`, first push before 16:00 local |
    | `notif_copy_evening` | same, first push 16:00-22:00 |
    | `notif_copy_late` | same, the streak saver (and a first push after 22:00) |
    | `notif_copy_frozen` | same, first push when a freeze covered yesterday |
    | `notif_streak_saver_enabled` | `false` stops the streak saver |

    `{streak}` and `{next}` in a line become the streak length and the next day. The app logs
    `notification_opened` with `line_id` to PostHog, so open rates can be compared per line;
    give a rewritten line a new id. A percent condition on `randomization_id` (the learner's
    Firebase uid) splits learners between pools.
- Permission: the app does not ask at launch. `NotificationPrimer`
  (`lib/services/notification_primer.dart`) shows a soft pre-prompt ("Turn on reminders" /
  "Maybe later") after the streak celebration of a lesson that starts or extends the streak or
  used a freeze; at most 3 times, 3+ days apart, and only while the OS prompt can still appear.
  The Settings reminder switches also ask.
  - Set up on 2026-11-21: secret `CRON_SECRET` in Secret Manager (project `bojang-backend`,
    readable by `1042932678350-compute@developer.gserviceaccount.com`), passed to the function by
    `SecretParam("CRON_SECRET")` in `functions/main.py`. Do not set it on the Cloud Run service
    by hand: `firebase deploy` replaces the service's environment. Cloud Scheduler job
    `bojang-streak-reminders` (us-central1, `0 * * * *` UTC) posts to the route with the header.
    To rotate: add a new secret version, redeploy, then
    `gcloud scheduler jobs update http bojang-streak-reminders --location=us-central1 --update-headers=X-Cron-Secret=<new>`.

Console: done 2026-11-21.
- Apple key "Bojang Push and DeviceCheck", Key ID `3BMNZ7JP4R`: APNs (Sandbox & Production,
  team scoped) + DeviceCheck. Apple keeps no copy of the `.p8`; Tashi holds the only one.
- Uploaded as the **production** APNs auth key for `com.bojang.app`. The development slot is
  empty; upload the same `.p8` there to get pushes on debug builds run from Xcode.
- `CRON_SECRET` and the hourly Cloud Scheduler job (see above).

## Analytics (Google Analytics for Firebase)

- Code: the `_firebase*` helpers in `lib/services/analytics.dart` and
  `lib/models/firebase_event_rules.dart`; what is sent is in ANALYTICS_EVENTS.md, "Firebase
  Analytics". Named product events, screen views and app sessions, never taps or scrolls; user
  id = Firebase uid; no names, emails, coordinates, IDFA or ad signals.
- Follows Settings > Privacy > "Share usage analytics" (`setAnalyticsCollectionEnabled`). Debug
  builds send nothing unless run with `--dart-define=FIREBASE_ANALYTICS_IN_DEBUG=true`.

Console (not done yet):
1. Project settings > Integrations > Google Analytics > Enable. Create a new GA4 property in a
   Google Analytics account owned by ta3tsering@gmail.com (not an OpenPecha one), e.g. "Bojang",
   reporting time zone of Tashi's choice, currency USD.
2. Turn off data sharing that the app does not need: in Analytics admin > Data collection, leave
   Google signals off; Admin > Account settings: uncheck the "Google products & services" and
   "Modeling contributions" sharing options; Data retention 14 months.
3. Re-download `GoogleService-Info.plist` for `com.bojang.app` (it now carries the Analytics
   settings) and update the `GOOGLE_SERVICE_INFO_PLIST` repo secret if its contents changed.
   The `GOOGLE_APP_ID` stays the same, so an old plist also works.
4. DebugView: build from Xcode with the scheme argument `-FIRDebugEnabled` (Product > Scheme >
   Edit Scheme > Run > Arguments) and `--dart-define=FIREBASE_ANALYTICS_IN_DEBUG=true
   --dart-define=ENABLE_IOS_FIREBASE=true` in the Dart defines, with the real plist. Then Firebase
   console > Analytics > DebugView should show `first_open`, `session_start`, `screen_view` and
   `app_launched` within seconds (`app_session_started` too when POSTHOG_IN_DEBUG=true).
5. Register custom definitions in GA4 (Admin > Custom definitions) for the parameters and user
   properties to report on, e.g. event-scoped `level_id`, `correct`, `bojang_session_id`; user-scoped
   `auth_provider`, `current_streak`, `league`, `lesson_style`, `voice`.

## App Store privacy label

Firebase adds data the current label (Name, Email, User ID, Product Interaction, Crash Data,
Other Diagnostic Data) does not list. Add these, as App Functionality + Analytics:
- **Performance Data** (Performance Monitoring)
- **Device ID** (Firebase installation IDs used by Crashlytics, Performance, Remote Config and
  FCM tokens, and the Analytics app instance id), not used for tracking.

Firebase Analytics adds nothing beyond that list for the label: it collects User ID, Product
Interaction and Device ID (above), and infers **Coarse Location** from the IP address. Coarse
Location should be on the label in any case if it is not yet (Settings approximate location, `LocationService`); mark it
Analytics, linked to the user, not tracking. Keep "Used for tracking" at No: no IDFA, ad signals
off, no data linked with other companies' data for ads.

## Privacy policy

Published at https://www.bojang.in/privacy-policy.html (repo `Bojang-website`, deployed by Render
on push to main). App Store Connect's privacy policy URL points there (changed 2026-11-21; it goes
live with the next app version). Update the policy whenever the app starts collecting something new.

## Android (not set up)

Android has no Firebase app config. To turn these services on there: add an Android app with
package `com.bojang.app` in the Firebase console, add the release SHA-256 (also needed for Play
Integrity), have CI write `android/app/google-services.json` from a secret, and add the
`com.google.gms.google-services` and `com.google.firebase.crashlytics` Gradle plugins. Android
releases are paused until the Play upload key is reset anyway.
