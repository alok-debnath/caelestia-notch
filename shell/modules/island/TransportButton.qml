pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// One transport control, the way Tide draws them: a bare glyph, no chrome, no
// hover fill. The only feedback is the press -- the glyph shrinks under the
// finger and springs back, which at this size reads better than a highlight
// behind something this thin.
Item {
    id: root

    property string icon
    property bool enabled: true

    signal triggered

    implicitWidth: 28
    implicitHeight: 28

    scale: area.pressed ? 0.8 : 1
    opacity: enabled ? 1 : 0.35

    Behavior on scale {
        NumberAnimation {
            duration: 100
        }
    }

    MaterialIcon {
        anchors.centerIn: parent

        text: root.icon
        color: area.pressed ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
        fontStyle: Tokens.font.icon.builders.large.build()
        fill: 1
    }

    MouseArea {
        id: area

        anchors.fill: parent
        // Tide's own overshoot: the glyph is small, the target is not.
        anchors.margins: -15

        enabled: root.enabled
        preventStealing: true

        onClicked: root.triggered()
    }
}
