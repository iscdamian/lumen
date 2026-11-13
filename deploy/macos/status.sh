#!/usr/bin/env bash
# Show the status of the Lumen auto-share agent and recent logs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

echo "== Lumen auto-share status =="
echo "Label:   $LABEL"
echo "Plist:   $PLIST $([ -f "$PLIST" ] && echo '(installed)' || echo '(MISSING)')"
echo "Binary:  $BIN $([ -x "$BIN" ] && echo '(ok)' || echo '(MISSING)')"
echo "Config:  $CONFIG"
echo "Logs:    $LOG_DIR"
echo

if agent_registered; then
  echo "launchd: REGISTERED"
  launchctl print "$SERVICE_TARGET" 2>/dev/null \
    | grep -E 'state =|pid =|last exit code =|runs =' || true
else
  echo "launchd: not registered (stopped or not installed)"
fi

echo
echo "== Running lumen processes =="
pgrep -lf "$BIN" || echo "(none)"

echo
echo "== supervisor.log (last 15) =="
[ -f "$LOG_DIR/supervisor.log" ] && tail -n 15 "$LOG_DIR/supervisor.log" || echo "(no supervisor log yet)"
