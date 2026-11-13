#!/usr/bin/env bash
# Restart the Lumen auto-share agent (reloads plist + config, resets the
# 30-minute timer by starting a brand new supervisor + process).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"
require_non_root

if [ ! -f "$PLIST" ]; then
  echo "error: not installed (no $PLIST). Run ./install.sh first." >&2
  exit 1
fi

# Fully reload so config/plist changes take effect, then ensure it's up.
agent_unload
agent_load
agent_kickstart
echo "Restarted."
