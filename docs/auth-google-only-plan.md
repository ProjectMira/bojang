# Plan: Google-only sign-in + fix Google sign-in on TestFlight

Goal: the auth screen offers exactly two actions — **Continue with Google** and
**Continue without account** — and Google sign-in actually works in TestFlight
builds. Remove the "Email sign-in coming soon" button and the graduation-hat
icon; the branding is just the "Bojang" wordmark + tagline.

---

## Part 0 — Why Google sign-in fails on TestFlight (root cause, three layers)

The snackbar in the screenshot ("Google sign-in was cancelled or failed…") is
the `signInWithGoogle() == null` path. It is null because of layer 1; layers
2–3 would break it even after layer 1 is fixed.

1. **The feature is compile-time disabled on iOS.**
   [lib/services/app_config.dart:10](../lib/services/app_config.dart) gates
   Google sign-in behind `--dart-define=ENABLE_IOS_GOOGLE_SIGN_IN=true`.
   In [.github/workflows/mobile-release.yml](../.github/workflows/mobile-release.yml)
   push-triggered builds hardcode `enable_ios_google_sign_in="false"` (line ~118)
   and the `workflow_dispatch` input defaults to `false` (line ~52-56). So every
   TestFlight build ships with `_googleSignIn == null` →
   `GoogleAuthService.signInWithGoogle()` returns `null` immediately.

2. **No iOS OAuth client configuration reaches the app bundle.**
   [ios/Runner/GoogleService-Info.plist](../ios/Runner/GoogleService-Info.plist)
   contains `PLACEHOLDER_CLIENT_ID` / bundle `com.example.bojang`. CI overwrites
   it from the `GOOGLE_SERVICE_INFO_PLIST` secret when set, **but the file is
   not referenced anywhere in `ios/Runner.xcodeproj/project.pbxproj`** — it is
   never copied into the app bundle, so the `google_sign_in_ios` plugin cannot
   discover a client ID at runtime.

3. **`Info.plist` is missing the Google URL scheme.**
   [ios/Runner/Info.plist](../ios/Runner/Info.plist) has no
   `REVERSED_CLIENT_ID` entry under `CFBundleURLTypes` and no `GIDClientID`
   key, so even with a client ID the OAuth redirect back into the app cannot
   complete.

### Manual prerequisite (must be done by a human, before or alongside the code work)

- In the Firebase console (or Google Cloud console → Credentials), register an
  **iOS app / iOS OAuth client** for bundle ID **`com.bojang.app`** (the plist
  currently in the repo was generated for `com.example.bojang` — wrong).
- Note the resulting `CLIENT_ID` (ends `.apps.googleusercontent.com`) and
  `REVERSED_CLIENT_ID` (`com.googleusercontent.apps.…`).
- Update the `GOOGLE_SERVICE_INFO_PLIST` GitHub secret with the new plist
  (used by the existing "Restore Firebase iOS configuration" CI step and the
  bundle-ID check at workflow line ~461).

> OAuth iOS client IDs are not secrets — they ship inside every app binary and
> are extractable by anyone. It is standard practice to commit them in
> `Info.plist`. Only the plist-as-a-whole stays in the secret because it also
> carries the Firebase API key.

---

## Part 1 — iOS configuration fix

### 1.1 `ios/Runner/Info.plist`

- Add the Google client ID key (the `google_sign_in_ios` plugin reads this
  first, so the plist does **not** need to be added to the Xcode target for
  sign-in to work):

  ```xml
  <key>GIDClientID</key>
  <string>REAL_CLIENT_ID.apps.googleusercontent.com</string>
  ```

- Add a second dict to the existing `CFBundleURLTypes` array (keep the
  existing `com.bojang.app` entry):

  ```xml
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.REAL_REVERSED_CLIENT_ID_SUFFIX</string>
    </array>
  </dict>
  ```

- Use the real values from the manual prerequisite. If they are not available
  at implementation time, commit with clearly marked `TODO_CLIENT_ID`
  placeholders **and** add the CI guard in 1.3 so a build cannot ship them.

### 1.2 `lib/services/app_config.dart` + call sites

Google sign-in is now always on; remove the kill switch for it:

- Delete `googleSignInEnabled` from `AppConfig` (keep `firebaseEnabled` and its
  `ENABLE_IOS_FIREBASE` gate exactly as is — the Firebase token exchange in
  `GoogleAuthService._firebaseIdTokenFromGoogle` already degrades gracefully).
- In [lib/services/google_auth_service.dart:40-45](../lib/services/google_auth_service.dart),
  remove the `if (!AppConfig.googleSignInEnabled)` early-return block from
  `initialize()`. The web early-return stays.

### 1.3 `.github/workflows/mobile-release.yml`

- Remove the `enable_ios_google_sign_in` workflow input, its `prepare`-job
  output/env plumbing (lines ~52-56, ~87, ~105, ~118, ~130), and the
  `--dart-define "ENABLE_IOS_GOOGLE_SIGN_IN=…"` flag from the
  `flutter build ios` step (line ~514). Keep everything for
  `enable_ios_firebase` untouched.
- Update the secret guard (line ~404) so it only checks
  `enable_ios_firebase` for the `GOOGLE_SERVICE_INFO_PLIST` requirement.
- Add a new guard step in the iOS job, before the Flutter build: fail if
  `ios/Runner/Info.plist` still contains a placeholder client ID —
  `if grep -q 'TODO_CLIENT_ID\|PLACEHOLDER' ios/Runner/Info.plist; then exit 1; fi`
  (with an `::error::` message telling the operator to fill in the real
  Google iOS client ID).

### 1.4 Out of scope (note only, do not do now)

- Bundling `GoogleService-Info.plist` into the Xcode target is only needed for
  `Firebase.initializeApp()` (still gated off on iOS). Leave for a follow-up.
- Android Google sign-in additionally requires the Play App Signing SHA-1/SHA-256
  fingerprints registered in the same Firebase/Google Cloud project. Android
  releases are currently paused anyway (upload-key issue).

---

## Part 2 — Simplified auth screen (`lib/screens/auth_screen.dart`)

Final layout, top to bottom (all existing fade/slide animation, theming, and
`GoogleFonts.poppins(...).copyWith(fontFamilyFallback: ['Jomolhari'])` styling
conventions stay):

1. **Wordmark** — text `Bojang` (36, bold) + tagline `Practice Tibetan every day`.
   **Delete the 120×120 gradient circle with `Icons.school`** (lines 157-172).
2. **Card** — keep the card, slimmed to:
   - Title: `Save your progress`
   - One body line: `Sign in with Google to sync XP, streaks, and league progress across devices.`
   - The existing `GoogleSignInButton` widget from
     [lib/widgets/google_sign_in_button.dart](../lib/widgets/google_sign_in_button.dart)
     (real multicolor G logo + built-in loading state) wired to
     `_handleGoogleSignIn` with `isLoading: _isLoading`. This replaces the
     current `OutlinedButton.icon` with `Icons.g_mobiledata`.
3. **`Continue without account`** text button (unchanged behavior).

Removals:

- `_handleEmailAuth()` and the `Email sign-in coming soon` `OutlinedButton.icon`
  (lines 94-98, 246-253).
- `_buildGoogleSignInButton()` (replaced by the shared widget).
- The second card paragraph ("You can also continue without an account…") —
  the skip button below already says it.

Behavior kept as-is: success snackbar + 500 ms delay + `pushReplacement` to
`MainNavigationScreen`; null → "Google sign-in was cancelled or failed. You can
still continue without an account."; exception → existing error mapping.

### Testability change (required for Part 3)

`AuthScreen` currently hard-instantiates the `GoogleAuthService()` singleton,
so the mocks in the existing test file were never actually used. Add optional
constructor injection:

```dart
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.authService});
  final GoogleAuthService? authService;
  ...
}
// in state:
late final GoogleAuthService _googleAuthService =
    widget.authService ?? GoogleAuthService();
```

No call-site changes needed (`splash_screen.dart` keeps `const AuthScreen()`).

---

## Part 3 — Tests

### 3.1 Rewrite `test/screens/auth_screen_test.dart`

The current file is 100% stale — it tests an email/password form, "Sign Up"
toggle, and password visibility that don't exist in the screen anymore, and
its Provider-injected mocks are ignored by the widget. Replace wholesale.

Setup: keep `@GenerateMocks([GoogleAuthService, ApiService])`, build the widget
as `MaterialApp(home: AuthScreen(authService: mockGoogleAuthService))` (Provider
wrapper no longer needed). Regenerate mocks with
`dart run build_runner build --delete-conflicting-outputs`.
`GoogleFonts.config.allowRuntimeFetching = false;` in `setUpAll` if font
fetching flakes in CI.

Test cases:

1. **Branding**: finds one `Bojang` text and one `Practice Tibetan every day`;
   `find.byIcon(Icons.school)` finds nothing.
2. **Google-only**: finds one `GoogleSignInButton` / `Continue with Google`;
   finds no `Email sign-in coming soon`, no `Icons.mail_outline`, no
   `TextFormField` anywhere.
3. **Skip path**: finds `Continue without account`; tapping it navigates
   (assert via a `NavigatorObserver` mock or `find.byType(AuthScreen)` gone —
   note `MainNavigationScreen` may need its own service mocks to pump; if it
   drags in too many dependencies, assert with a mocked `NavigatorObserver`
   that `didReplace` fired instead of settling the destination screen).
4. **Sign-in success**: mock `signInWithGoogle()` → test `User`; tap button;
   verify called once; snackbar `Welcome Test User!` shown; after
   `pump(Duration(milliseconds: 600))` navigation replaced the screen.
5. **Sign-in cancelled/failed**: mock returns `null`; tap; snackbar containing
   `cancelled or failed` shown; still on `AuthScreen`.
6. **Sign-in throws**: mock throws `Exception('sign_in_failed …')`; snackbar
   containing `configuration issue` shown; no crash; loading state cleared
   (button enabled again).
7. **Loading state**: mock returns a delayed future; tap; while pending the
   button shows `Signing in...` (from `GoogleSignInButton`) and a second tap
   does not trigger a second `signInWithGoogle()` call.

### 3.2 `test/services/google_auth_service_test.dart` / `_simple_test.dart`

Check for assertions on `AppConfig.googleSignInEnabled` or the
initialize-skips-on-iOS behavior removed in 1.2 and update/delete those cases.
(Behavior change to cover: `initialize()` on non-web now always constructs
`GoogleSignIn` — if the existing tests exercise this, adjust expectations.)

### 3.3 `integration_test/auth_flow_test.dart`

Update stale expectations: remove `Learn Tibetan Language`, `Icons.school`,
`Welcome Back!`, `Sign Up` toggle, `Skip for now`; use
`Practice Tibetan every day`, `Continue with Google`,
`Continue without account`.

### 3.4 Untouched

`test/widgets/google_sign_in_button_test.dart` already covers the shared
button — leave as is.

---

## Part 4 — Verification checklist (in order)

1. `flutter analyze` — clean.
2. `dart run build_runner build --delete-conflicting-outputs` — mocks regenerate.
3. `flutter test` — all pass, including the rewritten auth screen suite.
4. Grep the repo for `ENABLE_IOS_GOOGLE_SIGN_IN`, `googleSignInEnabled`,
   `Email sign-in`, `Icons.school` (in lib/) — zero hits left.
5. Local device sanity run (`flutter run` on an iOS device/simulator with the
   real client ID in Info.plist): tap Continue with Google → account chooser
   appears → returns signed in.
6. Dispatch the Mobile Release workflow (iOS only) → install from TestFlight →
   Google sign-in completes end-to-end.

## Acceptance criteria

- Auth screen shows exactly: Bojang wordmark, tagline, "Save your progress"
  card with one description line + Google button, and "Continue without
  account". No graduation hat, no email button, no text fields.
- Google sign-in works on a TestFlight build without any workflow toggles.
- CI fails loudly if the Info.plist client ID is still a placeholder.
- `flutter test` green.
