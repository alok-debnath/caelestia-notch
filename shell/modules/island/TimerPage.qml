pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Tide's kitchen timer: the ring on the left with what is left written across
// it, the dial and the two buttons on the right.
//
// The dial is scroll-and-drag rather than Tide's typed field. Typing into the
// island means taking the keyboard off the compositor for a panel that is
// opened by hovering, and a timer is two numbers -- a wheel is both faster and
// impossible to leave in a half-typed state. Scroll it, drag it up and down,
// or tap the halves.
Item {
    id: root

    // Smoothed so the ring sweeps rather than stepping once a second.
    property real ringProgress: IslandTimer.progress

    // Canvas only repaints when it is told to.
    onRingProgressChanged: ring.requestPaint()

    Behavior on ringProgress {
        NumberAnimation {
            duration: 700
            easing.type: Easing.InOutCubic
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 20
        anchors.bottomMargin: 26

        spacing: 18

        Item {
            width: 116
            height: parent.height

            Canvas {
                id: ring

                anchors.centerIn: parent

                width: 104
                height: 104

                readonly property color trackColour: Colours.palette.m3surfaceContainerHighest
                readonly property color fillColour: Colours.palette.m3primary

                onPaint: {
                    const ctx = getContext("2d");
                    const cx = width / 2;
                    const cy = height / 2;
                    const thickness = 5;
                    const radius = Math.min(width, height) / 2 - thickness / 2;
                    const start = -Math.PI / 2;
                    const progress = Math.max(0, Math.min(1, root.ringProgress));

                    ctx.reset();
                    ctx.lineCap = "round";
                    ctx.lineWidth = thickness;

                    ctx.beginPath();
                    ctx.strokeStyle = trackColour;
                    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                    ctx.stroke();

                    if (progress <= 0)
                        return;

                    // Anticlockwise, so the ring empties the way the time does.
                    ctx.beginPath();
                    ctx.strokeStyle = fillColour;
                    ctx.arc(cx, cy, radius, start, start - Math.PI * 2 * progress, true);
                    ctx.stroke();
                }
            }

            IslandText {
                anchors.centerIn: ring

                text: IslandTimer.active ? IslandTimer.remainingText : root.dialText
                font.pixelSize: IslandTokens.bodyPixelSize + (IslandTimer.remainingSeconds >= 3600 ? 2 : 8)
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Column {
            width: parent.width - 116 - 18
            anchors.verticalCenter: parent.verticalCenter

            spacing: 10

            Row {
                width: parent.width
                height: 42

                spacing: 8

                TimerDial {
                    width: (parent.width - 8) / 2
                    height: parent.height

                    label: qsTr("hr")
                    value: IslandTimer.selectedHours
                    maximum: 23
                    onValueRequested: v => IslandTimer.setDuration(v, IslandTimer.selectedMinutes)
                }

                TimerDial {
                    width: (parent.width - 8) / 2
                    height: parent.height

                    label: qsTr("min")
                    value: IslandTimer.selectedMinutes
                    maximum: 59
                    pad: true
                    onValueRequested: v => IslandTimer.setDuration(IslandTimer.selectedHours, v)
                }
            }

            Row {
                width: parent.width
                height: 34

                spacing: 8

                TimerButton {
                    width: (parent.width - 8) / 2
                    height: parent.height

                    label: {
                        if (IslandTimer.running)
                            return qsTr("Stop");
                        if (IslandTimer.active && IslandTimer.remainingSeconds > 0)
                            return qsTr("Continue");
                        return qsTr("Start");
                    }
                    accent: true
                    enabled: IslandTimer.running || IslandTimer.totalSeconds > 0
                    onTriggered: IslandTimer.toggle()
                }

                TimerButton {
                    width: (parent.width - 8) / 2
                    height: parent.height

                    label: qsTr("Reset")
                    enabled: IslandTimer.active || IslandTimer.remainingSeconds > 0
                    onTriggered: IslandTimer.reset()
                }
            }
        }
    }

    // What the ring says before anything is running: the dial, not zero, so
    // setting a timer shows you what you are about to start.
    readonly property string dialText: {
        const h = IslandTimer.selectedHours;
        const m = IslandTimer.selectedMinutes;
        const pad = v => v < 10 ? `0${v}` : `${v}`;
        return h > 0 ? `${h}:${pad(m)}:00` : `${pad(m)}:00`;
    }
}
