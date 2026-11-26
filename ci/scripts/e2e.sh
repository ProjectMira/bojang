#!/usr/bin/env bash
# End-to-end suite on the iOS Simulator, against a local backend.
#
#   ci/scripts/e2e.sh [--device <udid|name>] [--backend <bojang-backend dir>]
#                     [--out <dir>] [test files...]
#
# With no test files it runs every integration_test/*_test.dart that belongs
# to the suite (journeys, crawler, accessibility, screenshots).
#
# What it does:
#   1. Starts the FastAPI backend from a bojang-backend checkout on SQLite
#      with seeded content (ci/e2e/local_backend.py) on 127.0.0.1:8787.
#   2. Starts the Firebase Auth emulator (ci/e2e/firebase.json) on 9099.
#   3. Swaps ios/Runner/GoogleService-Info.plist for well-formed dummy
#      values (project demo-bojang-e2e) and restores it on exit.
#   4. Runs each test with `flutter test -d <udid>` (single arch; avoids the
#      lipo failure of `flutter build ios --simulator` on Xcode 27) and
#      saves a simulator screenshot at every "SHOT:<name>" the tests print.
#
# Environment: BOJANG_BACKEND (backend checkout, default ../bojang-backend
# next to this repo), BOJANG_BACKEND_PY (python with the backend's
# requirements, default <backend>/functions/venv/bin/python).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEVICE=""
BACKEND="${BOJANG_BACKEND:-}"
OUT="$ROOT/build/e2e"
TESTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --backend) BACKEND="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) TESTS+=("$1"); shift ;;
  esac
done

if [ -z "$BACKEND" ]; then
  for c in "$ROOT/../bojang-backend" "$ROOT/../../../../bojang-backend"; do
    [ -d "$c/functions" ] && BACKEND="$(cd "$c" && pwd)" && break
  done
fi
[ -d "$BACKEND/functions" ] || { echo "backend checkout not found; pass --backend"; exit 2; }
PY="${BOJANG_BACKEND_PY:-$BACKEND/functions/venv/bin/python}"
[ -x "$PY" ] || PY="$(git -C "$BACKEND" rev-parse --path-format=absolute --git-common-dir)/../functions/venv/bin/python"

if [ -z "$DEVICE" ]; then
  DEVICE="$(xcrun simctl list devices available | grep -m1 'iPhone 16 Pro Max' | grep -oE '[0-9A-F-]{36}')"
elif ! [[ "$DEVICE" =~ ^[0-9A-F-]{36}$ ]]; then
  DEVICE="$(xcrun simctl list devices available | grep -m1 "$DEVICE (" | grep -oE '[0-9A-F-]{36}')"
fi
[ -n "$DEVICE" ] || { echo "no simulator found"; exit 2; }
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null

if [ ${#TESTS[@]} -eq 0 ]; then
  TESTS=(integration_test/smoke_test.dart integration_test/journeys_test.dart
         integration_test/crawler_test.dart integration_test/accessibility_test.dart
         integration_test/screens_test.dart)
fi

RUN="$OUT/$(date +%Y%m%d-%H%M%S)"
STATE="$RUN/state"
mkdir -p "$RUN/shots" "$STATE"
PLIST="$ROOT/ios/Runner/GoogleService-Info.plist"
PIDS=()

cleanup() {
  git -C "$ROOT" checkout -- ios/Runner/GoogleService-Info.plist 2>/dev/null || true
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done
  # the emulator forks a java process
  pkill -f "firebase.*emulators:start.*demo-bojang-e2e" 2>/dev/null || true
  pkill -f "cloud-firestore-emulator|firebase-tools.*auth" 2>/dev/null || true
  xcrun simctl status_bar "$DEVICE" clear 2>/dev/null || true
}
trap cleanup EXIT

wait_http() { # url seconds
  for _ in $(seq 1 "$2"); do curl -fs "$1" >/dev/null 2>&1 && return 0; sleep 1; done
  return 1
}

echo "backend: $BACKEND  device: $DEVICE  out: $RUN"
"$PY" "$ROOT/ci/e2e/local_backend.py" --backend "$BACKEND/functions" --state-dir "$STATE" \
  --vocab-db "${BOJANG_VOCAB_DB:-$(git -C "$BACKEND" rev-parse --path-format=absolute --git-common-dir)/../functions/bojang_local.db}" \
  >"$RUN/backend.log" 2>&1 &
PIDS+=($!)
(cd "$ROOT/ci/e2e" && firebase emulators:start --only auth --project demo-bojang-e2e \
  --config firebase.json >"$RUN/emulator.log" 2>&1) &
PIDS+=($!)
wait_http http://127.0.0.1:8787/e2e/health 90 || { tail -30 "$RUN/backend.log"; exit 1; }
wait_http http://127.0.0.1:9099/ 90 || { tail -30 "$RUN/emulator.log"; exit 1; }

plutil -replace GOOGLE_APP_ID -string "1:123456789012:ios:0123456789abcdef012345" "$PLIST"
plutil -replace API_KEY -string "AIzaSyA0000000000000000000000000000000X" "$PLIST"
plutil -replace BUNDLE_ID -string "com.bojang.app" "$PLIST"
plutil -replace PROJECT_ID -string "demo-bojang-e2e" "$PLIST"
plutil -replace GCM_SENDER_ID -string "123456789012" "$PLIST"
plutil -replace STORAGE_BUCKET -string "demo-bojang-e2e.appspot.com" "$PLIST"

xcrun simctl status_bar "$DEVICE" override --time "9:41" --batteryState charged \
  --batteryLevel 100 --wifiBars 3 --cellularBars 4 2>/dev/null || true

DEFINES=(--dart-define=BOJANG_E2E=true --dart-define=ENABLE_IOS_FIREBASE=true
         --dart-define=BOJANG_API_BASE_URL=http://127.0.0.1:8787
         --dart-define=BOJANG_AUTH_EMULATOR=127.0.0.1:9099)

FAILED=()
for t in "${TESTS[@]}"; do
  name="$(basename "$t" .dart)"
  log="$RUN/$name.log"
  echo "=== $t"
  (cd "$ROOT" && flutter test "$t" -d "$DEVICE" "${DEFINES[@]}" ${E2E_FLUTTER_ARGS:-}) >"$log" 2>&1 &
  tp=$!
  seen=0
  while kill -0 "$tp" 2>/dev/null; do
    total=$(grep -c "SHOT:" "$log" 2>/dev/null || true)
    while [ "$seen" -lt "${total:-0}" ]; do
      seen=$((seen + 1))
      shot=$(grep "SHOT:" "$log" | sed -n "${seen}p" | sed 's/.*SHOT://' | tr -d '[:space:]')
      xcrun simctl io "$DEVICE" screenshot "$RUN/shots/$name--$shot.png" >/dev/null 2>&1 || true
    done
    sleep 0.3
  done
  if wait "$tp"; then echo "PASS $t"; else echo "FAIL $t (log: $log)"; FAILED+=("$t"); fi
  grep -E "^REPORT:" "$log" | sed 's/^REPORT://' >>"$RUN/report.md" || true
done

echo
echo "screenshots: $RUN/shots"
[ -f "$RUN/report.md" ] && echo "report: $RUN/report.md"
if [ ${#FAILED[@]} -gt 0 ]; then echo "failed: ${FAILED[*]}"; exit 1; fi
echo "all passed"
