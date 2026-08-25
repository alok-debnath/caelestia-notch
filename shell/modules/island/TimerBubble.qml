pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The running timer, as a bubble beside the capsule.
//
// Tide slides it out from *behind* the capsule's edge rather than fading it in
// beside it -- it starts overlapped, small and low, and rises into place, so it
// reads as something the island pushed out rather than as a second widget that
// appeared. It goes back the same way.
//
// It is only ever up while the island is resting: a panel or a notification is
// already the thing you are looking at.
Item {
    id: root

    // 0 tucked behind the capsule, 1 out beside it.
    property real reveal: 0

    // The one-shot when the timer reaches zero: a pulse in the scale and a
    // flash in the ring, then it puts itself away.
    property real pulse: 0
    property real flash: 0
    property bool completing: false

    readonly property bool wanted: (IslandTimer.active && IslandTimer.remainingSeconds > 0) || completing

    implicitWidth: 34
    implicitHeight: 34

    visible: reveal > 0.001 || completing
    scale: (0.55 + reveal * 0.45) * (1 + pulse * 0.12)
    transformOrigin: Item.Center

    onWantedChanged: {
        show.stop();
        hide.stop();
        (wanted ? show : hide).restart();
    }

    Connections {
        target: IslandTimer

        function onFinished(): void {
            root.completing = true;
            completion.restart();
        }
    }

    NumberAnimation {
        id: show

        target: root
        property: "reveal"
        to: 1
        duration: 360
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hide

        target: root
        property: "reveal"
        to: 0
        duration: 280
        easing.type: Easing.InCubic
    }

    SequentialAnimation {
        id: completion

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "pulse"
                from: 0
                to: 1
                duration: 140
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "flash"
                from: 0
                to: 1
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "pulse"
                from: 1
                to: 0
                duration: 380
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "flash"
                from: 1
                to: 0
                duration: 380
                easing.type: Easing.InOutQuad
            }
        }

        PauseAnimation {
            duration: 380
        }

        ScriptAction {
            script: root.completing = false
        }
    }

    StyledRect {
        anchors.fill: parent

        radius: width / 2
        color: Colours.tPalette.m3surfaceContainer
    }

    Canvas {
        id: ring

        anchors.fill: parent
        anchors.margins: 1

        readonly property real progress: IslandTimer.progress
        readonly property color trackColour: Colours.palette.m3surfaceContainerHighest
        readonly property color fillColour: root.completing ? Colours.palette.m3tertiary : Colours.palette.m3primary

        onProgressChanged: requestPaint()
        onTrackColourChanged: requestPaint()
        onFillColourChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const cx = width / 2;
            const cy = height / 2;
            const thickness = root.completing ? 3 + root.flash : 3;
            const radius = Math.min(width, height) / 2 - thickness / 2;
            const start = -Math.PI / 2;

            ctx.reset();
            ctx.lineCap = "round";
            ctx.lineWidth = thickness;

            ctx.beginPath();
            ctx.strokeStyle = trackColour;
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.stroke();

            if (root.completing) {
                // The flash: a soft full ring over the track, brightest at the
                // moment the timer lands.
                if (root.flash > 0) {
                    ctx.beginPath();
                    ctx.lineWidth = thickness + 1.5;
                    ctx.strokeStyle = Qt.rgba(fillColour.r, fillColour.g, fillColour.b, 0.35 * root.flash);
                    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                    ctx.stroke();
                }
                return;
            }

            if (progress <= 0)
                return;

            ctx.beginPath();
            ctx.strokeStyle = fillColour;
            ctx.arc(cx, cy, radius, start, start - Math.PI * 2 * progress, true);
            ctx.stroke();
        }
    }

    // Flashing at zero leaves nothing to read, so the bubble keeps the glyph.
    MaterialIcon {
        anchors.centerIn: parent

        text: "timer"
        color: root.completing ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.small
        fill: 1
        opacity: root.completing ? 1 : 0.75
    }

    // Repaint while it counts: the ring is a Canvas, and the progress only
    // moves once a second.
    Connections {
        target: root

        function onFlashChanged(): void {
            ring.requestPaint();
        }
    }
}
