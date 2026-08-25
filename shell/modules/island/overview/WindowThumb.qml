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
    signal closeRequested

    // The cell's own corner radii, so a window that reaches into a corner can
    // take that corner's curve instead of cutting across it.
    property real cornerTopLeft: 0
    property real cornerTopRight: 0
    property real cornerBottomLeft: 0
    property real cornerBottomRight: 0

    // What a window is rounded by when it is nowhere near an edge.
    property real baseRadius: 10

    readonly property var geometry: client?.lastIpcObject ?? null

    // Distance from each edge of the cell. Tide's own rule: a corner's radius
    // is the *cell's* radius pulled in by however far the window sits from
    // that corner, floored at the plain window radius -- so a maximised window
    // matches the cell exactly, one with a gap around it is a plain rounded
    // rectangle, and a tiled one follows whichever edges it touches. Without
    // it, a full-screen window draws a second, tighter outline just inside the
    // workspace's own, which is the mismatch you see on the active cell.
    readonly property real distLeft: Math.max(0, x)
    readonly property real distRight: Math.max(0, (parent?.width ?? 0) - (x + width))
    readonly property real distTop: Math.max(0, y)
    readonly property real distBottom: Math.max(0, (parent?.height ?? 0) - (y + height))

    x: ((geometry?.at[0] ?? 0) - originX) * scaleFactor
    y: ((geometry?.at[1] ?? 0) - originY) * scaleFactor
    width: (geometry?.size[0] ?? 1) * scaleFactor
    height: (geometry?.size[1] ?? 1) * scaleFactor

    StyledClippingRect {
        id: frame

        anchors.fill: parent

        topLeftRadius: Math.max(root.cornerTopLeft - Math.max(root.distLeft, root.distTop), root.baseRadius)
        topRightRadius: Math.max(root.cornerTopRight - Math.max(root.distRight, root.distTop), root.baseRadius)
        bottomLeftRadius: Math.max(root.cornerBottomLeft - Math.max(root.distLeft, root.distBottom), root.baseRadius)
        bottomRightRadius: Math.max(root.cornerBottomRight - Math.max(root.distRight, root.distBottom), root.baseRadius)
        color: Colours.palette.m3surfaceContainer

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

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag.target: root
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        // Tide's own two: left goes to the window, right closes it where it
        // stands, without leaving the overview.
        onClicked: mouse => {
            if (drag.active)
                return;
            if (mouse.button === Qt.RightButton)
                root.closeRequested();
            else
                root.activated();
        }

        onReleased: if (drag.active)
            root.Drag.drop()
    }
}
