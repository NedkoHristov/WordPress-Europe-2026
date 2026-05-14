#!/usr/bin/env bash
# =============================================================================
# screenshot-watcher.sh — Fire Grafana screenshots at peak load
#
# Runs in the background alongside a k6 test. Polls Prometheus for k6_vus
# every POLL_INTERVAL seconds. Once VUs have been at or above TARGET_VU for
# HOLD_COUNT consecutive polls, waits SETTLE_SECS for Grafana panels to
# stabilise, then calls screenshot.js with a time window pinned to right now.
#
# State machine:
#   WAITING → (vus >= 1)    → RISING
#   RISING  → (hold count)  → AT_PEAK → sleep SETTLE_SECS → screenshot → exit 0
#   RISING  → (vus drops)   → hold counter resets, stays RISING
#   any     → elapsed >= TIMEOUT → exit 1
#
# Usage:
#   bash scripts/screenshot-watcher.sh --prefix l1 [options] &
#   WATCHER_PID=$!
#   <run k6 test>
#   kill $WATCHER_PID 2>/dev/null || true
#   wait $WATCHER_PID 2>/dev/null || true
#
# Options:
#   --prefix     PREFIX   Screenshot filename prefix              (default: snap)
#   --target-vu  N        Fire when k6_vus >= N                  (default: 45)
#   --hold       N        Consecutive polls required at target    (default: 3)
#   --settle     SECS     Wait after peak before screenshotting   (default: 5)
#   --window     SECS     Grafana time window width               (default: 300)
#   --poll       SECS     Poll interval                           (default: 3)
#   --timeout    SECS     Give up if no screenshot taken by then  (default: 300)
#   --prometheus URL      Prometheus base URL (default: http://localhost:9090)
# =============================================================================
set -euo pipefail

# ── defaults ─────────────────────────────────────────────────────────────────
PREFIX="snap"
TARGET_VU=45
HOLD_COUNT=3
SETTLE_SECS=5
WINDOW_SECS=300
POLL_INTERVAL=3
TIMEOUT=300
PROMETHEUS="http://localhost:9090"

# ── parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)     PREFIX="$2";        shift 2 ;;
    --target-vu)  TARGET_VU="$2";     shift 2 ;;
    --hold)       HOLD_COUNT="$2";    shift 2 ;;
    --settle)     SETTLE_SECS="$2";   shift 2 ;;
    --window)     WINDOW_SECS="$2";   shift 2 ;;
    --poll)       POLL_INTERVAL="$2"; shift 2 ;;
    --timeout)    TIMEOUT="$2";       shift 2 ;;
    --prometheus) PROMETHEUS="$2";    shift 2 ;;
    *) echo "[watcher] Unknown argument: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── helpers ───────────────────────────────────────────────────────────────────
log() { echo "[watcher $(date +%H:%M:%S)] $*"; }

# Query current k6_vus from Prometheus; returns integer (floor), or 0 on error
query_vus() {
  curl -sf "${PROMETHEUS}/api/v1/query?query=k6_vus" \
    | jq -r '(.data.result[0].value[1] // "0") | tonumber | floor' 2>/dev/null \
    || echo "0"
}

# Integer >= comparison via awk (handles floats from jq safely)
gte() { awk -v a="$1" -v b="$2" 'BEGIN { exit (a >= b) ? 0 : 1 }'; }

# ── startup log ───────────────────────────────────────────────────────────────
log "Started — prefix=${PREFIX} target_vu=${TARGET_VU} hold=${HOLD_COUNT}×${POLL_INTERVAL}s settle=${SETTLE_SECS}s window=${WINDOW_SECS}s timeout=${TIMEOUT}s"

# ── state machine ─────────────────────────────────────────────────────────────
state="WAITING"
hold=0
elapsed=0

while true; do
  vus=$(query_vus)

  case "$state" in

    WAITING)
      if gte "$vus" 1; then
        log "k6 started — k6_vus=${vus}, watching for peak"
        state="RISING"
        hold=0
      fi
      ;;

    RISING)
      if gte "$vus" "$TARGET_VU"; then
        hold=$(( hold + 1 ))
        log "k6_vus=${vus} >= ${TARGET_VU} (hold ${hold}/${HOLD_COUNT})"
        if (( hold >= HOLD_COUNT )); then
          state="AT_PEAK"
          # Don't sleep — fall through to AT_PEAK handling immediately
          continue
        fi
      else
        if (( hold > 0 )); then
          log "k6_vus=${vus} dropped below target — resetting hold counter"
        fi
        hold=0
      fi
      ;;

    AT_PEAK)
      log "Peak confirmed — settling for ${SETTLE_SECS}s before screenshot"
      sleep "$SETTLE_SECS"

      # Pin exact time window at the moment we fire
      NOW_MS=$(( $(date +%s) * 1000 ))
      FROM_MS=$(( NOW_MS - WINDOW_SECS * 1000 ))

      log "Firing screenshot.js — from=$(date -d @$(( FROM_MS / 1000 )) '+%H:%M:%S') to=$(date -d @$(( NOW_MS / 1000 )) '+%H:%M:%S')"
      node "${SCRIPT_DIR}/screenshot.js" "${PREFIX}" "${FROM_MS}" "${NOW_MS}"
      log "Done — screenshots saved to screenshots/${PREFIX}-*.png"
      exit 0
      ;;

  esac

  sleep "$POLL_INTERVAL"
  elapsed=$(( elapsed + POLL_INTERVAL ))

  if (( elapsed >= TIMEOUT )); then
    log "Timeout after ${TIMEOUT}s with no screenshot (state=${state}, last k6_vus=${vus})"
    exit 1
  fi
done
