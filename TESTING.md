# Testing Bojang before a TestFlight build

One command runs the whole end-to-end suite on the iOS Simulator against a
**local** backend and a **local** Firebase Auth emulator, so nothing is
written to production (no learners, events or progress in prod analytics):

```bash
ci/scripts/e2e.sh --backend ../bojang-backend
```

Results land in `build/e2e/<timestamp>/`:

| File | What |
|---|---|
| `report.md` | Crawler coverage table, accessibility results, screenshot flags |
| `shots/*.png` | Simulator screenshots: every journey step, every crawled route, every main screen per device and theme |
| `store/<device>/*.png` | The App Store set (home, picture and listening questions, games, streak) at 6.9" iPhone 1320×2868 and 13" iPad 2064×2752, status bar at 9:41 |
| `<test>.log` | Full `flutter test` output per test |
| `backend.log`, `emulator.log` | Local backend and Auth emulator |

Exit code 0 means everything passed.

## What it needs

- Xcode with an iOS Simulator runtime, Flutter (see `pubspec.yaml`).
- A checkout of **bojang-backend** (the branch the build ships with, e.g.
  `rel-avatar`) with a Python virtualenv at `functions/venv` that has
  `functions/requirements.txt` and `pytest` installed (or point
  `BOJANG_BACKEND_PY` at a python that does).
  `git worktree add <path> rel-avatar` is a convenient way to test a branch.
- `firebase` CLI (firebase-tools) and Java, for the Auth emulator.
- Optional: `functions/bojang_local.db` in the backend checkout (an old local
  SQLite with the vocabulary topics). Without it you only get the Basics
  course and the test fixtures, and the picture games have fewer topics.
  Override with `BOJANG_VOCAB_DB=<file>`.

## What runs

| Test | Covers |
|---|---|
| `integration_test/smoke_test.dart` | Backend reachable, never production, app starts, anonymous account |
| `integration_test/journeys_learning_test.dart` | Fresh-install onboarding (no notification prompt, Amdo selectable), Home opens on the path, lesson intro (auto-play, Hear all / Stop), quiz (two-choice first question, wrong → Continue, right auto-advances, Back → "Keep going?" both ways), lesson complete (beginner "Next lesson", reminder primer), Practice review |
| `integration_test/journeys_games_test.dart` | Every game in the Games tab: start, a move, finish or quit; Memory Match result buttons; offline / server down |
| `integration_test/journeys_profile_test.dart` | Name and picture sheet (drawn avatar, photo upload through a mocked picker), leaderboard card, full board (pinned own row, report / hide), city opt-in, every Settings toggle (10 AM reminder, reading help, voice, analytics opt-out...), email sign-up / sign-in / sign-out, delete account |
| `integration_test/crawler_test.dart` | Visits every main screen and taps every enabled tappable in the semantics tree. After each tap: no exception, no overflow, something changed or a route was pushed; then goes back. Coverage table in `report.md` |
| `integration_test/accessibility_test.dart` | `iOSTapTargetGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` on every main screen |
| `integration_test/screens_test.dart` | Screenshots of every main screen, light and dark, on iPhone SE, iPhone 16 Pro Max and iPad Pro 13"; flags overflow and text cut short |
| `integration_test/store_screenshots_test.dart` | App Store screenshots on the two sizes App Store Connect asks for (`E2E_STORE_DEVICES` to change) |

Run a subset by naming files:

```bash
ci/scripts/e2e.sh --backend ../bojang-backend integration_test/crawler_test.dart
```

Options: `--device <udid or name>` (default "iPhone 16 Pro Max"; pick one no
one else is using), `--out <dir>`, `E2E_SCREEN_DEVICES="name;name;..."` for
the screenshot devices.

### Several simulators at once

Start the services once, then run test files on different simulators:

```bash
ci/scripts/e2e_services.sh --backend ../bojang-backend
```

```bash
ci/scripts/e2e.sh --external-services --device "iPhone 16 Pro" integration_test/journeys_games_test.dart
```

Each run uses its own anonymous learner, and the "server down" switch is
per learner, so parallel runs don't affect each other. Run each in its own
checkout or worktree: `e2e.sh` swaps `ios/Runner/GoogleService-Info.plist`
while it runs.

## App Store screenshots

Every full run saves the App Store set to `build/e2e/<run>/store/`. On the
local backend the word pictures are solid-colour placeholders, so the picture
question and Listen & Tap shots are not publishable as they are. Either:

- put real pictures in a folder as `<level-id>/<english word>.jpg` (e.g.
  `vocab-fruits/apple.jpg`) and run with `BOJANG_MEDIA_DIR=<folder>`, or
- for the final set, use `ci/scripts/store_screenshots.sh <udid> <out>`,
  which reads the live backend's words and pictures (lessons and games
  only; it pumps screens directly and never signs in).

Only this set is meant for publishing; the `shots/` folder is for review.

## How it works

- **Backend** (`ci/e2e/local_backend.py`): the real FastAPI app from the
  backend checkout on a throwaway SQLite file, seeded with the
  `functions/tests/conftest.py` fixtures, the Basics course and dialogues
  from the backend's curriculum code, the vocabulary topics from
  `bojang_local.db`, 27 rival learners with XP this week, placeholder
  pictures and silent audio. `firebase_admin` is stubbed as in the backend
  tests; ID tokens are decoded without verification, so every emulator
  account is its own learner. Profile photos are stored on disk. Test-only
  endpoints: `/e2e/health`, `/e2e/xp`, `/e2e/outage`.
- **Auth**: the Firebase Auth emulator (`ci/e2e/firebase.json`, project
  `demo-bojang-e2e`). The app connects to it when built with
  `--dart-define=BOJANG_AUTH_EMULATOR=127.0.0.1:9099`.
- **App build flags** (set by `e2e.sh`): `BOJANG_E2E=true` (App Check off),
  `ENABLE_IOS_FIREBASE=true`, `BOJANG_API_BASE_URL=http://127.0.0.1:8787`.
  The smoke test fails if the base URL is the production one.
- **Firebase config**: `e2e.sh` writes well-formed dummy values into
  `ios/Runner/GoogleService-Info.plist` for the run and restores it on exit.
  Never commit it. Remote Config and Installations try Google with the dummy
  key and are refused; that is expected and harmless.
- **Single arch**: tests run with `flutter test <file> -d <udid>`, which builds
  for the simulator's architecture only. `flutter build ios --simulator` fails
  with the lipo step on Xcode 27.
- **Native prompts**: the suite uses plain `integration_test`. The
  notification, push, location, geocoding and photo picker plugins are
  answered by platform-channel spies (`integration_test/support/harness.dart`)
  that also record what was asked. That is how "no notification prompt
  during onboarding" is asserted.
- **Screenshots**: tests print `SHOT:<name>`; `e2e.sh` saves the simulator
  screen at each marker.

### What it cannot reach

- Real iOS permission dialogs and their system UI (the spies answer instead;
  Patrol would be needed to tap the real ones).
- Real push delivery (the 10 AM reminder is sent by the server; the suite
  checks the switch, the stored preference and the device registration call).
- Sign in with Apple and Google sign-in (need the real providers).
- Real App Check, Crashlytics, Analytics and Remote Config (off or refused
  with the dummy config).
- Audio output (clips are silent fixtures; the crawler counts a play call as
  an effect).
- External links (Safari, App Store, share sheet) are not followed.

## Unit and widget tests

`flutter test` runs `test/`. Many of those tests are stale (old mocks) and
fail; they are separate from this suite.
