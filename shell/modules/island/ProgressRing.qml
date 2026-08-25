pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A small circular level indicator. Canvas rather than an arc shape so it stays
// crisp at the sizes the notch uses, and repaints only when the value moves.
Item {
    id: root

    required property real value

    property color trackColour: Colours.palette.m3surfaceContainerHighest
    property color fillColour: Colours.palette.m3primary

    implicitWidth: IslandTokens.progressSize
    implicitHeight: IslandTokens.progressSize

    // Smoothed rather than a fresh animation per step: holding a volume key
    // sets the level several times a second, and restarting a 200ms curve on
    // every one of them makes the ring stutter behind the figure. Tide's
    // numbers -- the velocity is the cap, the duration is the settle.
    Behavior on value {
        SmoothedAnimation {
            velocity: 1.2
            duration: 180
            easing.type: Easing.InOutQuad
        }
    }

    onValueChanged: canvas.requestPaint()
    onTrackColourChanged: canvas.requestPaint()
    onFillColourChanged: canvas.requestPaint()

    Canvas {
        id: canvas

        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            const thickness = IslandTokens.progressThickness;
            const radius = (Math.min(width, height) - thickness) / 2;
            const cx = width / 2;
            const cy = height / 2;

            ctx.reset();
            ctx.lineWidth = thickness;
            ctx.lineCap = "round";

            ctx.beginPath();
            ctx.strokeStyle = root.trackColour;
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.stroke();

            if (root.value <= 0)
                return;

            // Start at twelve o'clock and sweep clockwise.
            const start = -Math.PI / 2;
            ctx.beginPath();
            ctx.strokeStyle = root.fillColour;
            ctx.arc(cx, cy, radius, start, start + Math.PI * 2 * Math.min(1, root.value));
            ctx.stroke();
        }
    }
}
