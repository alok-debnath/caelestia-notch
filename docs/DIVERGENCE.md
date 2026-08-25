# Divergence from Caelestia

The `shell/` tree started as Caelestia 2.3.0 (Fedora `caelestia-shell`,
`/etc/xdg/quickshell/caelestia`). Everything in it is Caelestia's except
`modules/island/`, which is new, and four files that were changed to make room
for the notch.

Keeping this list short is deliberate. The island is a module that plugs in, not
a rewrite of the shell, and the smaller this file stays the easier it is to pull
a fix or a feature out of upstream Caelestia by hand.

To see the current diff against a packaged Caelestia:

```sh
diff -rq /etc/xdg/quickshell/caelestia shell
```

## The dashboard is removed

Caelestia's top-centre dashboard drawer is gone: `modules/dashboard/` is deleted,
and with it the drawer's panel, region, blob, hover and drag handling, shortcut
and `ScreenState` flags.

Its calendar and performance views were the parts worth keeping, so they were
moved into `modules/island/` and are opened from the notch instead. The calendar
was decoupled from `ScreenState` on the way — it owns its `viewDate` now, since
nothing outside it needs the value.

Files touched by the removal, beyond deleting the module:

| File | Change |
| --- | --- |
| `components/ScreenState.qml` | dropped `dashboard`, `dashboardTab`, `dashboardDate` |
| `modules/drawers/Panels.qml` | dropped the `Dashboard.Wrapper` |
| `modules/drawers/Regions.qml` | dropped its input region |
| `modules/drawers/ContentWindow.qml` | dropped `dashBg`, its deform transform, and its entries in the fullscreen and drag-mask handling |
| `modules/drawers/Interactions.qml` | dropped the hover, drag and shortcut-mode paths |
| `modules/Shortcuts.qml` | dropped the `dashboard` shortcut; `showall` no longer toggles it |
| `modules/launcher/Wrapper.qml` | no longer subtracts dashboard height |
| `modules/nexus/` | dropped `DashboardPanel` and its `PanelsPage` row |

`Config.dashboard.*` still exists — it is provided by `Caelestia.Config` in C++,
and the performance cards still read `Config.dashboard.performance.*` for which
widgets to show. The config namespace outlives the drawer it was named after.
The one place this shows is the nexus settings page, which still exposes the
dashboard update intervals; those drive the ported cards, so they still do
something.

In `modules/nexus/PageCompRegistry.qml` the dashboard's sub-page slot is filled
with a `PlaceholderComp` rather than removed, because later entries in that
`StackPage` are addressed by index from other pages.

## `shell.qml`

Four lines: `import "modules/island"` / `import "modules/island/overview"`, and
`Island {}` / `Overview {}`, mounted just before `ConfigToasts {}` so the
island's layer surfaces stack above the drawers.

## `services/ShellState.qml`

`Components` gains an `island` slot. Each island window registers itself into it
via the existing `ShellState.ComponentRef`, which is how `ContentWindow` finds
the capsule it has to draw.

## `modules/drawers/ContentWindow.qml`

Adds `islandBg`, a `BlobRect` in the shell's blob group that mirrors the island
capsule's geometry, with `topLeftRadius` and `topRightRadius` forced to 0.

This is what makes the notch a notch. The blob group melts overlapping shapes
together with concave joins, so a rectangle placed against the top border reads
as carved out of it rather than stuck onto it — the same treatment the dashboard
and launcher already get.

Two upstream facts make the coordinate mapping work, and both are load-bearing:

- the island's `PanelWindow` is `anchors { top; left; right }` with no margins of
  its own, so the exclusion zones place its origin at exactly
  `(bar.implicitWidth, borderThickness)`;
- the capsule is positioned relative to that window.

Together, the capsule's `x`/`y` land in the same space `PanelBg` works in, which
is why `islandBg` uses the same `+ bar.implicitWidth` / `+ borderThickness`
offsets every other panel does. **If the notch ever renders offset from the
border, check these two first.**

## `modules/notifications/Wrapper.qml`

Adds `popupsEnabled`, pinned to `false`, which collapses Caelestia's notification
popup stack — the notch renders popups instead.

The panel is left *mounted* rather than removed, because `Panels`, `Regions`,
`ContentWindow` and the sidebar all anchor against its geometry; only its
`implicitHeight` is forced to zero. Notification history in the sidebar is
unaffected: it reads the `Notifs` service directly rather than going through this
panel.

Set it back to `true` to hand popups back to Caelestia. You would then also want
to stop the notch showing them, in `modules/island/IslandWindow.qml`.

## `modules/nexus/`

`PageCompRegistry.qml` gains `IslandPanel` at the **end** of the Panels stack,
and `pages/PanelsPage.qml` gains a row pointing at it. Appended rather than
slotted in beside the other panels because the taskbar sub-pages before it are
addressed by index from elsewhere in that page.

The island's settings do not live in `Config`: that object comes from
`Caelestia.Config` in C++ and this repo has no C++, so `IslandConfig` keeps them
in `~/.config/caelestia/island.json` and the page writes through to it. Every
other settings page in the window edits `GlobalConfig` instead -- this is the one
that does not.

## Configuration, not code

Caelestia's own OSD is left enabled upstream. It is turned off through
`~/.config/caelestia/shell.json`:

```json
{ "osd": { "enabled": false } }
```

Without that, volume and brightness render both in the notch and in Caelestia's
OSD drawer. This is user configuration rather than a change to the tree, so it is
not carried in this repo.

## Notes on behaviour inherited from Caelestia

`Brightness` only learns about brightness changes it makes itself — it shells out
to `brightnessctl` and updates its own property. An external `brightnessctl` call
therefore changes the screen without the notch reacting. This is upstream
behaviour, not a notch bug: the brightness keys go through
`caelestia:brightnessUp` / `caelestia:brightnessDown`, which do route through the
service, so the OSD appears for the keys you actually press.
