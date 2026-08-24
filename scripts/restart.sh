#!/usr/bin/env bash
# Restart the running shell.
#
# Note the pkill pattern: matching the full command line would also match the
# shell running this script and kill it mid-way, so match the process name.

set -euo pipefail

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

if pgrep -u "$(id -u)" -x qs >/dev/null 2>&1; then
    log "stopping running shell"
    pkill -u "$(id -u)" -x qs || true
    for _ in $(seq 20); do
        pgrep -u "$(id -u)" -x qs >/dev/null 2>&1 || break
        sleep 0.25
    done
fi

log "starting shell"
setsid caelestia shell -d >/dev/null 2>&1 < /dev/null &

sleep 4
if pgrep -u "$(id -u)" -x qs >/dev/null 2>&1; then
    log "shell is up"
else
    echo "shell did not start -- run 'caelestia shell' to see the error" >&2
    exit 1
fi
