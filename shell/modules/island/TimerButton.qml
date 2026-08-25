pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// One of the timer's two buttons. Tide's proportions -- a wide, shallow,
// heavily rounded slab -- in Caelestia's colours: the primary one carries the
// action, the other is a quiet surface.
StyledRect {
    id: root

    property string label
    property bool accent: false
    property bool enabled: true

    signal triggered

    radius: Tokens.rounding.large
    color: {
        if (!root.enabled)
            return Colours.palette.m3surfaceContainer;
        if (root.accent)
            return area.pressed ? Colours.palette.m3primaryFixedDim : Colours.palette.m3primary;
        return area.pressed ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainerHigh;
    }
    opacity: root.enabled ? 1 : 0.5

    Behavior on color {
        CAnim {}
    }

    IslandText {
        anchors.centerIn: parent

        text: root.label
        color: root.accent && root.enabled ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
    }

    MouseArea {
        id: area

        anchors.fill: parent

        enabled: root.enabled
        preventStealing: true

        onClicked: root.triggered()
    }
}
