#!/bin/zsh
# Runs the Phase 1 spike as a proper app (so audio-capture permission applies to it) and streams its log.
#   ./scripts/spike.sh --list
#   ./scripts/spike.sh --source com.spotify.client --dest ZEALOT --seconds 1800
# Ctrl-C stops the route cleanly.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ -d build/TapSpike.app ]] || ./scripts/build-app.sh TapSpike
LOG="$PWD/build/spike.log"
: > "$LOG"

open -W --stdout "$LOG" --stderr "$LOG" build/TapSpike.app --args "$@" &
OPEN_PID=$!
trap 'pkill -INT -x TapSpike || true; wait $OPEN_PID 2>/dev/null; kill $TAIL_PID 2>/dev/null' INT TERM
tail -f "$LOG" &
TAIL_PID=$!
wait $OPEN_PID || true
sleep 0.2
kill $TAIL_PID 2>/dev/null || true
