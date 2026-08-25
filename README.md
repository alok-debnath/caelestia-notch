# caelestia-notch

A Hyprland desktop shell: [Caelestia](https://github.com/caelestia-dots/shell)
with a Dynamic-Island-style notch built into it as a native module.

Not a fork that tracks upstream, and not a patch set over someone else's tree —
this is the shell, maintained here, edited directly.

Built on Fedora 44 + Hyprland + Quickshell 0.3.1.

## What the notch is

A notch that grows out of the top border as one continuous surface, carrying the
clock at rest and morphing to show notifications, volume, microphone, brightness,
the current track, a calendar, system resources, a control centre, notification
history and a file shelf -- plus a workspace overview in a window of its own.

Its **geometry, type scale and motion are Tide Island's**: every state morphs the
capsule to a fixed size and the content lays out inside it, rather than the
capsule sizing itself to whatever is in it. That table -- 140x38 at rest, 220 for
a line of text, 410x165 for the player, 420 for the control centre, 400ms of
OutQuint between them -- is most of why the notch reads as one object changing
shape rather than a set of popups.

Its **colour is Caelestia's**: the palette comes from the wallpaper and the shape
is drawn by the shell's own blob renderer, so nothing here is painted black.

**There is no dashboard.** Caelestia's top-centre drawer is removed — its
calendar and performance views are ported into the notch, which is where they
belong once the notch is there at all.

It is drawn by Caelestia's own signed-distance-field blob renderer — the same
one that draws the bar and drawers — so it fuses into the border with concave
joins rather than floating below it as a separate pill. Square top corners,
rounded bottom.

```
┌─────────────────────────────────┐
│░░░░░░░░░░░░╭──────────╮░░░░░░░░░│   one surface with the border
│            │ 11:05 PM │         │
│            ╰──────────╯         │
│                                 │
```

## Why it is written this way

The obvious way to get a Dynamic Island on Hyprland is to run
[Tide Island](https://github.com/enhaoswen/Tide-island) alongside Caelestia.
That gives you two Quickshell processes, two notification paths and two colour
systems, and it was the starting point for this repo. It does not end well:
Tide is a complete shell, so everything it renders duplicates something
Caelestia already renders, and its C++ backend re-implements services Caelestia
already has.

So the island here is a **native Caelestia module**. It reads the shell's own
services and owns no infrastructure of its own:

| The island needs | It uses | Instead of |
| --- | --- | --- |
| Notifications | `Notifs` / `NotifData` | snooping `Notify` calls off the session bus |
| Volume, microphone | `Audio` (PipeWire) | `pactl subscribe` + polling `wpctl` |
| Brightness | `Brightness.monitors` | a `udev` watch on `/sys/class/backlight` |
| Now playing | `Players` (MPRIS) | a second MPRIS client |
| Colour | `Colours` | a hardcoded palette with a JSON bridge over it |
| Shape | `BlobRect` in the shell's blob group | painting its own rounded rectangle |

That table is the whole design. Because Caelestia *is* the notification server,
the notch gets the real app icon, the notification's actions as buttons, urgency
colouring, its expire timeout and Do Not Disturb — all for free, none of which
survives a bus-snooping implementation. Because `Audio` exposes the source node,
microphone OSD works. Because `Colours` is the same singleton the rest of the
shell reads, the notch is themed by the wallpaper with no bridging code at all.

There is no C++ in this repo.

## Install

```sh
git clone https://github.com/alok-debnath/caelestia-notch
cd caelestia-notch
make install
make restart
```

`make install` deploys `shell/` to `~/.config/quickshell/caelestia`. That name is
deliberate: Quickshell resolves a config name against `$XDG_CONFIG_HOME` before
`/etc/xdg`, so this shadows the packaged `caelestia-shell` tree **without
touching any launcher**. `caelestia shell -d`, `SUPER + R` and every existing
keybind keep working and pick this up. An existing config directory is moved
aside, not deleted.

`make run` runs the working tree directly (`qs -p shell`) without installing,
which is the way to iterate.

You still want `caelestia-shell` installed for its Quickshell dependency and
`caelestia-cli` for the `caelestia` command itself.

## Usage

The notch shows the clock at rest and takes over on its own for notifications
and volume/microphone/brightness. The expanded views are opened by click or IPC:

| | |
| --- | --- |
| **Left click the notch** | calendar |
| **Right click the notch** | system resources |

```sh
qs ipc -c caelestia call island toggleCalendar
qs ipc -c caelestia call island togglePerformance
qs ipc -c caelestia call island togglePlayer
qs ipc -c caelestia call island close
```

Bind any of those in `~/.config/hypr/hypr-user.lua` if you want them on keys.

A notification or a volume change interrupts whatever is expanded and hands it
back afterwards — the expanded view is a state the user set, transient layers
only borrow the notch.

## Layout

```
shell/
├── shell.qml
├── modules/
│   ├── island/       the notch
│   ├── bar/ drawers/ launcher/ lock/ sidebar/ …
│   ├── notifications/  popups collapsed — the notch renders them
│   └── …
├── services/         Notifs Audio Brightness Players Colours …
├── components/       StyledRect StyledText MaterialIcon …
└── utils/
scripts/              install, restart
docs/                 architecture, divergence from Caelestia
```

The island module:

| File | Role |
| --- | --- |
| `Island.qml` | one window per screen, IPC |
| `IslandWindow.qml` | the state machine and the morphing capsule |
| `IslandTokens.qml` | Tide's sizes, radii, hold times and type scale |
| `IslandConfig.qml` | the island's settings, and their file |
| `SlidingLayer.qml` | a page and how far it is from the middle |
| `IslandText.qml` | the notch's type, in the shell's typeface |
| `ClockLayer.qml` `DatePreviewLayer.qml` `LyricsLayer.qml` | the three resting pages |
| `CavaBars.qml` `LyricsProvider.qml` | the visualiser and the lyrics helper |
| `OsdWatcher.qml` `OsdLayer.qml` `ProgressRing.qml` | levels |
| `EventWatcher.qml` `EventLayer.qml` | everything else worth announcing |
| `NotificationQueue.qml` `NotificationLayer.qml` `NotificationCenterLayer.qml` | notifications, and their history |
| `PlayerLayer.qml` `MediaBlock.qml` | now playing |
| `ControlLayer.qml` | the control centre |
| `FileShelf.qml` `ShelfLayer.qml` | the file shelf |
| `CalendarLayer.qml` `Calendar.qml` | the calendar, ported from the dashboard |
| `PerformanceLayer.qml` `Performance.qml` | system resources, ported from the dashboard |
| `IslandActions.qml` | the island's only buttons |
| `overview/` | the workspace overview, in a window of its own |

## Divergence from Caelestia

Caelestia's dashboard is removed and its calendar and performance views live in
the island now; a handful of other files changed to make room for the notch.
All of it is listed with rationale in [docs/DIVERGENCE.md](docs/DIVERGENCE.md).

## Credits and license

GPL-3.0, as a derivative of Caelestia and of Tide Island's design. See
[NOTICE](NOTICE) — the island module contains no Tide Island code, but the idea
and the layer set are theirs.
