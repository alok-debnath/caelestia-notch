# caelestia-notch

A Hyprland desktop shell: [Caelestia](https://github.com/caelestia-dots/shell)
with a Dynamic-Island-style notch built into it as a native module.

Not a fork that tracks upstream, and not a patch set over someone else's tree —
this is the shell, maintained here, edited directly.

Built on Fedora 44 + Hyprland + Quickshell 0.3.1.

## What the notch is

A notch that grows out of the top border as one continuous surface, carrying the
clock at rest and morphing to show notifications, volume, microphone, brightness
and the current track.

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
and volume/microphone/brightness. The only thing it needs to be told is the
player:

```sh
qs ipc -c caelestia call island togglePlayer
qs ipc -c caelestia call island showPlayer
qs ipc -c caelestia call island hidePlayer
```

Bind `togglePlayer` in `~/.config/hypr/hypr-user.lua` if you want it on a key.

## Layout

```
shell/
├── shell.qml
├── modules/
│   ├── island/       the notch
│   ├── bar/ drawers/ dashboard/ launcher/ lock/ …
│   ├── notifications/  popups collapsed — the notch renders them
│   └── …
├── services/         Notifs Audio Brightness Players Colours …
├── components/       StyledRect StyledText MaterialIcon …
└── utils/
scripts/              install, restart
docs/                 architecture, divergence from Caelestia
```

The island module is nine files:

| File | Role |
| --- | --- |
| `Island.qml` | one window per screen, IPC |
| `IslandWindow.qml` | layer priority, the morphing capsule |
| `IslandTokens.qml` | measurements |
| `OsdWatcher.qml` | turns Audio/Brightness changes into a transient layer |
| `NotificationQueue.qml` | feeds one notification at a time from `Notifs` |
| `ClockLayer.qml` `OsdLayer.qml` `NotificationLayer.qml` `PlayerLayer.qml` | the layers |
| `ProgressRing.qml` | the level ring |

## Divergence from Caelestia

Four files outside `modules/island/` differ from upstream Caelestia, all of them
to make room for the notch. They are listed with rationale in
[docs/DIVERGENCE.md](docs/DIVERGENCE.md).

## Credits and license

GPL-3.0, as a derivative of Caelestia and of Tide Island's design. See
[NOTICE](NOTICE) — the island module contains no Tide Island code, but the idea
and the layer set are theirs.
