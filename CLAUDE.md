# CLAUDE.md

Read [AGENTS.md](AGENTS.md) first — it holds the architecture, hard rules, build commands
and gotchas for this repo. `README.md` has the long-form version, including the per-file
island table and the full IPC call list.

## Short version

Caelestia shell with a Dynamic-Island notch as a native module. Tide Island supplies the
geometry and motion; Caelestia supplies every service and the colour. Owned code — edit
files directly, no upstream, no patch overlay.

## Before changing the island

- The island reads Caelestia's singletons and owns no infrastructure of its own.
- Sizes and timings come from `IslandTokens.qml`, never from content.
- `make run` to iterate; `make install && make restart` to deploy.
- `~/.config/quickshell/caelestia` is a deploy copy — never edit it.

## Working style

- Commits and pushes only when explicitly asked, per the global rules.
- Verify changes live over IPC rather than by reading the diff back.
