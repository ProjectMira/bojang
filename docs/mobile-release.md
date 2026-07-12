# Mobile release runbook

The `Mobile Release` GitHub Actions workflow builds and publishes Android to
Google Play and iOS to TestFlight with one shared Flutter version.

The normal release path is:

1. Calculate a version from `pubspec.yaml` and the committed version history.
2. Run static analysis on application code and the stable model test suite.
3. Build and upload the selected platforms.
4. As soon as at least one store accepts the upload, commit the version to
   `pubspec.yaml` and create an annotated `v<version>-build.<number>` tag. A
   store that consumed a build number must never see it again, so a failure on
   the other platform does not block the version commit; the failed platform
   simply ships with the next build number.

Unless `AUTO_MOBILE_RELEASE_PAUSED` is set to `true`, every push to `main`
creates a build-only version increment, uploads Android to the Play Internal
track and iOS to TestFlight, then commits the shared version and creates an
annotated tag. Setting the repository variable `ANDROID_RELEASE_PAUSED` to
`true` makes push-triggered releases skip Android (iOS-only releases) while a
Play-side blocker such as an upload-key reset is pending; manual dispatch
ignores it.
Manual dispatch remains available for version overrides and partial-release
recovery. The release jobs use the `mobile-production` GitHub Environment.

## Fixed application identifiers

- Android: `com.projectmira.bojang`
- iOS: `com.bojang.app`

These values must exactly match Google Play, Apple Developer, App Store Connect,
and Firebase. Changing a published Android package name creates a different app.

## GitHub environment

Create an environment at **Settings > Environments > New environment** named
`mobile-production`. Restrict it to `main` and add a required reviewer when the
repository plan supports environment approvals.

Create these environment variables:

| Variable | Value |
| --- | --- |
| `ANDROID_PACKAGE_NAME` | `com.projectmira.bojang` |
| `ANDROID_UPLOAD_CERT_SHA1` | SHA-1 of the upload certificate Google Play expects; the workflow fails fast when the keystore secret does not match. Update it after any upload-key reset. |
| `IOS_BUNDLE_ID` | `com.bojang.app` |
| `APPLE_TEAM_ID` | Apple Developer team ID |
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect team API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect API issuer ID |

Automatic releases on pushes to `main` are enabled by default. To pause them,
create the repository-level variable `AUTO_MOBILE_RELEASE_PAUSED` and set it to
`true`; remove it or set any other value to re-enable. The legacy
`AUTO_MOBILE_RELEASE_ENABLED` variable is no longer read and can be deleted.

The IDs may be stored as secrets instead for compatibility, but the private key,
keystore, passwords, and service-account JSON must always be secrets.

Create these environment secrets:

| Secret | Contents |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded Android upload keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Upload keystore password |
| `ANDROID_KEY_ALIAS` | Upload-key alias |
| `ANDROID_KEY_PASSWORD` | Upload-key password |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Full Google service-account JSON |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | Exact App Store Connect `.p8` contents |
| `GOOGLE_SERVICE_INFO_PLIST` | Correct iOS Firebase plist; optional while iOS Firebase is disabled |
| `RELEASE_GITHUB_TOKEN` | Token used only for the final version commit/tag when the organization forces read-only workflow tokens |

The ProjectMira organization currently forces the standard workflow token to be
read-only. The `mobile-production` environment therefore contains a release token
for the final version commit and tag. The environment is restricted to `main` and
does not require recurring manual approval, so push releases are fully automatic.
Replace the current token with a fine-grained token limited to the
`ProjectMira/bojang` repository and Contents read/write when convenient.

## Android setup

### 1. Create or recover the upload key

For a new Play app, create an upload key and store an offline backup:

```sh
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload
```

If the app already exists, use its current upload key. Do not create a different
key unless Google Play has completed an upload-key reset.

Store it in the GitHub Environment:

```sh
openssl base64 -A -in upload-keystore.jks \
  | gh secret set ANDROID_KEYSTORE_BASE64 --env mobile-production
gh secret set ANDROID_KEYSTORE_PASSWORD --env mobile-production
gh secret set ANDROID_KEY_ALIAS --env mobile-production
gh secret set ANDROID_KEY_PASSWORD --env mobile-production
```

The last three commands prompt for their values without putting them in shell
history.

### Upload key mismatch recovery

Google Play permanently associates the app with the upload certificate of the
first uploaded bundle and rejects bundles signed with any other key:

```
The Android App Bundle was signed with the wrong key.
Found: SHA1: <certificate of the keystore in ANDROID_KEYSTORE_BASE64>
expected: SHA1: <upload certificate registered with Google Play>
```

Bojang hit this on 2026-07-11. Play builds 1–6 (including the live production
release 1.0.0) were uploaded with an upload key whose certificate SHA-1 is
`C1:16:42:7E:15:40:DF:9F:CF:A6:80:F9:7C:01:96:E4:C8:D9:50:F6`. That keystore is
not on this machine and was never committed. The keystore generated during CI
setup on 2026-07-11 (backed up at `~/Documents/keys/bojang/upload-keystore.jks`,
certificate SHA-1 `86:93:40:C6:88:1E:5A:E4:31:21:6B:9D:36:70:C5:FB:52:F5:3A:AC`)
is a different key, so Play rejects every CI upload.

Two ways out:

1. **Recover the original keystore.** Check the machine and backups used to
   upload Play builds 1–6 (before 2026-07-11). If found, re-encode it into
   `ANDROID_KEYSTORE_BASE64` with its alias and passwords, and delete the
   unused 2026-07-11 keystore to avoid future confusion.
2. **Reset the upload key.** In Play Console open
   **Test and release > Setup > App signing** (App integrity), choose
   **Request upload key reset**, select a reason (key lost), and upload
   `~/Documents/keys/bojang/upload-certificate.pem`. Google reviews the
   request and shows the date the new key becomes usable (typically about
   48 hours). After the reset takes effect, update the repository variable
   `ANDROID_UPLOAD_CERT_SHA1` to
   `86:93:40:C6:88:1E:5A:E4:31:21:6B:9D:36:70:C5:FB:52:F5:3A:AC`. The GitHub
   secrets already contain the new keystore, so no secret changes are needed.

An upload-key reset only changes the key used to sign uploads; Play App
Signing re-signs bundles for devices, so installed users are unaffected.

While this stayed unresolved, automatic releases were briefly paused with the
repository variable `AUTO_MOBILE_RELEASE_PAUSED=true`. On 2026-07-12 automatic
releases were resumed for iOS only: `AUTO_MOBILE_RELEASE_PAUSED` was cleared
and `ANDROID_RELEASE_PAUSED=true` now makes push-triggered releases skip the
Android job. iOS `1.0.1` build `8` (uploaded to TestFlight by run 15 without a
version commit) was recorded directly in `pubspec.yaml`, so numbering resumes
at build 9.

Once the Play upload-key reset takes effect:

1. Update the repository variable `ANDROID_UPLOAD_CERT_SHA1` to the new upload
   certificate SHA-1 (see above).
2. Delete the `ANDROID_RELEASE_PAUSED` repository variable.

The next push to `main` then releases both platforms again. Play jumps from
versionCode 6 to the current build number; gaps are fine because Play only
requires versionCode to increase.

### 2. Configure Google Play

1. Create the Play Console application with package `com.projectmira.bojang`.
2. Accept Play App Signing and all required developer agreements.
3. Complete the required store, policy, content, and data-safety setup.
4. If this is the first release and the Publishing API rejects it, upload the
   first signed AAB manually to Internal testing.
5. Invite `github-play-publisher@bojang-backend.iam.gserviceaccount.com` under
   **Play Console > Users and permissions**.
6. Give it app-level permission to manage testing-track releases for Bojang.

The Google Play Android Developer API is already enabled in the
`bojang-backend` Google Cloud project. The service-account JSON is backed up at
`~/Documents/keys/bojang/google-play-service-account.json` and stored in the
GitHub `mobile-production` environment.

If the key is rotated later, update GitHub with:

```sh
gh secret set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON \
  --env mobile-production < play-service-account.json
```

### 3. Configure Firebase and Google Sign-In

Register `com.projectmira.bojang` in Firebase. Add the SHA-1 and SHA-256
fingerprints for both:

- the upload certificate used by GitHub Actions;
- the Google Play app-signing certificate shown under Play App Signing.

The upload certificate can be inspected with:

```sh
keytool -list -v -keystore upload-keystore.jks -alias upload
```

The Bojang upload key generated during setup is backed up at
`~/Documents/keys/bojang/upload-keystore.jks`, with its public certificate at
`~/Documents/keys/bojang/upload-certificate.pem`. Its passwords are stored in
macOS Keychain under `bojang-android-keystore-password` and
`bojang-android-key-password` for account `ProjectMira/bojang`.

The project does not currently apply the Android Google Services Gradle plugin or
contain `android/app/google-services.json`. Firebase on Android should be treated
as a separate configuration task before depending on it in a store build.

## iOS setup

1. Maintain an active Apple Developer Program membership.
2. Register `com.bojang.app` under Certificates, Identifiers & Profiles.
3. Create the App Store Connect app using that bundle ID.
4. Accept all pending Apple agreements.
5. Have the Account Holder request App Store Connect API access if it is not
   already enabled.
6. Generate a team API key with sufficient upload and signing access.
7. Download its `.p8` file. Apple only allows this download once.
8. Store the key:

```sh
gh secret set APP_STORE_CONNECT_API_PRIVATE_KEY \
  --env mobile-production < AuthKey_KEYID.p8
```

The workflow normalizes and cryptographically validates the `.p8` before asking
Xcode to sign the archive.

### Firebase and Google Sign-In on iOS

The tracked `ios/Runner/GoogleService-Info.plist` currently belongs to a different
bundle ID. Leave the workflow's iOS Firebase and Google Sign-In inputs disabled
until Firebase contains an Apple app for `com.bojang.app`.

After registering the correct app:

1. Download its `GoogleService-Info.plist`.
2. Confirm `BUNDLE_ID` is `com.bojang.app`.
3. Store it in GitHub:

```sh
gh secret set GOOGLE_SERVICE_INFO_PLIST \
  --env mobile-production < GoogleService-Info.plist
```

4. Update `CFBundleURLSchemes` in `ios/Runner/Info.plist` to the plist's
   `REVERSED_CLIENT_ID` before enabling Google Sign-In.

The workflow validates the restored plist's bundle ID before building.

## Version rules

Flutter versions use `MAJOR.MINOR.PATCH+BUILD`. Android uses the build as its
global `versionCode`; therefore the number must never go backwards. The workflow
scans the committed history and defaults to one above the greatest committed
build number. It cannot see unpublished or manually uploaded store builds.

Before the first automated release, check the greatest build/version code in both
stores. Supply an explicit `build_number` greater than both if necessary.

Example:

- Flutter version: `1.0.1+7`
- Git tag: `v1.0.1-build.7`

## Running a release

### Automatic releases

A normal push to `main` is sufficient unless the repository variable
`AUTO_MOBILE_RELEASE_PAUSED` is set to `true`. Push releases keep the current marketing
version, increment the build number, publish both test builds, and create a tag
such as `v1.0.1-build.7`. The bot's follow-up commit only changes `pubspec.yaml`
and is excluded from the push trigger, preventing a release loop.

### Manual releases

1. Ensure the intended source is committed and pushed to `main`.
2. Open **Actions > Mobile Release > Run workflow**.
3. Select `main`.
4. Choose the version bump.
5. For the first run, provide an explicit safe build number.
6. Leave both platforms selected for a normal release.
7. Keep the Android track on `internal` until the pipeline is proven.
8. Keep the iOS Firebase options disabled until the plist and URL scheme are fixed.
9. Approve the `mobile-production` deployment when prompted.
10. Confirm the TestFlight and Internal testing builds have matching versions.

The broader historical test suite currently contains compile-time failures, so
the release gate runs `flutter analyze lib --no-fatal-infos --no-fatal-warnings`
and `flutter test test/models`. Expand the gate to the full suite after those
legacy test failures are repaired.

## Partial-release recovery

Apple and Google uploads cannot be transactional. One platform can accept a build
while the other fails. When this happens, the workflow commits and tags the
version anyway: the successful store consumed the build number, so it must be
recorded to keep numbering monotonic. The failed platform misses that build and
ships with the next release; build-number gaps are acceptable on both stores.

Recovery is therefore automatic in the common case — push again (or dispatch
manually) once the failure cause is fixed, and the next build number goes out
to both stores.

Manual recovery is only needed when a store accepted an upload but the
finalize job itself failed (for example, `main` moved during the release). In
that case apply the release version from the **Prepare version** summary to
`pubspec.yaml` on the new head and create the tag manually. Never reuse a
build number for a different binary.

## Credential rotation

- Revoke and replace a compromised App Store Connect key immediately.
- Request an upload-key reset through Play Console if the Android upload key is
  lost or compromised.
- Rotate the Google service-account JSON and remove the old key.
- Keep offline backups of the Android upload keystore and Apple `.p8` outside the
  repository and outside the developer accounts that use them.
