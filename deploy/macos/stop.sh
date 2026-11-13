#!/usr/bin/env bash
# Stop (unload) the Lumen auto-share agent WITHOUT relaunching it.
# After this, nothing restarts Lumen until ./start.sh (or next login if you
# leave the plist in place — use ./uninstall.sh to also disable at login).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
. "$SCRIPT_DIR/_common.sh"
require_non_root

agent_unload
echo "Stopped. Lumen will not relaunch until you run ./start.sh."
