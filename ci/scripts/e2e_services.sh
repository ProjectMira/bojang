#!/usr/bin/env bash
# Starts the local backend (127.0.0.1:8787) and the Firebase Auth emulator
# (127.0.0.1:9099) in the foreground until Ctrl-C, for running
#   ci/scripts/e2e.sh --external-services --device <udid> <tests>
# on several simulators at once.
#
#   ci/scripts/e2e_services.sh [--backend <bojang-backend dir>] [--state <dir>]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BACKEND="${BOJANG_BACKEND:-}"
STATE="$ROOT/build/e2e/services"
while [ $# -gt 0 ]; do
  case "$1" in
    --backend) BACKEND="$2"; shift 2 ;;
    --state) STATE="$2"; shift 2 ;;
    *) echo "unknown $1"; exit 2 ;;
  esac
done
if [ -z "$BACKEND" ]; then
  for c in "$ROOT/../bojang-backend" "$ROOT/../../../../bojang-backend"; do
    [ -d "$c/functions" ] && BACKEND="$(cd "$c" && pwd)" && break
  done
fi
COMMON="$(git -C "$BACKEND" rev-parse --path-format=absolute --git-common-dir)/.."
PY="${BOJANG_BACKEND_PY:-$BACKEND/functions/venv/bin/python}"
[ -x "$PY" ] || PY="$COMMON/functions/venv/bin/python"
mkdir -p "$STATE"
trap 'kill 0' EXIT
"$PY" "$ROOT/ci/e2e/local_backend.py" --backend "$BACKEND/functions" --state-dir "$STATE" \
  --vocab-db "${BOJANG_VOCAB_DB:-$COMMON/functions/bojang_local.db}" &
(cd "$ROOT/ci/e2e" && exec firebase emulators:start --only auth --project demo-bojang-e2e --config firebase.json) &
wait
