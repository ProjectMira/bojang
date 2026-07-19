# App Review Response Plan — July 17, 2026

Submission ID: 9d579324-de12-474d-a7de-621fdbe29070
Apple's second reply raised two issues:

1. **Guideline 4.8 (Login Services)** — "still" no equivalent login option next to Google.
2. **Guideline 5.1.1(v) (Data Collection & Storage)** — app supports account creation
   but offers no account deletion. Apple asks for a **screen recording from a physical
   device** showing the complete deletion flow.

## What is actually going on (verified 2026-07-17 via the ASC API)

- The App Store version currently **WAITING_FOR_REVIEW is "2.0.0(17)" with build 17
  attached** (not build 18 as the previous plan specified). Submitted 2026-07-17 06:45 UTC.
- The screenshot Apple attached shows the **old auth screen** — subtitle "Sign in with
  **Google** to sync XP…" and no Apple button. That exact copy was replaced in commit
  `8355c0b` (the same commit that added Sign in with Apple). **Conclusion: Apple's 4.8
  reply was written against the old 1.0.1 (10) binary, not build 17/18.** Builds 17 and
  18 do contain Sign in with Apple (CI builds with `ENABLE_IOS_FIREBASE=true` and fails
  the release if the IPA lacks the `applesignin` entitlement or bundles the placeholder
  Firebase plist).
- So 4.8 is already fixed in the binary; it "reappeared" only because the reviewer had
  not seen the new build yet. The reply below identifies Sign in with Apple explicitly,
  as Apple invites us to do.
- **5.1.1(v) is a real gap in the app UI.** The backend endpoint `DELETE /auth/me`
  already exists and is **live in production** (verified in the deployed OpenAPI spec at
  `bojang-backend-lbziapssxq-uc.a.run.app`). It deletes every user-owned row (profile,
  enrollments, gamification state, level progress, daily activity, learning sessions,
  XP events, quiz attempts, subscriptions, purchase receipts, auth identities, user row —
  see `bojang-backend/functions/database/postgres.py::delete_document`) and then deletes
  the Firebase Auth user via the Admin SDK. The Flutter client even has an unused
  `ApiService.deleteAccount()` (from May). **Only the in-app UI flow is missing.**

## Why the current submission must be pulled

If build 17 gets reviewed as-is it will be rejected again on 5.1.1(v) (no deletion UI),
and build 17 also lacks the guest re-entry fix from build 18. Remove the submission from
review, ship one new build containing the deletion flow, and resubmit once.

---

# Part A — Implementation spec (hand to Sonnet 5)

Repo: `/Users/tashitsering/Desktop/Projects/bojang/bojang` (Flutter, branch `main`).

> **Before you start:** `git status` shows uncommitted WIP unrelated to this task
> (`pubspec.yaml` adds `share_plus`, plus lockfile/generated-registrant churn). Do NOT
> sweep these into your commit. Stash them (`git stash`) or leave them out of `git add`.
> Also note: **every push to `main` triggers a full iOS release to TestFlight**
> (`.github/workflows/mobile-release.yml`, paths-ignore covers only `pubspec.yaml`), so
> push exactly once, when the change is verified.

## A1. Add an "Account" section to Settings with the delete flow

File: `lib/screens/settings_screen.dart`

Current structure: `_StateScreenState.build` renders sections "Appearance", "Learning",
"Progress", "About" via `_buildSectionHeader(...)` + `_buildSettingsCard(...)`. Match
these helpers and the existing GoogleFonts.poppins + Jomolhari-fallback styling exactly.

1. Import `GoogleAuthService` and the `AuthScreen`:
   `../services/google_auth_service.dart`, `auth_screen.dart`.
2. In `build`, read the auth service:
   `final authService = Provider.of<GoogleAuthService>(context, listen: false);`
   (`GoogleAuthService` is provided app-wide in `lib/main.dart` via `MultiProvider`;
   it exposes `currentUser` / `isSignedIn`.)
3. Between the "Progress" and "About" sections, add — **only when
   `authService.isSignedIn`** — a new section:
   - `_buildSectionHeader('Account')`
   - A settings card: title **"Delete Account"**, subtitle
     "Permanently delete your account and synced data", icon `Icons.delete_forever`,
     styled destructive (red icon/title — follow how the existing cards pass colors; if
     `_buildSettingsCard` doesn't support a color override, add an optional
     `iconColor`/`titleColor` parameter defaulting to current behavior).
   - `onTap: _handleDeleteAccount`.
4. Implement `_handleDeleteAccount()`:
   - **Dialog 1 (explain):** title "Delete Account?", body: "This permanently deletes
     your account and all synced data: XP, streaks, league progress, completed levels,
     and quiz history. This cannot be undone." Buttons: Cancel / Continue.
   - **Dialog 2 (confirm):** title "Are you sure?", body: "Your account will be
     permanently deleted. You can keep using Bojang without an account, but your synced
     progress cannot be recovered." Buttons: Cancel / **"Delete My Account"** (red, bold).
     Two dialogs is deliberate — Apple explicitly allows confirmation steps.
   - On confirm, show a blocking progress indicator (e.g. `showDialog` with
     `barrierDismissible: false` and a `CircularProgressIndicator`).
   - Call `await ApiService().deleteAccount()` **first, while the Firebase session is
     still valid** (the endpoint needs the ID token; the server deletes the Firebase
     user, so order matters: backend call → local sign-out).
   - **On success (`true`):**
     a. `await Provider.of<GoogleAuthService>(context, listen: false).signOut();`
        (clears Firebase + Google session and `_currentUser`; it already swallows the
        errors that can occur now that the server has deleted the Firebase user).
     b. `await Provider.of<ProgressService>(context, listen: false).resetProgress();`
        (exists at `lib/services/progress_service.dart:251`; clears local XP/streak/etc.
        so the UI doesn't show ghost progress from the deleted account).
     c. Dismiss the progress dialog, then
        `Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (route) => false);`
        — same pattern as `_handleLogout` in `lib/screens/profile_screen.dart:74`.
     d. Show a SnackBar on the new route: "Your account has been deleted." (schedule it
        with `WidgetsBinding.instance.addPostFrameCallback` or use a
        `ScaffoldMessenger` obtained before navigation — verify it actually appears).
   - **On failure (`false` or exception):** dismiss the progress dialog and show an
     error dialog: "We couldn't delete your account. Please check your connection and
     try again." Do NOT sign the user out on failure.
   - Guard every `context` use after `await` with `if (!mounted) return;`.
5. Guest users (`isSignedIn == false`) must not see the Account section at all.

## A2. Tests

- Widget test for `SettingsScreen`: shows "Delete Account" when a signed-in
  `GoogleAuthService` is provided, hides it for guests. `AuthScreen` already accepts an
  injected `authService` — follow whatever injection pattern existing widget tests use
  (see `test/`); wrap the screen in a `MultiProvider` with a fake/stub
  `GoogleAuthService` whose `isSignedIn` returns true/false.
- Backend (optional but cheap, repo `bojang-backend/functions`): `tests/test_auth.py`
  currently has no delete test — add one: create a user via the test client, call
  `DELETE /auth/me`, assert 200 and that a subsequent `GET /auth/me` returns 404.
  Run with the repo's pytest setup.

## A3. Verify locally before pushing (iOS simulator)

Per `bojang-verify-ship-workflow` / `bojang-apple-sign-in` memory:

1. The committed `ios/Runner/GoogleService-Info.plist` is a placeholder that crashes
   every local iOS run. Fetch the real one first (do NOT commit it — repo is public):
   `GET https://firebase.googleapis.com/v1beta1/projects/bojang-backend/iosApps/1:1042932678350:ios:1003658f46dedca0b2da9f/config`
   with a gcloud bearer token; base64-decode `configFileContents` over
   `ios/Runner/GoogleService-Info.plist`. Restore the placeholder before committing.
2. Run on the iOS simulator with `--dart-define=ENABLE_IOS_FIREBASE=true`.
3. Verify and screenshot:
   - Auth screen shows **Sign in with Apple above Google** (4.8 evidence).
   - Settings shows the Account section when signed in, hides it as guest.
   - Full deletion flow works end-to-end against production (create a throwaway
     Google-account sign-in, delete it, confirm you land on the auth screen and that
     re-signing-in creates a fresh profile with 0 XP).
4. `flutter analyze` and the test suite must pass.

## A4. Ship

1. Commit ONLY the delete-account changes (plus tests + this doc if desired) to `main`
   and push. The push triggers the iOS release workflow → **build 19** (build-only
   bump, `ENABLE_IOS_FIREBASE=true` automatic). Android stays paused via
   `ANDROID_RELEASE_PAUSED`.
2. Watch the workflow to green. CI gates already verify the applesignin entitlement and
   the real Firebase plist inside the IPA. (gh is unauthenticated — check errors via
   public check-run annotations or the web UI; poll ≥3 min apart.)
3. Confirm build 19 reaches TestFlight processing state VALID.

---

# Part B — Manual App Store Connect steps (for Tashi)

1. **Now:** App Store Connect → Bojang → remove the current submission from review
   ("Remove from Review" on the 2.0.0(17) submission). This prevents a wasted rejection
   of build 17.
2. While editable, clean the version string **"2.0.0(17)" → "2.0.0"** (it currently has
   the build number pasted into the marketing version).
3. After build 19 is on TestFlight: attach **build 19** to the 2.0.0 version.
4. App Review Information:
   - Keep **Sign-in required: NO** (no demo credentials — "Continue without account" is
     the demo mode; reviewers use Sign in with Apple for account features).
   - Review Notes: add the deletion path — "Account deletion: Profile tab → gear icon
     (Settings) → Account → Delete Account" — and the link to the screen recording
     (step 5).
5. **Screen recording (physical iPhone, required by Apple):**
   - Install build 19 from TestFlight on your iPhone.
   - Start iOS screen recording (Control Center), then in one take:
     a. Launch Bojang → tap **Sign in with Apple** → complete sign-in (this also
        demonstrates the 4.8 fix and "creating a new account").
     b. Go to **Profile tab → gear icon → Settings → Account → Delete Account**.
     c. Go through both confirmation dialogs → deletion completes → app returns to the
        login screen.
   - Upload the video somewhere reviewers can open (unlisted Google Drive/YouTube link)
     and paste the link into the Review Notes; ALSO attach the video file directly to
     the Resolution Center reply (replies support attachments).
6. Reply in the Resolution Center with the message below, then resubmit.

## Resolution Center reply (paste after build 19 is attached)

```
Hello,

Thank you for the detailed review. Both issues are addressed in the build attached
to this submission (version 2.0.0, build 19).

Guideline 4.8 — Login Services:
The app now offers Sign in with Apple as an equivalent login option. It appears as
the FIRST option on the sign-in screen, above Google sign-in. As your note states,
Sign in with Apple meets all of the guideline's requirements: it limits data
collection to name and email, lets users keep their email address private via Hide
My Email, and does not collect app interactions for advertising. The screenshot
attached to your last message shows the sign-in screen from the previously reviewed
binary (1.0.1); Sign in with Apple has been present since version 2.0.0.

Guideline 5.1.1(v) — Account Deletion:
The app now supports full account deletion, initiated and completed entirely
in-app: Profile tab → Settings (gear icon) → Account → Delete Account. After a
confirmation step, the app permanently deletes the user's account and all
associated data on our servers (profile, XP, streaks, league progress, completed
levels, quiz history) and the underlying authentication account. This is a
permanent deletion, not a deactivation, and requires no customer-service contact.
A screen recording captured on a physical iPhone demonstrating sign-in, navigation
to the deletion option, and the complete deletion flow is attached to this reply,
and a link is also included in the App Review Information notes.

Thank you for your time.
```

---

# Part C — July 18 rejection follow-up (2.1(a) SiwA error + 2.1 demo account)

Apple reviewed **build 17 again** (build 19 was never attached) on an iPad Air 11"
(iPadOS 26.5.2) and raised: (a) "an error message was displayed when we attempted to
Sign in with Apple", and (b) the old demo credentials ta6tsering@gmail.com failed.

## What was checked (2026-07-19)

- Firebase apple.com provider: enabled, clientId=com.bojang.app — correct for the
  native flow (verified via Identity Toolkit API).
- App ID capabilities: APPLE_ID_AUTH present (verified via ASC API).
- firebase_auth 5.7.0 iOS plugin: confirmed it runs Sign in with Apple **natively**
  (ASAuthorizationController) — no URL scheme needed; cancel maps to code "canceled".
- Runner.entitlements: applesignin present; CI verifies it in every shipped IPA.
- **Conclusion:** no client/server misconfiguration found. The most likely cause is
  Apple's review environment failing/dismissing the Apple-ID sheet, which our app
  answered with error-looking snackbars — including "Apple sign-in was cancelled or
  failed" even on a plain cancel. That reads as a bug to a reviewer.

## What was fixed

1. **App (→ build 20):** cancel of Apple/Google sign-in now shows nothing (a cancel is
   not an error); genuine failures show a designed dialog ("<Provider> sign-in didn't
   complete" + guidance to retry or continue without an account). Underlying error
   codes still go to the console for diagnosis. Files:
   `lib/services/google_auth_service.dart` (null only on cancel, rethrow real errors),
   `lib/screens/auth_screen.dart` (`_showSignInIssueDialog`), tests updated.
2. **ASC (done via API):** demo account name/password **cleared**, demoAccountRequired
   false, review notes rewritten — now leads with "no demo account exists, previously
   provided credentials were removed", and adds the account-deletion path per
   5.1.1(v).

## Remaining manual steps (Tashi)

1. Verify Sign in with Apple end-to-end on your **physical iPhone AND iPad** with
   TestFlight build 20 (Apple reviewed on iPad). If you see any error, report the
   exact dialog text back for diagnosis before resubmitting.
2. In App Store Connect: fix the version string "2.0.0(17)" → "2.0.0", attach
   **build 20**.
3. Record ONE screen recording on a physical device showing: launch → Sign in with
   Apple completing successfully → Profile → Settings → Account → Delete Account →
   both confirmations → back at the login screen. This single video covers 2.1(a),
   4.8, and 5.1.1(v).
4. Reply in the Resolution Center with the message below (attach the video), then
   resubmit.

## Resolution Center reply (paste with build 20)

```
Hello,

Thank you for the continued review. We have addressed all outstanding issues in
the build attached to this submission (version 2.0.0, build 20).

Guideline 2.1(a) — Sign in with Apple error:
We tested Sign in with Apple on physical iPhone and iPad devices running the
attached build and it completes successfully; the attached screen recording,
captured on a physical device, shows the full flow. We could not reproduce a
failure, but we did find that the previously reviewed build displayed an
error-style message even when the Apple ID sheet was simply dismissed. The new
build corrects this: dismissing the sheet returns to the sign-in screen quietly,
and only a genuine failure shows a dialog with guidance. Please note the
previously reviewed binary was build 17; the attached build 20 also contains
in-app account deletion and the corrected sign-in behavior.

Guideline 2.1 — Demo account:
We apologize for the confusion: the demo credentials previously listed in App
Review Information were stale and have now been removed entirely. No demo
account is needed to review the app — tapping "Continue without account" on the
first screen unlocks every learning feature. Account features (sync of XP,
streaks, and league progress) can be reviewed with Sign in with Apple using any
Apple ID; an account is created automatically on first sign-in.

Guideline 5.1.1(v) — Account deletion (from your July 17 message):
The attached build includes full in-app account deletion: Profile tab → Settings
(gear icon) → Account → Delete Account. After a confirmation step, the account
and all associated data are permanently deleted from our servers, along with the
underlying authentication account. The attached screen recording demonstrates
creating an account with Sign in with Apple, navigating to the deletion option,
and the complete deletion flow.

Guideline 4.8 — Login Services (from your July 17 message):
Sign in with Apple is offered as the first login option, alongside Google. It
limits data collection to name and email, supports Hide My Email, and does not
collect app interactions for advertising.

Thank you for your time.
```

---

# Reference — facts verified while writing this plan

- Prod API `https://bojang-backend-lbziapssxq-uc.a.run.app` exposes
  `DELETE /auth/me` (checked `/openapi.json` 2026-07-17).
- Server deletion path: `api/routes/auth.py::delete_account` →
  `postgres.py::delete_document("users", uid)` (explicit deletes across all 12
  user-owned tables, FKs also `ondelete="CASCADE"`) → `firebase_admin.auth.delete_user`.
- App client: `ApiService.deleteAccount()` at `lib/services/api_service.dart:188`
  (returns `bool`), base URL defaults to prod.
- Auth gating: `AppConfig.appleSignInEnabled = isIOS && ENABLE_IOS_FIREBASE`
  (`lib/services/app_config.dart`); CI push releases set it true and verify the IPA.
- ASC snapshot 2026-07-17: versions = 1.0 (READY_FOR_SALE, build 2),
  "2.0.0(17)" (WAITING_FOR_REVIEW, build 17); TestFlight builds 11–18 all VALID.
