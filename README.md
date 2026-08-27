# caelestia-notch

A Hyprland desktop shell: [Caelestia](https://github.com/caelestia-dots/shell)
with a Dynamic-Island-style notch built into it as a native module.

Not a fork that tracks upstream, and not a patch set over someone else's tree —
this is the shell, maintained here, edited directly.

Built on Fedora 44 + Hyprland + Quickshell 0.3.1.

## What the notch is

A notch that grows out of the top border as one continuous surface, carrying the
clock at rest and morphing to show notifications, volume, microphone, brightness,
the current track, a calendar, system resources, notification history, clipboard
history, a file shelf, a kitchen timer, the wallpaper picker, a face scan and an
app search -- plus the workspace overview.

Its **geometry, type scale and motion are Tide Island's**: every state morphs the
capsule to a fixed size and the content lays out inside it, rather than the
capsule sizing itself to whatever is in it. That table -- 140x38 at rest, 220 for
a line of text, 410x190 for the player, 760 for the overview, 400ms of OutQuint
between them -- lives in `IslandTokens.qml`, and is most of why the notch reads
as one object changing shape rather than a set of popups.

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
and volume/microphone/brightness. **Hover** it to expand; the capsule itself is
never clickable, so crossing it on the way somewhere else does nothing. The
buttons inside the expanded view open the rest, and every view has an IPC call:

```sh
qs ipc -c caelestia call island toggleSearch        # the launcher, in the notch
qs ipc -c caelestia call island togglePerformance
qs ipc -c caelestia call island togglePlayer
qs ipc -c caelestia call island toggleNotifications
qs ipc -c caelestia call island toggleClipboard
qs ipc -c caelestia call island clearClipboard
qs ipc -c caelestia call island toggleShelf
qs ipc -c caelestia call island pasteFile
qs ipc -c caelestia call island toggleWallpapers
qs ipc -c caelestia call island overview
qs ipc -c caelestia call island timer               # and timerToggle, timerReset, timerSet <minutes>
qs ipc -c caelestia call island nextPage            # the resting pages, without swiping
qs ipc -c caelestia call island previousPage
qs ipc -c caelestia call island close
```

Bind any of those in `~/.config/hypr/hypr-user.lua` if you want them on keys.

Drag across the notch to move between its three resting pages -- the date, the
clock, and whatever is playing. Drop a file on it to put it on the shelf.

### The launcher is the notch

**Caelestia's launcher opens in the notch, not in a drawer.** Not a second
launcher living beside it -- the same one, in a different shape. The drawer at
the bottom of the screen is gone; the capsule grows into a search field with the
results hanging below it inside the same surface.

It is `modules/launcher/ContentList` hosted by the island, so everything the
launcher does, it does here:

| | |
| --- | --- |
| apps | fuzzy or exact, ordered by how often you launch them, favourites first |
| `>` | actions -- whatever is in `launcher.actions` |
| `>calc ` | the calculator |
| `>scheme ` `>variant ` | colour schemes and Material variants |
| `>wallpaper ` | the wallpaper picker, previewing as you move |
| `:i ` `:c ` `:d ` `:e ` `:w ` `:g ` `:k ` `:t ` | search by id, category, comment, exec, window class, generic name, keywords, terminal-only |

Every keybind is the one you already have: `SUPER + D`, `caelestia shell drawers
toggle launcher`, `qs ipc call island toggleSearch` -- all of them set the same
`screenState.launcher` flag, and the notch is what answers it now. Enter
launches, Escape closes, up/down and the vim keys move, clicking away closes.

To hand it back to the drawer, set `drawerEnabled: true` in
`modules/launcher/Wrapper.qml`.

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
| `Island.qml` | one notch per screen, and the `island` / `faceId` IPC handlers |
| `IslandWindow.qml` | the state machine and the morphing capsule |
| `IslandTokens.qml` | Tide's sizes, radii, hold times and type scale |
| `IslandConfig.qml` | the island's settings, and their file |
| `IslandLayer.qml` | one non-resting layer, and the size it lays out at |
| `SlidingLayer.qml` | a page of the notch that can slide |
| `IslandText.qml` `IslandRollText.qml` | the notch's type, and a label that rolls rather than blinks |
| `MarqueeText.qml` | a title too long for the capsule |
| **Resting** | |
| `RestingPage.qml` `PageDots.qml` | one side of Tide's resting strip, and where you are in it |
| `ClockLayer.qml` `ClockText.qml` | the clock, one rolling glyph per character |
| `DatePreviewLayer.qml` `StripItem.qml` `BatteryPill.qml` | the left page: date, readings, charge |
| `LyricsLayer.qml` `LyricsProvider.qml` `CavaBars.qml` | the right page: cover, synced line, visualiser |
| `WallpaperLayer.qml` | Tide's wallpaper switcher, the library as one strip |
| **Transient** | |
| `OsdWatcher.qml` `OsdLayer.qml` `ProgressRing.qml` | volume, microphone, brightness |
| `EventWatcher.qml` `EventLayer.qml` | everything else worth announcing, in one line |
| `NotificationQueue.qml` `NotificationLayer.qml` | notifications, one at a time, at Tide's metrics |
| `BluetoothWatcher.qml` `BluetoothLayer.qml` | a device connecting or disconnecting |
| `FaceIdWatcher.qml` `FaceIdLayer.qml` `FaceIdGlyph.qml` | biopass face scans, the mark drawn rather than a font glyph |
| **Expanded** | |
| `PlayerLayer.qml` `MediaBlock.qml` `TransportButton.qml` | now playing, and its transport |
| `NotificationCenterLayer.qml` | everything that came through and is still around |
| `ClipboardLayer.qml` `Clipboard.qml` | clipboard history, backed by `cliphist` |
| `FileShelf.qml` `ShelfLayer.qml` `ShelfBubble.qml` | the file shelf, and what is on it |
| `LauncherLayer.qml` | Caelestia's launcher, hosted in the notch |
| `CalendarLayer.qml` `Calendar.qml` | the calendar, ported from the dashboard |
| `PerformanceLayer.qml` `Performance.qml` | system resources, ported from the dashboard |
| `IslandTimer.qml` `TimerPage.qml` `TimerDial.qml` `TimerButton.qml` `TimerBubble.qml` | Tide's kitchen timer, and its bubble |
| `OverviewLayer.qml` `overview/` | the workspace overview, morphed out of the notch |

## Divergence from Caelestia

Caelestia's dashboard is removed and its calendar and performance views live in
the island now; a handful of other files changed to make room for the notch.
All of it is listed with rationale in [docs/DIVERGENCE.md](docs/DIVERGENCE.md).

## Credits and license

GPL-3.0, as a derivative of Caelestia and of Tide Island's design. See
[NOTICE](NOTICE) — the island module contains no Tide Island code, but the idea
and the layer set are theirs.
