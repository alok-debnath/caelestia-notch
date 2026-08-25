pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// One half of the timer's dial: a number and what it counts.
//
// Tide types into these. The island cannot, sensibly: taking the keyboard off
// the compositor for a panel that opens on hover is a bad trade for two
// numbers. So this is a wheel -- scroll it, drag it up or down, or tap the top
// and bottom halves -- and it can never be left holding half a number.
StyledRect {
    id: root

    property string label
    property int value
    property int maximum: 59
    property bool pad: false

    signal valueRequested(value: int)

    readonly property string valueText: root.pad && root.value < 10 ? `0${root.value}` : `${root.value}`

    function step(by: int): void {
        // Wraps, so a long scroll never dead-ends at either extreme.
        const span = root.maximum + 1;
        root.valueRequested(((root.value + by) % span + span) % span);
    }

    radius: Tokens.rounding.large
    color: area.pressed ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainerHigh

    Behavior on color {
        CAnim {}
    }

    Row {
        anchors.centerIn: parent

        spacing: 6

        IslandRollText {
            anchors.verticalCenter: parent.verticalCenter

            hero: true
            text: root.valueText
        }

        IslandText {
            anchors.verticalCenter: parent.verticalCenter

            dim: true
            text: root.label
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent

        preventStealing: true

        onWheel: wheel => {
            root.step(wheel.angleDelta.y > 0 ? 1 : -1);
            wheel.accepted = true;
        }

        onClicked: mouse => root.step(mouse.y < height / 2 ? 1 : -1)
    }

    // The drag itself: vertical, one step per 12 pixels, in the direction the
    // hand moves.
    DragHandler {
        id: drag

        property real lastStep: 0

        target: null
        xAxis.enabled: false
        yAxis.enabled: true

        onActiveChanged: lastStep = 0

        onActiveTranslationChanged: {
            if (!active)
                return;
            const steps = Math.trunc(-activeTranslation.y / 12);
            if (steps === lastStep)
                return;
            root.step(steps - lastStep);
            lastStep = steps;
        }
    }
}
