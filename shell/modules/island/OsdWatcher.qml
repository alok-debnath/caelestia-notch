pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Turns volume, microphone and brightness changes into a transient island
// layer.
//
// All three come from Caelestia's own services, so there is no polling, no
// pactl subscription and no udev watching to do here -- Audio is PipeWire-backed
// and Brightness already tracks the backlight per screen.
QtObject {
    id: root

    enum Kind {
        Volume,
        Microphone,
        Brightness
    }

    property Brightness.Monitor monitor

    readonly property bool showing: hideTimer.running
    property int kind: OsdWatcher.Kind.Volume
    property real value
    property bool muted

    // Services emit on startup as they populate, which would flash the OSD the
    // moment the shell starts. Nothing is shown until the first real change.
    property bool ready

    function trigger(newKind: int, newValue: real, newMuted: bool): void {
        if (!ready)
            return;

        kind = newKind;
        value = newValue;
        muted = newMuted;
        hideTimer.restart();
    }

    readonly property Timer readyTimer: Timer {
        running: true
        interval: 1000
        onTriggered: root.ready = true
    }

    readonly property Timer hideTimer: Timer {
        interval: IslandTokens.osdHideDelay
    }

    readonly property Connections audioConn: Connections {
        target: Audio

        function onVolumeChanged(): void {
            root.trigger(OsdWatcher.Kind.Volume, Audio.volume, Audio.muted);
        }

        function onMutedChanged(): void {
            root.trigger(OsdWatcher.Kind.Volume, Audio.volume, Audio.muted);
        }

        function onSourceVolumeChanged(): void {
            root.trigger(OsdWatcher.Kind.Microphone, Audio.sourceVolume, Audio.sourceMuted);
        }

        function onSourceMutedChanged(): void {
            root.trigger(OsdWatcher.Kind.Microphone, Audio.sourceVolume, Audio.sourceMuted);
        }
    }

    readonly property Connections brightnessConn: Connections {
        target: root.monitor

        function onBrightnessChanged(): void {
            root.trigger(OsdWatcher.Kind.Brightness, root.monitor?.brightness ?? 0, false);
        }
    }
}
