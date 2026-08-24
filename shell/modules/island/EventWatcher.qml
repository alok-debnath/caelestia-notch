pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.services

// Everything the notch announces that is not a notification and not a level.
//
// These are all state changes the shell already tracks -- a workspace switch, a
// lock key, the charger, a bluetooth device, the recorder, do-not-disturb --
// so the watcher only has to notice them and describe them. Nothing here polls
// or talks to a bus of its own.
QtObject {
    id: root

    enum Kind {
        Workspace,
        Lock,
        Power,
        Bluetooth,
        Recording,
        Dnd,
        GameMode,
        Idle,
        Media
    }

    // A panel the user opened is not interrupted by a workspace switch.
    property bool blocked

    readonly property bool showing: hideTimer.running && !blocked
    property int kind: EventWatcher.Kind.Workspace
    property string icon: ""
    property string title: ""
    property string detail: ""

    // Services emit as they populate at startup, which would fire an event for
    // every one of them the moment the shell starts.
    property bool ready

    function trigger(newKind: int, newIcon: string, newTitle: string, newDetail: string): void {
        if (!ready || blocked)
            return;

        kind = newKind;
        icon = newIcon;
        title = newTitle;
        detail = newDetail;
        hideTimer.restart();
    }

    readonly property Timer readyTimer: Timer {
        running: true
        interval: 1500
        onTriggered: root.ready = true
    }

    readonly property Timer hideTimer: Timer {
        interval: IslandTokens.splitHideDelay
    }

    readonly property Connections workspaceConn: Connections {
        target: Hypr

        function onActiveWsIdChanged(): void {
            const ws = Hypr.focusedWorkspace;
            const name = ws?.name ?? `${Hypr.activeWsId}`;
            // Named workspaces are worth showing as their name; numbered ones
            // are already in the big number the layer draws.
            root.trigger(EventWatcher.Kind.Workspace, "web_asset", qsTr("Workspace"), name === `${Hypr.activeWsId}` ? "" : name);
        }

        function onCapsLockChanged(): void {
            root.trigger(EventWatcher.Kind.Lock, Hypr.capsLock ? "keyboard_capslock" : "keyboard_capslock_badge", qsTr("Caps Lock"), Hypr.capsLock ? qsTr("On") : qsTr("Off"));
        }

        function onNumLockChanged(): void {
            root.trigger(EventWatcher.Kind.Lock, "dialpad", qsTr("Num Lock"), Hypr.numLock ? qsTr("On") : qsTr("Off"));
        }
    }

    readonly property Connections powerConn: Connections {
        target: UPower

        function onOnBatteryChanged(): void {
            const dev = UPower.displayDevice;
            const perc = Math.round((dev?.percentage ?? 0) * 100);
            if (UPower.onBattery)
                root.trigger(EventWatcher.Kind.Power, "power_off", qsTr("On battery"), `${perc}%`);
            else
                root.trigger(EventWatcher.Kind.Power, "power", qsTr("Charging"), `${perc}%`);
        }
    }

    readonly property Connections recorderConn: Connections {
        target: Recorder

        function onRunningChanged(): void {
            root.trigger(EventWatcher.Kind.Recording, Recorder.running ? "screen_record" : "stop_circle", qsTr("Recording"), Recorder.running ? qsTr("Started") : qsTr("Stopped"));
        }

        function onPausedChanged(): void {
            if (Recorder.running)
                root.trigger(EventWatcher.Kind.Recording, "screen_record", qsTr("Recording"), Recorder.paused ? qsTr("Paused") : qsTr("Resumed"));
        }
    }

    readonly property Connections dndConn: Connections {
        target: Notifs

        function onDndChanged(): void {
            root.trigger(EventWatcher.Kind.Dnd, Notifs.dnd ? "notifications_off" : "notifications", qsTr("Do Not Disturb"), Notifs.dnd ? qsTr("On") : qsTr("Off"));
        }
    }

    readonly property Connections gameModeConn: Connections {
        target: GameMode

        function onEnabledChanged(): void {
            root.trigger(EventWatcher.Kind.GameMode, "sports_esports", qsTr("Game mode"), GameMode.enabled ? qsTr("On") : qsTr("Off"));
        }
    }

    readonly property Connections idleConn: Connections {
        target: IdleInhibitor

        function onEnabledChanged(): void {
            root.trigger(EventWatcher.Kind.Idle, IdleInhibitor.enabled ? "coffee" : "bedtime", qsTr("Keep awake"), IdleInhibitor.enabled ? qsTr("On") : qsTr("Off"));
        }
    }

    // A player changing track is worth announcing, but a player that is merely
    // seeking or buffering is not, so this watches the title rather than the
    // metadata as a whole.
    readonly property Connections mediaConn: Connections {
        target: Players.active ?? null

        function onTrackTitleChanged(): void {
            const player = Players.active;
            if (!player?.trackTitle)
                return;
            root.trigger(EventWatcher.Kind.Media, "music_note", player.trackTitle, player.trackArtist ?? "");
        }
    }

    // One Connections per device: Bluetooth.devices is a model, and the thing
    // worth announcing is a single device's connected state flipping.
    readonly property Instantiator btDevices: Instantiator {
        model: Bluetooth.devices

        delegate: QtObject {
            required property BluetoothDevice modelData

            readonly property Connections conn: Connections {
                target: modelData

                function onConnectedChanged(): void {
                    const dev = modelData;
                    root.trigger(EventWatcher.Kind.Bluetooth, dev.connected ? "bluetooth_connected" : "bluetooth_disabled", dev.name, dev.connected ? qsTr("Connected") : qsTr("Disconnected"));
                }
            }
        }
    }
}
