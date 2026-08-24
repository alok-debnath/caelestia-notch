#!/usr/bin/env bash
# Deploy the shell to the Quickshell config directory.
#
# It installs under the name "caelestia" on purpose: Quickshell resolves a config
# name against $XDG_CONFIG_HOME before /etc/xdg, so this shadows the packaged
# caelestia-shell tree without touching any launcher. `caelestia shell -d`, the
# SUPER+R reload and every existing keybind keep working and pick this up.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${TARGET:=${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

command -v rsync >/dev/null || { echo "rsync is required" >&2; exit 1; }

if [[ -e $TARGET && ! -e $TARGET/.caelestia-notch ]]; then
    backup="$TARGET.backup-$(date +%Y%m%d%H%M%S)"
    log "moving the existing config aside to $backup"
    mv "$TARGET" "$backup"
fi

log "installing to $TARGET"
mkdir -p "$TARGET"
rsync -a --delete "$REPO_ROOT/shell"/ "$TARGET"/

# Marker so a re-install overwrites our own tree instead of backing it up again.
touch "$TARGET/.caelestia-notch"

log "done -- reload with: caelestia shell -d  (or SUPER+R)"
