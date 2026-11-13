#!/usr/bin/env bash
# Shared paths and launchd helpers for the Lumen auto-share deployment.
# Sourced by install/start/stop/restart/status/uninstall.
#
# Everything is per-user (no root, no LaunchDaemon): the service must run
# inside the logged-in GUI session for ScreenCaptureKit to capture the
# screen, which only a LaunchAgent in ~/Library/LaunchAgents provides.

set -euo pipefail

LABEL="com.lumen.autoshare"

APP_HOME="$HOME/Library/Application Support/lumen-autoshare"
BIN_DIR="$APP_HOME/bin"
BIN="$BIN_DIR/lumen"
SUPERVISOR="$BIN_DIR/lumen-supervisor.sh"
CONFIG="$APP_HOME/config.env"

LOG_DIR="$HOME/Library/Logs/lumen-autoshare"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

GUI_DOMAIN="gui/$(id -u)"
SERVICE_TARGET="$GUI_DOMAIN/$LABEL"

# Refuse to run as root: a root LaunchDaemon has no GUI session and cannot
# use ScreenCaptureKit, and the task explicitly forbids root.
require_non_root() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "error: run this as your normal login user, not root/sudo." >&2
    exit 1
  fi
}

# Is the agent currently registered with launchd?
agent_registered() {
  launchctl print "$SERVICE_TARGET" >/dev/null 2>&1
}

# Load (bootstrap) the agent. Prefers the modern API, falls back to legacy.
agent_load() {
  if launchctl bootstrap "$GUI_DOMAIN" "$PLIST" 2>/dev/null; then
    :
  else
    # Legacy fallback for older macOS.
    launchctl load -w "$PLIST"
  fi
  launchctl enable "$SERVICE_TARGET" 2>/dev/null || true
}

# Unload (bootout) the agent if present. Idempotent.
agent_unload() {
  if agent_registered; then
    launchctl bootout "$SERVICE_TARGET" 2>/dev/null \
      || launchctl bootout "$GUI_DOMAIN" "$PLIST" 2>/dev/null \
      || launchctl unload "$PLIST" 2>/dev/null \
      || true
  fi
}

# Force an immediate (re)start of the agent.
agent_kickstart() {
  launchctl kickstart -k "$SERVICE_TARGET" 2>/dev/null || true
}
