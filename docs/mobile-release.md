# Mobile release runbook

The `Mobile Release` GitHub Actions workflow builds and publishes Android to
Google Play and iOS to TestFlight with one shared Flutter version.

The normal release path is:

1. Decide the next marketing version from the commits landed since the last
   release tag, write it to `pubspec.yaml`, and commit it back to `main` with
   `[skip ci]`. The build number is `github.run_number` plus the optional
   `BUILD_NUMBER_OFFSET` repository variable — it is never read back out of
   git, so it always increases and a failed run cannot strand one.
2. Run static analysis on application code and the stable model test suite.
3. Build and upload the selected platforms, from the commit carrying the
   bumped version.
4. As soon as at least one store accepts the upload, push the annotated
   `v<version>-build.<number>` tag and publish a GitHub release with the
   build artifacts.

Unless `AUTO_MOBILE_RELEASE_PAUSED` is set to `true`, every push to `main`
releases: it bumps the marketing version, uploads Android to the Play Internal
track and iOS to TestFlight, then tags the release. Setting the repository variable `ANDROID_RELEASE_PAUSED` to
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
| `GOOGLE_SERVICE_INFO_PLIST` | Correct iOS Firebase plist for `com.bojang.app`; required — Sign in with Apple depends on it |
| `RELEASE_GITHUB_TOKEN` | Token used to push the version bump and the release tag, because the organization forces read-only workflow tokens |

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

iOS Firebase is **enabled on every push-triggered release** and must stay that
way: Sign in with Apple (App Store guideline 4.8) and backend account sync both
run through it. The tracked `ios/Runner/GoogleService-Info.plist` is a
deliberate placeholder — the repository is public — and CI overwrites it from
the `GOOGLE_SERVICE_INFO_PLIST` secret, verifying the bundle ID before building
and failing the release if the placeholder reaches the IPA.

If the plist ever needs replacing:

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

Flutter versions use `MAJOR.MINOR.PATCH+BUILD`.

**Marketing version** (`MAJOR.MINOR.PATCH`) is decided by
`ci/scripts/bump_version.sh` from the commit subjects since the last `v*` tag:

| Commit landed since the last release | Bump |
| --- | --- |
| `feat:` / `feat(scope):`, or a merged `feat/*` branch | minor |
| any `type!:` subject, a `BREAKING CHANGE:` footer, or a merged `breaking/*` branch | major |
| anything else — `fix:`, `chore:`, plain prose | patch |

There is no "no bump" outcome, so the version always advances. A manual
dispatch can override the level (`version_bump`) or set an exact version
(`version`). If a run commits a bump and then fails before tagging, the next
run reuses that pending version instead of bumping again.

**Build number** is `github.run_number + BUILD_NUMBER_OFFSET` (the repository
variable defaults to 0). Android uses it as its global `versionCode`, so it
must never go backwards — the run counter guarantees that without consulting
git or the stores. The offset exists to jump the counter above build numbers
consumed by the old history-scanning scheme, or by a manual upload.

The `+BUILD` value committed in `pubspec.yaml` is a leftover placeholder; CI
passes the real number via `--build-number` and never reads it back.

Example:

- Flutter version: `2.0.1+38`
- Git tag: `v2.0.1-build.38`

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
4. Leave `version_bump` on `auto` to derive the bump from the commits, or pick
   a level to force one. `version` sets an exact marketing version.
5. Leave both platforms selected for a normal release.
6. Keep the Android track on `internal` until the pipeline is proven.
7. Leave iOS Firebase enabled — Sign in with Apple does not work without it.
8. Approve the `mobile-production` deployment if prompted.
9. Confirm the TestFlight and Internal testing builds have matching versions.

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

A re-run of a failed run is also safe: it keeps the same run number, and the
iOS upload step checks App Store Connect for that build first and skips the
upload if it is already there.

Manual recovery should no longer be necessary. The version is committed before
the builds start rather than after they finish, so a store upload can never
succeed against a version that was not recorded, and build numbers are not
derived from anything a failed run could leave behind.

## Credential rotation

- Revoke and replace a compromised App Store Connect key immediately.
- Request an upload-key reset through Play Console if the Android upload key is
  lost or compromised.
- Rotate the Google service-account JSON and remove the old key.
- Keep offline backups of the Android upload keystore and Apple `.p8` outside the
  repository and outside the developer accounts that use them.
