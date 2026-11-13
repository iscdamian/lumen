# Lumen auto-share (macOS, unattended open-access LAN mode)

Fully automatic, **unauthenticated** Lumen screen sharing on a trusted LAN.
After installation, the Mac user logs in and another device can open
`http://<en1-ip>:3131` to watch the screen immediately — **zero
confirmations, no QR, no PIN, no password**.

> ⚠️ **Security boundary.** This grants screen access to *anyone who can
> reach the service on the LAN*. The server binds **only** to the chosen
> interface's IPv4 address (never `0.0.0.0`). Do **not** port-forward it to
> the WAN or put it behind a public reverse proxy. Open access is explicit
> and opt-in; upstream authentication remains the default everywhere else.

## What it does

| Requirement | How |
|---|---|
| Start at login | per-user **LaunchAgent** (`RunAtLoad`), runs in the GUI/Aqua session for ScreenCaptureKit |
| Pick `en1` automatically | `lumen serve --interface en1` resolves the interface's current IPv4, prefers `192.168.188.127`, waits out DHCP/link bring-up, never shows a menu |
| No auth | `--auth-mode none` — no approval, QR, pairing code, enrollment, cookie, or token; every viewer is admitted |
| Bind to the LAN interface only | server binds the interface IP, not all interfaces |
| Multiple viewers | supported |
| Full restart every 30 min | **supervisor** fully terminates the process (SIGINT → grace → SIGKILL) and launches a fresh one; timer resets each start |
| Crash recovery | supervisor restarts immediately on unexpected exit; `KeepAlive` relaunches the supervisor itself |
| Browser auto-reconnect | the bundled web viewer already retries with exponential backoff and rejoins after the server returns |
| Protect admin endpoints | admin UI stays gated by `--allow-lan-admin` and is reachable only on the bound interface |

## Install

```bash
# from the repo root, build the custom binary first:
cargo build --release

cd deploy/macos
chmod +x *.sh
./install.sh                 # or: ./install.sh /path/to/custom/lumen
```

The custom binary is copied to
`~/Library/Application Support/lumen-autoshare/bin/lumen` — it does **not**
overwrite a Homebrew `lumen`.

On first run grant **Screen Recording** permission to that `lumen` binary
(System Settings → Privacy & Security → Screen Recording), then `./restart.sh`.

## Manage

```bash
./status.sh     # agent state, running process, recent logs
./stop.sh       # stop and DO NOT relaunch
./start.sh      # start / force a fresh start
./restart.sh    # reload config + plist, reset the 30-min timer
./uninstall.sh  # remove agent + app files (add --purge to drop logs too)
```

## Configure

Edit `~/Library/Application Support/lumen-autoshare/config.env`, then
`./restart.sh`:

```sh
LUMEN_INTERFACE="en1"          # interface to bind to
LUMEN_PORT="3131"              # HTTP/WebRTC port
LUMEN_RESTART_INTERVAL="1800"  # hard process lifetime (seconds) = 30 min
LUMEN_SHUTDOWN_GRACE="10"      # seconds before SIGKILL
LUMEN_EXTRA_ARGS=""            # extra `lumen serve` args
```

The supervisor always runs:

```bash
lumen serve --interface "$LUMEN_INTERFACE" --port "$LUMEN_PORT" \
            --auth-mode none --no-qr --allow-lan-admin $LUMEN_EXTRA_ARGS
```

## Logs

`~/Library/Logs/lumen-autoshare/`

| File | Contents |
|---|---|
| `supervisor.log` | startup, selected interface/port, scheduled restarts, forced terminations, crash exit codes, immediate restarts |
| `lumen.log` | Lumen's own stdout/stderr (bind address, viewer connections, WebRTC events) |
| `launchd.out.log` / `launchd.err.log` | launchd-level output |

Example:

```text
[2025-01-01 00:00:00] Supervisor started (interface=en1 port=3131 restart=1800s grace=10s)
[2025-01-01 00:00:00] Lumen started (pid 5123); scheduled restart in 1800s
[2025-01-01 00:30:00] Scheduled restart initiated (lifetime reached 1800s)
[2025-01-01 00:30:00] Terminating Lumen (pid 5123): SIGINT, grace 10s
[2025-01-01 00:30:01] Previous process terminated; launching replacement
[2025-01-01 00:30:01] Lumen started (pid 5241); scheduled restart in 1800s
```

## How the 30-minute restart works

`launchd` keeps the **supervisor** alive; the supervisor owns each Lumen
process's hard lifetime. Every `LUMEN_RESTART_INTERVAL` seconds it sends
`SIGINT` (Lumen's graceful Ctrl-C path), waits `LUMEN_SHUTDOWN_GRACE`
seconds, escalates to `SIGKILL` if needed, waits for the old process to
fully exit (so the port is free), then starts a new process and resets the
timer. An unexpected exit is logged with its code and restarted immediately.
`./stop.sh` boots the agent out so nothing relaunches.
