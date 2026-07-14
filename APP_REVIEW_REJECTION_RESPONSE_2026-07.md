# Response to App Review Rejection — July 14, 2026

Submission ID: 9d579324-de12-474d-a7de-621fdbe29070
Version reviewed: 1.0.1 (10) — rejected on Guideline 4.8 (Login Services) and
Guideline 2.1 (demo account did not work).

## What was fixed in the app

- **Guideline 4.8:** Sign in with Apple added as an equivalent login option,
  shown above Google sign-in on the auth screen (iOS builds). It runs through
  Firebase Auth and the same backend `/auth/sync` flow as Google.
- **Guideline 2.1:** The Google demo account was removed from the review setup.
  The app needs no credentials: "Continue without account" unlocks all learning
  features, and reviewers can exercise account features with any Apple ID via
  Sign in with Apple.

## Steps to resubmit (manual, in App Store Connect)

1. Wait for build **2.0.0 (18)** to finish processing in TestFlight. (Build 17
   also has Sign in with Apple, but 18 additionally restores a way for
   signed-out users to reach the login screen from the Profile tab — use 18.)
2. In App Store Connect → Bojang → App Store tab → create/select the new
   version (2.0.0) and attach build 18.
3. App Information → App Review Information:
   - **Sign-in required: NO** (uncheck it / remove the demo credentials
     ta6tsering@gmail.com — this is what triggered the 2.1 rejection).
   - Paste the updated Review Notes from `APP_REVIEW_INFORMATION.md`.
4. Reply in the Resolution Center with the message below, then resubmit.

## Reply to paste in the Resolution Center

```
Hello,

Thank you for the review. We have addressed both issues in the new build
(version 2.0.0, build 18) that we are submitting with this reply.

Guideline 4.8 — Design — Login Services:
We have added Sign in with Apple as an equivalent login option. It is
displayed as the first login option on the sign-in screen, alongside Google
sign-in. As noted in the guideline, Sign in with Apple limits data collection
to name and email, lets users keep their email private via Hide My Email, and
does not collect app interactions for advertising.

Guideline 2.1 — Information Needed:
No demo account is required to review the app. Sign-in is entirely optional:
tapping "Continue without account" on the first screen gives full access to
every learning feature (lessons, quizzes, games, audio, and local progress
tracking). Signing in only adds cross-device sync of XP, streaks, and league
progress. To review those account features, please use Sign in with Apple with
any Apple ID — an account is created automatically on first sign-in. We have
removed the previous Google demo credentials from App Review Information, and
we apologize for the inconvenience they caused.

Thank you for your time.
```

## Infrastructure changes made alongside the app change (for the record)

- Apple identity provider enabled in Firebase Auth (project `bojang-backend`,
  audience `com.bojang.app`).
- `ios/Runner/Runner.entitlements` created with `com.apple.developer.applesignin`
  and wired into all Runner build configurations.
- `GoogleService-Info.plist` added to the Xcode Resources build phase (it was
  never bundled before, so Firebase could not initialize on iOS at runtime).
- `mobile-release.yml`: push releases now build with `ENABLE_IOS_FIREBASE=true`;
  CI ensures the SIGN_IN_WITH_APPLE capability on the App ID via the App Store
  Connect API and fails the release if the exported IPA is missing the
  entitlement or bundles the placeholder Firebase plist.
