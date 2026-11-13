#!/usr/bin/env bash
# Install the Lumen auto-share LaunchAgent for the current login user.
#
# Usage:
#   ./install.sh [path-to-lumen-binary]
#
# If no binary path is given, uses ./target/release/lumen (relative to the
# repository root). The custom binary is copied into a private location and
# never overwrites a Homebrew-managed `lumen`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"

require_non_root

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC_BIN="${1:-$REPO_ROOT/target/release/lumen}"

if [ ! -x "$SRC_BIN" ]; then
  echo "error: lumen binary not found/executable at: $SRC_BIN" >&2
  echo "       build it first (cargo build --release) or pass a path." >&2
  exit 1
fi

echo "Installing Lumen auto-share for user $(id -un) ($(id -u))"

mkdir -p "$BIN_DIR" "$APP_HOME" "$LOG_DIR" "$HOME/Library/LaunchAgents"

# If a previous instance is running, stop it first so we never end up with
# two supervisors (and so we can replace the binary cleanly).
agent_unload

install -m 0755 "$SRC_BIN" "$BIN"
install -m 0755 "$SCRIPT_DIR/lumen-supervisor.sh" "$SUPERVISOR"
echo "Installed binary:     $BIN"
echo "Installed supervisor: $SUPERVISOR"

# Preserve an existing config (don't clobber user edits); seed on first run.
if [ ! -f "$CONFIG" ]; then
  install -m 0644 "$SCRIPT_DIR/config.env" "$CONFIG"
  echo "Installed config:     $CONFIG"
else
  echo "Kept existing config: $CONFIG"
fi

# Generate the LaunchAgent plist. RunAtLoad + KeepAlive makes launchd start
# the supervisor at login and relaunch it if it ever dies (belt-and-braces
# on top of the supervisor's own restart loop). ProcessType Interactive +
# running in the gui domain keeps us in the Aqua session for ScreenCaptureKit.
cat >"$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SUPERVISOR</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/launchd.err.log</string>
</dict>
</plist>
PLIST_EOF
echo "Installed LaunchAgent: $PLIST"

agent_load
agent_kickstart

echo
echo "Done. Lumen auto-share is running and will start at login."
echo "  Interface/port/interval: edit $CONFIG then ./restart.sh"
echo "  Logs:    $LOG_DIR"
echo "  Status:  ./status.sh"
echo
echo "NOTE: the first run needs Screen Recording permission for the 'lumen'"
echo "      binary. Grant it in System Settings > Privacy & Security >"
echo "      Screen Recording, then ./restart.sh."
