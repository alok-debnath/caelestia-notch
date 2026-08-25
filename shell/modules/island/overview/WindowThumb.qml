pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.modules.island
import qs.services
import qs.utils

// One window in the overview, where it actually is on its workspace.
//
// The picture is a live screencopy of the window itself rather than an icon, so
// the overview is a view of the session rather than a diagram of it. Dragging
// one onto another workspace moves it there.
Item {
    id: root

    required property HyprlandToplevel client
    required property real scaleFactor
    required property real originX
    required property real originY
    property bool live: true

    signal activated

    readonly property var geometry: client?.lastIpcObject ?? null

    x: ((geometry?.at[0] ?? 0) - originX) * scaleFactor
    y: ((geometry?.at[1] ?? 0) - originY) * scaleFactor
    width: (geometry?.size[0] ?? 1) * scaleFactor
    height: (geometry?.size[1] ?? 1) * scaleFactor

    StyledClippingRect {
        id: frame

        anchors.fill: parent

        radius: Tokens.rounding.small
        color: Colours.palette.m3surfaceContainer
        border.width: root.client === Hypr.activeToplevel ? 2 : 0
        border.color: Colours.palette.m3primary

        ScreencopyView {
            anchors.fill: parent

            captureSource: root.client?.wayland ?? null // qmllint disable unresolved-type
            live: root.live
        }

        // Fallback for anything that will not capture -- xwayland windows that
        // have not mapped yet, mostly.
        MaterialIcon {
            anchors.centerIn: parent

            text: Icons.getAppCategoryIcon(root.geometry?.class ?? "", "desktop_windows")
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.builders.extraLarge.build()
            z: -1
        }
    }

    // Dragging is a real QML drag rather than a moved item, so the workspace
    // cards can accept the drop themselves instead of the thumbnail having to
    // work out where it was let go.
    Drag.active: dragArea.drag.active
    Drag.source: root
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    MouseArea {
        id: dragArea

        anchors.fill: parent

        drag.target: root
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        onClicked: if (!drag.active)
            root.activated()

        onReleased: if (drag.active)
            root.Drag.drop()
    }
}
