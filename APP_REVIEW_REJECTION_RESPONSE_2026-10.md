# Sign in with Apple — Apple-side registration fault (October 4, 2026)

Submission `09f8c7bc-5b5f-473f-a4f6-c69abf36f45b` (version 2.0.0, build 21) was rejected
on Jul 31 and Aug 6, 2026 under Guideline 2.1(a): "We were unable to sign up with Sign in
with Apple." Apple's own sheet shows **"Sign Up Not Completed"** and never returns a
credential to the app.

## Root cause: Apple's Sign in with Apple backend does not recognise `com.bojang.app`

This is not a signing, entitlement, Firebase or Dart problem. On 2026-10-04 the device log
of a failing attempt was captured live (`idevicesyslog`, iPhone 14 Pro, iOS 26.6.2,
TestFlight build 2.1.2 (46), Apple Account with no prior Bojang relationship):

```
19:07:04 akd  Client has default access level in SiwA entitlement
19:07:04 akd  Fetching developer team for client with ID: <private>
19:07:04 akd  Encountered error while fetching developer team: Error Domain=AKSQLError Code=-6003
19:07:04 akd  No applications were found with the provided Client ID: <private>
19:07:04 akd  Application is not requesting email for this authorization
19:07:11 akd  AppleIDAuthSupport: setError: 2:M2 missing (bad password)
19:07:11 akd  SRP authentication with server failed! Error: Error Domain=com.apple.AppleIDAuthSupport Code=2
19:07:12 AuthKitUIService  AlertHandler called with error: ... {Error Domain=AKAuthenticationServerError Code=-24000}
```

(The second attempt at 19:07:18–21 failed the same way.)

- The first line shows that the device read the signed `com.apple.developer.applesignin`
  entitlement from the app. Nothing on the client side is missing.
- `AKSQLError -6003` / "No applications were found with the provided Client ID", then the
  server ending the SRP exchange with `-24000` ("M2 missing"), is the exact signature in
  Apple Developer Forums thread
  [837986](https://developer.apple.com/forums/thread/837986) and its siblings (834106,
  838652, 841148, 843504, 843735, 844787). Many teams have reported it since July 2026,
  always on specific App IDs, while other App IDs in the same team keep working.
- Every resolved team in that thread got fixed **on Apple's side, with no client
  change**. "The same build simply started working once the registration was repaired."
  Developers who toggled the capability, re-minted profiles, re-created App IDs, or did the
  ASC API DELETE/POST (which we also did on Aug 15) saw no change.

This also explains why Drokpo (`app.drokpo.ios`, same team `W66Z24ZPWQ`, same iPhone, same
Apple Account) works and Bojang does not, even though their App ID settings are identical.

## Everything checked

| Check | Result |
|---|---|
| `CODE_SIGN_ENTITLEMENTS` | `Runner/Runner.entitlements` in Debug, Profile **and** Release; it contains `com.apple.developer.applesignin = [Default]` |
| Signed binary (build 46 IPA from the GitHub release) | `codesign -d --entitlements` shows `applesignin [Default]`, `W66Z24ZPWQ.com.bojang.app`, `beta-reports-active` |
| Embedded profile | "iOS Team Store Provisioning Profile: com.bojang.app", minted 2026-08-15 19:52 UTC (after the capability re-registration), grants `applesignin [Default]` |
| App ID `VKS273UBYR` | UNIVERSAL, `APPLE_ID_AUTH` = `PRIMARY_APP_CONSENT`, identical to Drokpo's working App ID |
| macOS | The ASC record's MAC_OS 1.0 version is an empty draft (no build), and it shares the same UNIVERSAL App ID, so there is no grouping to configure. The repo's `macos/` target still uses the template bundle ID `com.example.wordTrain`, which is unrelated to iOS |
| Bundle ID | `com.bojang.app` matches across Xcode, the IPA `Info.plist`, the bundled `GoogleService-Info.plist`, the Firebase iOS app and the ASC app `6752509504` |
| Firebase `apple.com` IdP | Enabled, `clientId = com.bojang.app`. That is correct for the native flow, which needs no Services ID or key |
| Nonce | SHA-256 of the raw nonce goes to Apple; the raw nonce goes to Firebase (`lib/services/apple_sign_in.dart`) |
| New-user path | A hidden or empty email falls back to username = uid and display name = "Learner". `/auth/sync` is always called, and a backend failure still lands in the app |
| iPad | The presentation anchor falls back to any window. The sheet *did* present on the reviewer's iPad, which confirms it |

## What has to happen at Apple (only the account holder can do this)

1. **File a Feedback Assistant report** at feedbackassistant.apple.com → Developer
   Technologies & SDKs → Sign in with Apple. Use the text below.
2. **Reply on forum thread 837986** with the team ID, the App ID and the FB number. Apple
   DTS has been collecting affected teams there.
3. **Open a Developer Support case** at developer.apple.com/contact → Development and
   Technical → Sign in with Apple, and quote the FB number.
4. When Apple says it is repaired, retest **build 46 as is**. No rebuild is needed.

### Feedback / support text

> Sign in with Apple fails for every user of our iOS app with "Sign Up Not Completed".
> Team ID W66Z24ZPWQ, App ID com.bojang.app (identifier resource VKS273UBYR), App Store app
> 6752509504. The App ID has Sign in with Apple enabled as a primary App ID. The signed
> TestFlight binary (2.1.2 build 46) and its App Store provisioning profile both carry
> com.apple.developer.applesignin = [Default]. The native ASAuthorizationController sheet
> presents, then the server rejects the request. The device log shows: "Encountered error
> while fetching developer team: AKSQLError -6003", "No applications were found with the
> provided Client ID", "AppleIDAuthSupport: setError: 2:M2 missing (bad password)", and
> AKAuthenticationServerError -24000. Reproduced on 2026-10-04 19:07 IST (13:37 UTC) on an
> iPhone 14 Pro, iOS 26.6.2. Another App ID in the same team (app.drokpo.ios) completes Sign
> in with Apple on the same device with the same Apple Account. This matches forum thread
> 837986. App Review has rejected our submission twice because of it (submission
> 09f8c7bc-5b5f-473f-a4f6-c69abf36f45b). Please repair the Sign in with Apple registration
> for com.bojang.app.

## Resubmission checklist (only after sign-up completes on a physical device)

1. ASC → Bojang → iOS version "2.0.0" → change the version number to **2.1.2** so that
   build 46 can be attached (the build's marketing version must match).
2. Attach build **2.1.2 (46)**.
3. Reply in the Resolution Center (text below) and resubmit.

> Sign in with Apple failed because of a server-side registration problem with our App ID
> on Apple's side (Feedback FB________), not because of the app. It has now been repaired
> and verified on iPhone and iPad with a new Apple Account. To test, tap "Sign in with
> Apple" on the first screen and continue with any Apple Account. No demo account is
> needed: Sign in with Apple and Google are the only account options, and "Continue
> without account" opens the full learning experience.
