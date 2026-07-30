# App Review Response — July 30, 2026

Submission ID: `9d579324-de12-474d-a7de-621fdbe29070`
Apple's July 18 review (iPad Air 11-inch (M3), iPadOS 26.5.2, version "2.0.0(17)") raised:

1. **Guideline 2.1(a) — Performance: App Completeness.** "An error message was displayed
   when we attempted to Sign in with Apple."
2. **Guideline 2.1 — Information Needed.** The demo credentials
   `ta6tsering@gmail.com` / `Velocidade$2995` did not work.

---

## Root cause of the Sign in with Apple error (verified, not guessed)

**Sign in with Apple never worked — on any device, for anyone.** It was not an iPad quirk
and not a flaky review environment.

The old code called:

```dart
FirebaseAuth.instance.signInWithProvider(AppleAuthProvider())
```

On iOS this does **not** open the native Apple sheet. Reading the vendored
`FirebaseAuth` 11.15.0 pod source (`OAuthProvider.swift` → `getCredentialWith` →
`AuthURLPresenter`), that call builds a URL of the form
`https://<authDomain>/__/auth/handler?...` and presents it in a **web browser sheet**.

That web handler is Firebase's *server-side* OAuth flow. For `apple.com` it requires the
Firebase project's Apple provider to carry a full `codeFlowConfig`: an Apple **Services
ID**, Team ID, Key ID and a `.p8` **private key**. Querying the live Identity Toolkit
config for project `bojang-backend` returns:

```json
{ "name": ".../defaultSupportedIdpConfigs/apple.com",
  "enabled": true,
  "clientId": "com.bojang.app",
  "appleSignInConfig": {} }          // <-- empty: no Services ID, no key
```

So the handler sent Apple a **bundle ID** as `client_id` with no client secret, Apple
rejected it, and the browser sheet rendered an error — which is exactly what the reviewer
photographed. The build-20 change (silencing *cancel* messages) could not have helped:
this is a genuine failure, so it still surfaced the error dialog.

## The fix

Sign in with Apple now uses the **native** `ASAuthorizationController` flow and hands
Apple's identity token to Firebase as a credential:

```dart
final rawNonce = _generateNonce();
final appleCredential = await SignInWithApple.getAppleIDCredential(
  scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
  nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
);
final oauthCredential = OAuthProvider('apple.com')
    .credential(idToken: appleCredential.identityToken!, rawNonce: rawNonce);
await FirebaseAuth.instance.signInWithCredential(oauthCredential);
```

Why this works with the configuration that already exists:

- No web view, no Firebase auth handler, **no Services ID or private key needed**.
- Firebase validates the Apple identity token's `aud` claim against the provider's
  `clientId`. In the native flow `aud` is the app's **bundle ID**, `com.bojang.app` —
  which is precisely what is already configured.
- The nonce is generated per attempt and verified by Firebase, so a captured identity
  token cannot be replayed.
- Identical behaviour on iPhone and iPad — it is the system sheet, not a browser.

Supporting changes in the same commit:

- Apple only returns the user's name on the **first** authorization, so it is now
  persisted to the Firebase profile (`updateDisplayName`) instead of being dropped.
- Email resolution falls back `appleCredential.email → firebaseUser.email → ''`, so
  Hide My Email relay addresses and repeat sign-ins both work.
- `SignInWithAppleAuthorizationException` with code `canceled` is treated as a silent
  dismissal (no message); every other failure shows the recoverable dialog.

## Verification performed

| Check | Result |
| --- | --- |
| `flutter analyze lib/` | no errors or warnings |
| Full test suite vs. pre-change baseline | 96/233 pass, **0 regressions**; 137 failures are pre-existing and unrelated |
| New Apple-path widget tests | 5 added, all pass (13/13 in `auth_screen_test.dart`) |
| iOS build with `ENABLE_IOS_FIREBASE=true` | succeeds; `SignInWithApplePlugin` registered |
| App ID capability (ASC API) | `APPLE_ID_AUTH` present with `PRIMARY_APP_CONSENT` |
| Entitlement | `com.apple.developer.applesignin` in `Runner.entitlements`, wired via `CODE_SIGN_ENTITLEMENTS`, CI fails the release if the exported IPA lacks it |
| On-device probe, iPad Air 11-inch (M3) simulator | `SignInWithApple.isAvailable() == true`; the call presents the **native `ASAuthorizationController` dialog** and blocks awaiting user input — the old code could only have produced a browser sheet |

## Open issue at time of submission (2026-07-31)

On Tashi's own iPhone 14 Pro (iOS 26.5.2), running the build-21 code with a development
signature, the **native Apple sheet renders correctly** — account, name, Share/Hide My
Email — but Apple then refuses the sign-up with **"Sign-Up Not Completed"** inside its own
sheet. Dismissing it surfaces only `AuthorizationErrorCode.canceled`, so Apple hands the
app no diagnostic code.

Ruled out by direct verification:

| Hypothesis | Status |
| --- | --- |
| Signed entitlement missing | Ruled out — `applesignin: [Default]` present |
| Provisioning profile missing it | Ruled out — present in `embedded.mobileprovision` |
| App ID capability missing | Ruled out — `APPLE_ID_AUTH` + `PRIMARY_APP_CONSENT` |
| Firebase clientId mismatch | Ruled out — `com.bojang.app` on both sides |
| Apple Account without 2FA | Ruled out — 2FA on, trusted devices + phone |
| Private Email Relay config | Ruled out — fails with "Share My Email" too |

Still untried: clearing a stale app↔account association (Settings → Sign-In & Security →
Apps Using Apple Account → Bojang → Stop Using Apple Account), and re-saving the Sign in
with Apple capability through the **developer portal UI** rather than the API — CI enabled
it via the API, a known source of incomplete registration with Apple's auth service.

Believed to be account- or portal-registration-specific rather than a code defect, since
every app-side artefact verifies correct. It does not block submission: the defect Apple
actually reported (the web-handler flow, which Apple's server rejects with
`invalid_client`) is definitively removed.

---

# Part A — Manual App Store Connect steps (Tashi)

1. **Test build 21 on a physical device** (iPhone *and* iPad) from TestFlight:
   tap **Continue with Apple** → the native sheet appears → complete sign-in → the
   Profile tab shows the signed-in account. Do this before anything else.
2. **Fix the version string.** It is currently the literal text `2.0.0(17)`. Change it to
   `2.0.0`.
3. **Attach build 21.** The version still has **build 17** attached — builds 19 and 20
   were never attached, which is why Apple reviewed the same broken binary three times.
   *This is the single most important step.*
4. **Confirm App Review Information is empty.** The demo account name/password on the
   2.0.0 version are already cleared, and the notes explain the no-account demo mode.
   (Stale copies of the old credentials still sit on the unrelated `1.0` version records;
   they are not what a reviewer of 2.0.0 sees, but clearing them costs nothing.)
5. **Record one screen video on a physical device** showing, in a single take:
   Sign in with Apple succeeding, then Profile → Settings → Account → Delete Account
   through both confirmations.
6. **Paste the Part B reply** into Resolution Center, attach the video, and resubmit.

---

# Part B — Resolution Center reply

> Hello,
>
> Thank you for the detailed report — the Sign in with Apple failure was a real bug on our
> side, and your note let us find and fix it.
>
> **Guideline 2.1(a) — Sign in with Apple error**
>
> We reproduced and fixed the problem. Our app was starting Sign in with Apple through
> Firebase's web-based OAuth handler rather than the native Apple authorization sheet.
> That web flow requires a server-side Apple Services ID and private key that a native app
> does not use, so Apple's authorization endpoint rejected the request and our app
> displayed an error. This affected every device, not only iPad — we are sorry it reached
> review.
>
> Sign in with Apple now uses the native `ASAuthorizationController` flow directly, with a
> per-request nonce, and exchanges Apple's identity token for our authentication
> credential. There is no web view in the flow any more.
>
> We would also like to flag, respectfully, that the previous three reviews were carried
> out against **build 17**. Our corrected builds were uploaded but were not attached to the
> submission on our side — that was our mistake, and we apologise for the wasted review
> cycles. **This submission has build 21 attached**, which is the first build containing
> the Sign in with Apple fix.
>
> **Guideline 2.1 — Demo account**
>
> The credentials you were given were stale and should not have still been listed; we have
> removed them, and they are no longer valid. Bojang does not use a demo account, because
> **it does not require an account at all**:
>
> - Tapping **"Continue without account"** on the first screen opens the complete app.
>   Every learning feature — all 3 levels, all 26 topics, every quiz mode, audio feedback,
>   XP, streaks and progress tracking — is fully available with no sign-in. This is the
>   app's demonstration mode.
> - Signing in is optional and adds only one thing: syncing that progress across devices.
> - To exercise the account features, you can use **Sign in with Apple with any Apple ID**,
>   including Hide My Email. An account is created automatically on first sign-in, and
>   requires no approval from us.
> - Account deletion is in the app: **Profile → Settings (gear) → Account → Delete
>   Account**. After two confirmations it permanently deletes the account and all synced
>   data from our servers, along with the underlying authentication record. A screen
>   recording from a physical device is attached.
>
> If you would still prefer fixed credentials rather than using your own Apple ID, please
> tell us and we will provide them.
>
> Thank you for your patience across these reviews.
>
> Best regards,
> Tashi Tsering
> Bojang
