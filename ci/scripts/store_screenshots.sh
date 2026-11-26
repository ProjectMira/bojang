#!/usr/bin/env bash
# Captures App Store screenshots from a booted iOS simulator.
#
#   ci/scripts/store_screenshots.sh --uses-production <simulator-udid> <output-dir>
#
# Runs integration_test/store_screenshots_test.dart on the simulator. The test
# prints "SHOT:<name>" each time a screen is ready and then holds it; this
# script takes the simulator screenshot at every marker.
#
# The committed ios/Runner/GoogleService-Info.plist is a placeholder whose
# values make Firebase abort at launch. For the simulator build only, the
# script swaps in well-formed dummy values and restores the file on exit
# (Firebase stays switched off on iOS without --dart-define
# ENABLE_IOS_FIREBASE=true, so the dummy values are never used).
#
# Suggested devices (the size App Store Connect asks for):
#   iPhone 16 Pro Max   1320x2868  6.9" iPhone
#   iPad Pro 13-inch    2064x2752  13" iPad
set -euo pipefail

# This talks to the PRODUCTION backend (every lesson or game it opens creates
# a learning session there). Prefer ci/scripts/e2e.sh, which captures the
# same set against a local backend. Only run this with the owner's OK.
if [ "${1:-}" != "--uses-production" ]; then
  echo "store_screenshots.sh hits the production backend. Use ci/scripts/e2e.sh"
  echo "(local backend) instead, or pass --uses-production as the first argument."
  exit 2
fi
shift

UDID="${1:?simulator udid}"
OUT="${2:?output directory}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLIST="$ROOT/ios/Runner/GoogleService-Info.plist"
LOG="$(mktemp -t bojang-shots)"

mkdir -p "$OUT"
cd "$ROOT"

restore() { git -C "$ROOT" checkout -- ios/Runner/GoogleService-Info.plist; }
trap restore EXIT

plutil -replace GOOGLE_APP_ID -string "1:123456789:ios:0123456789abcdef012345" "$PLIST"
plutil -replace API_KEY -string "AIzaSyA0000000000000000000000000000000X" "$PLIST"
plutil -replace BUNDLE_ID -string "com.bojang.app" "$PLIST"

xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 || true

flutter test integration_test/store_screenshots_test.dart -d "$UDID" >"$LOG" 2>&1 &
TEST_PID=$!

seen=0
while kill -0 "$TEST_PID" 2>/dev/null; do
  total=$(grep -c "SHOT:" "$LOG" || true)
  while [ "$seen" -lt "$total" ]; do
    seen=$((seen + 1))
    name=$(grep "SHOT:" "$LOG" | sed -n "${seen}p" | sed 's/.*SHOT://' | tr -d '[:space:]')
    [ "$name" = "done" ] && continue
    sleep 1.5 # let the screen settle after the marker
    xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null 2>&1
    echo "captured $name"
  done
  sleep 0.5
done

wait "$TEST_PID" || { echo "screenshot run failed; log: $LOG"; tail -20 "$LOG"; exit 1; }
xcrun simctl status_bar "$UDID" clear || true
echo "screenshots in $OUT"
