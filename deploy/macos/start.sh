#!/usr/bin/env bash
# Start (load) the Lumen auto-share agent.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"
require_non_root

if [ ! -f "$PLIST" ]; then
  echo "error: not installed (no $PLIST). Run ./install.sh first." >&2
  exit 1
fi

if agent_registered; then
  echo "Already running; forcing a fresh start."
  agent_kickstart
else
  agent_load
  echo "Started."
fi
