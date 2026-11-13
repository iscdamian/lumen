#!/usr/bin/env bash
# Lumen auto-share supervisor.
#
# launchd keeps THIS script alive (RunAtLoad + KeepAlive); the script owns
# the hard 30-minute lifetime of each Lumen process:
#
#   * start exactly one `lumen serve` child, bound to the LAN interface,
#     with open access (no approval / pairing / credential);
#   * after LUMEN_RESTART_INTERVAL seconds, fully terminate it (SIGINT →
#     grace → SIGKILL) and start a fresh process — the whole process exits,
#     not just the WebRTC peer / capture / encoder;
#   * if the child crashes earlier, restart immediately with a fresh timer;
#   * never run two Lumen processes at once (we wait for the old one to exit
#     before binding the port again);
#   * stop entirely when launchd boots us out (intentional disable).

set -uo pipefail

APP_HOME="$HOME/Library/Application Support/lumen-autoshare"
CONFIG="$APP_HOME/config.env"
BIN="$APP_HOME/bin/lumen"
LOG_DIR="$HOME/Library/Logs/lumen-autoshare"

# shellcheck disable=SC1090
[ -f "$CONFIG" ] && . "$CONFIG"

LUMEN_INTERFACE="${LUMEN_INTERFACE:-en1}"
LUMEN_PORT="${LUMEN_PORT:-3131}"
LUMEN_RESTART_INTERVAL="${LUMEN_RESTART_INTERVAL:-1800}"
LUMEN_SHUTDOWN_GRACE="${LUMEN_SHUTDOWN_GRACE:-10}"
# Extra raw args appended verbatim (word-split on purpose).
LUMEN_EXTRA_ARGS="${LUMEN_EXTRA_ARGS:-}"

mkdir -p "$LOG_DIR"
SUP_LOG="$LOG_DIR/supervisor.log"
APP_LOG="$LOG_DIR/lumen.log"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$SUP_LOG"
}

child=""

# Terminate the current Lumen child: graceful SIGINT first (lumen's Ctrl+C
# shutdown path), escalate to SIGKILL if it hangs past the grace window.
terminate_child() {
  [ -n "$child" ] || return 0
  if kill -0 "$child" 2>/dev/null; then
    log "Terminating Lumen (pid $child): SIGINT, grace ${LUMEN_SHUTDOWN_GRACE}s"
    kill -INT "$child" 2>/dev/null || true
    local waited=0
    while [ "$waited" -lt "$LUMEN_SHUTDOWN_GRACE" ]; do
      kill -0 "$child" 2>/dev/null || break
      sleep 1
      waited=$((waited + 1))
    done
    if kill -0 "$child" 2>/dev/null; then
      log "Graceful shutdown timed out after ${LUMEN_SHUTDOWN_GRACE}s; sending SIGKILL to $child"
      kill -KILL "$child" 2>/dev/null || true
    fi
  fi
  wait "$child" 2>/dev/null || true
}

# launchd sends SIGTERM on bootout; tear the child down and exit cleanly so
# no orphaned Lumen keeps the port or the screen capture.
on_stop() {
  log "Supervisor received stop signal; shutting down and NOT restarting"
  terminate_child
  log "Supervisor stopped"
  exit 0
}
trap on_stop INT TERM

if [ ! -x "$BIN" ]; then
  log "FATAL: lumen binary missing or not executable at $BIN (run install.sh)"
  # Non-zero exit; launchd will back off and retry, surfacing the problem.
  exit 78 # EX_CONFIG
fi

log "Supervisor started (interface=$LUMEN_INTERFACE port=$LUMEN_PORT restart=${LUMEN_RESTART_INTERVAL}s grace=${LUMEN_SHUTDOWN_GRACE}s)"

while true; do
  start_ts=$(date +%s)
  log "Starting Lumen: lumen serve --interface $LUMEN_INTERFACE --port $LUMEN_PORT --auth-mode none --no-qr --allow-lan-admin ${LUMEN_EXTRA_ARGS}"

  # shellcheck disable=SC2086
  "$BIN" serve \
    --interface "$LUMEN_INTERFACE" \
    --port "$LUMEN_PORT" \
    --auth-mode none \
    --no-qr \
    --allow-lan-admin \
    $LUMEN_EXTRA_ARGS >>"$APP_LOG" 2>&1 &
  child=$!
  log "Lumen started (pid $child); scheduled restart in ${LUMEN_RESTART_INTERVAL}s"

  deadline=$((start_ts + LUMEN_RESTART_INTERVAL))
  scheduled=0
  while kill -0 "$child" 2>/dev/null; do
    now=$(date +%s)
    if [ "$now" -ge "$deadline" ]; then
      scheduled=1
      log "Scheduled restart initiated (lifetime reached ${LUMEN_RESTART_INTERVAL}s)"
      terminate_child
      log "Previous process terminated; launching replacement"
      break
    fi
    sleep 1
  done

  if [ "$scheduled" -eq 0 ]; then
    # The child exited on its own: capture its status and restart at once.
    wait "$child"
    code=$?
    log "Lumen exited unexpectedly (exit code $code); restarting immediately (crash recovery)"
  fi

  child=""
  # Guard against a crash-on-start becoming a tight CPU spin.
  sleep 1
done
