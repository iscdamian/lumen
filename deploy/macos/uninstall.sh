#!/usr/bin/env bash
# Remove the Lumen auto-share agent and its files.
#
# Usage:
#   ./uninstall.sh            # remove agent + app files, KEEP logs
#   ./uninstall.sh --purge    # also remove logs
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"
require_non_root

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

echo "Uninstalling Lumen auto-share..."

agent_unload
rm -f "$PLIST" && echo "Removed $PLIST" || true
rm -rf "$APP_HOME" && echo "Removed $APP_HOME" || true

if [ "$PURGE" -eq 1 ]; then
  rm -rf "$LOG_DIR" && echo "Removed $LOG_DIR" || true
else
  echo "Kept logs at $LOG_DIR (use --purge to remove)."
fi

echo "Done. The Homebrew/upstream 'lumen' (if any) was not touched."
