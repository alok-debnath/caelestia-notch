pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Tide's kitchen timer, which lives in the island rather than in an app.
//
// A singleton because the timer outlives the panel that set it: the player
// panel is where you dial it in, the capsule bubble is where you watch it, and
// closing the panel must not cancel it. Seconds are counted off a wall-clock
// deadline rather than by decrementing on a tick, so a slow frame or a
// suspended session cannot make the timer drift.
Singleton {
    id: root

    // What the dial is set to, and what a start would run for.
    property int selectedHours: 0
    property int selectedMinutes: 5

    readonly property int totalSeconds: selectedHours * 3600 + selectedMinutes * 60

    // Counting, or paused with time left on it.
    property bool running: false
    property bool active: false

    property int remainingSeconds: 0
    property double deadline: 0

    readonly property real progress: active && totalSeconds > 0 ? Math.max(0, Math.min(1, remainingSeconds / totalSeconds)) : 0

    // The one-shot at zero: the bubble flashes rather than the shell shouting.
    signal finished

    readonly property string remainingText: {
        const s = Math.max(0, remainingSeconds);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const sec = s % 60;
        const pad = v => v < 10 ? `0${v}` : `${v}`;
        return h > 0 ? `${h}:${pad(m)}:${pad(sec)}` : `${pad(m)}:${pad(sec)}`;
    }

    function setDuration(hours: int, minutes: int): void {
        selectedHours = Math.max(0, Math.min(23, hours));
        selectedMinutes = Math.max(0, Math.min(59, minutes));
        if (!active)
            remainingSeconds = totalSeconds;
    }

    function toggle(): void {
        if (running) {
            // Pause: keep what is left, drop the deadline.
            remainingSeconds = Math.max(0, Math.round((deadline - Date.now()) / 1000));
            running = false;
            return;
        }

        if (!active || remainingSeconds <= 0) {
            if (totalSeconds <= 0)
                return;
            remainingSeconds = totalSeconds;
        }

        active = true;
        running = true;
        deadline = Date.now() + remainingSeconds * 1000;
    }

    function reset(): void {
        running = false;
        active = false;
        remainingSeconds = totalSeconds;
        deadline = 0;
    }

    readonly property Timer tick: Timer {
        running: root.running
        repeat: true
        interval: 200

        onTriggered: {
            const left = Math.max(0, Math.round((root.deadline - Date.now()) / 1000));
            if (left === root.remainingSeconds && left > 0)
                return;

            root.remainingSeconds = left;
            if (left > 0)
                return;

            root.running = false;
            root.active = false;
            root.finished();
        }
    }
}
