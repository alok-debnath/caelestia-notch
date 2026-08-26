# AGENTS.md

Context for AI agents working in this repo. Terse by design — `README.md` has the full prose.

## What this is

A Hyprland desktop shell: [Caelestia](https://github.com/caelestia-dots/shell) with a
Dynamic-Island notch built in as a native Quickshell module. Owned code, not a tracking
fork and not a patch set — edit files directly, there is no upstream to defer to.

Two ancestries:

- **Caelestia** — the shell itself. Services, colours, blob renderer, launcher, bar, lock.
  Everything the island needs, it reads from Caelestia's own singletons.
- **[Tide Island](https://github.com/enhaoswen/Tide-island)** — geometry, type scale and
  motion only. Fixed capsule sizes per state, content laid out inside; 400ms OutQuint
  between them. Tide's code was vendored and rewritten as QML, never installed alongside.

No C++ in this repo. Fedora 44 + Hyprland + Quickshell 0.3.1.

## Hard rules

1. **The island owns no infrastructure.** Notifications → `Notifs`/`NotifData`. Volume/mic →
   `Audio`. Brightness → `Brightness.monitors`. Now playing → `Players`. Colour → `Colours`.
   Shape → `BlobRect`. Never snoop the session bus, poll `wpctl`, watch `/sys/class/backlight`
   or hardcode a palette — that table is the whole design.
2. **Nothing is painted black.** Palette comes from the wallpaper via `Colours`.
3. **Capsule sizes come from `IslandTokens.qml`.** A state morphs to a fixed size; the capsule
   never sizes itself to its content.
4. **The capsule is not clickable at rest.** Hover expands; crossing it does nothing.
5. **No dashboard.** Caelestia's top-centre drawer is removed; calendar and performance live
   in the notch.
6. **Transient layers borrow the notch.** A notification or OSD interrupts an expanded view
   and hands it back after.

## Layout

```
shell/
├── shell.qml
├── modules/island/    the notch — see README for the per-file table
│   └── overview/      workspace overview cards
├── modules/           bar drawers launcher lock sidebar nexus notifications …
├── services/          Notifs Audio Brightness Players Colours …
├── components/        StyledRect StyledText MaterialIcon …
└── utils/
scripts/               install.sh restart.sh
docs/DIVERGENCE.md     what differs from stock Caelestia
```

Island entry points: `Island.qml` (one window per screen + IPC), `IslandWindow.qml` (state
machine, morphing capsule), `IslandTokens.qml` (sizes/radii/hold times/type scale),
`IslandConfig.qml` (settings, backed by `~/.config/caelestia/island.json`).

## Build / run

```sh
make run       # qs -p shell — run the working tree, no install. Use this to iterate.
make install   # deploy shell/ to ~/.config/quickshell/caelestia
make restart   # restart the running shell
```

`~/.config/quickshell/caelestia` is a **deploy copy, not a symlink** — edits there are
untracked and get overwritten. Always edit the repo.

Quickshell resolves a config name against `$XDG_CONFIG_HOME` before `/etc/xdg`, so the
deployed tree shadows the packaged `caelestia-shell` with no launcher change. Consequence:
after `dnf update caelestia-shell` the packaged tree is **not** what runs — re-run
`make install && make restart` or the system silently keeps the old tree.

Verify live over IPC, e.g. `qs ipc -c caelestia call island toggleCalendar`. Full call list
in README.

## Gotchas

- Git identity here is `alokdebnath.in@gmail.com`, not the global address.
- Shelf drag-in needs Hyprland with `hyprwm/Hyprland#15780` (merged 2026-08-08) — keyboard
  exclusivity during DnD otherwise breaks layer-shell drops. Not a QML bug.
- Face ID capsule fires on biopass scans in the **unlocked** session only; the lock screen
  has its own PAM stack. Wiring lives outside this repo: `/usr/local/bin/biopass-gate`,
  `auth optional pam_exec.so` in `system-auth` via `authselect`.
- Companion repo `~/hyprland-fedora` holds `SETUP-LOG.md`; system-level changes are logged
  there, usually in a paired commit.
- The predecessor repo `caelestia-tide-island` (patch series over two upstreams) is dead.
  Do not reintroduce a patch/overlay workflow.
