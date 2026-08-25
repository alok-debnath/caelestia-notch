pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.island
import qs.services

// One workspace: the wallpaper it sits on and the windows on it, to scale.
//
// The card is the monitor in miniature -- same aspect, same window positions --
// so picking a workspace out of the grid is the same act as looking at the
// screen.
StyledClippingRect {
    id: root

    required property int workspaceId
    required property ShellScreen screen
    required property var clients

    readonly property bool active: workspaceId === Hypr.activeWsId
    readonly property real scaleFactor: width / screen.width
    readonly property var monitor: Hypr.monitorFor(screen)

    signal activated

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    border.width: active ? 2 : 1
    border.color: active ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

    Image {
        anchors.fill: parent

        source: Wallpapers.current ? `file://${Wallpapers.current}` : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 640
        asynchronous: true
        opacity: 0.5
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.activated()
    }

    Repeater {
        model: root.clients

        WindowThumb {
            required property var modelData

            client: modelData
            scaleFactor: root.scaleFactor
            // Window geometry is in compositor coordinates, which include the
            // monitor's own offset on a multi-head setup.
            originX: root?.monitor?.lastIpcObject.x ?? 0
            originY: root?.monitor?.lastIpcObject.y ?? 0

            onActivated: root.activated()
        }
    }

    // Dropping a window here moves it to this workspace.
    DropArea {
        anchors.fill: parent

        onDropped: drop => {
            const client = drop.source?.client;
            if (client && client.workspace?.id !== root.workspaceId)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${client.address}", workspace = "${root.workspaceId}", follow = false })` : `movetoworkspacesilent ${root.workspaceId},address:0x${client.address}`);
            drop.accept();
        }
    }

    IslandText {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.medium

        text: `${root.workspaceId}`
        color: root.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        font.pixelSize: IslandTokens.bodyPixelSize
    }
}
