pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.modules.island.overview
import qs.services

// The workspace overview, laid out the way Tide lays it out.
//
// Not a grid of cards: one slab. A fixed rows-by-columns block of cells with
// six pixels between them, the outer four corners rounded to 30 and every
// inner corner to 16, so the whole thing reads as one surface that has been
// scored rather than as a tray of tiles. Each cell is the monitor in miniature
// at a fixed scale -- same wallpaper, same window positions, same aspect --
// which is what makes picking a workspace out of it the same act as looking at
// the screen.
//
// The grid is fixed rather than following which workspaces exist, again as
// Tide has it: workspace 4 is always in the same place whether or not anything
// is on it, so the overview is a map you learn once.
SlidingLayer {
    id: root

    required property var island

    // Tide's own numbers.
    property int rows: IslandConfig.overviewRows
    property int columns: IslandConfig.overviewColumns
    property real scale: 0.18

    readonly property real cellSpacing: 6
    readonly property real outerPadding: 14
    readonly property real largeRadius: 30
    readonly property real smallRadius: 16

    readonly property var monitor: Hypr.monitorFor(root.island.screen)
    readonly property var monitorData: monitor?.lastIpcObject ?? null

    readonly property var reserved: monitorData?.reserved ?? [0, 0, 0, 0]
    readonly property real monitorScale: monitorData?.scale ?? 1

    // The usable area of a workspace, in *logical* pixels.
    //
    // Both halves of that matter. Hyprland reports a monitor's resolution in
    // physical pixels (1920 here) but window geometry and the reserved strip
    // in logical ones (1800 at a scale of 1.0667), so the two have to be put
    // in the same units before anything is divided by anything -- mixing them
    // drew every window about 6% small inside its cell, which is a gap down
    // the right and bottom edge of every workspace that should have been full.
    readonly property real logicalWidth: (monitorData?.width ?? root.island.screen.width) / monitorScale
    readonly property real logicalHeight: (monitorData?.height ?? root.island.screen.height) / monitorScale

    readonly property real usableWidth: Math.max(1, logicalWidth - reserved[0] - reserved[2])
    readonly property real usableHeight: Math.max(1, logicalHeight - reserved[1] - reserved[3])

    readonly property real cellWidth: Math.max(180, usableWidth * scale)
    readonly property real cellHeight: Math.max(120, usableHeight * scale)

    // How far a logical pixel moves inside a cell. The same number as `scale`
    // whenever the cell is not clamped by the minimums above.
    readonly property real thumbScale: cellWidth / usableWidth

    // Which block of `rows * columns` workspaces is on screen: with ten cells,
    // workspace 11 scrolls the whole map along rather than growing it.
    readonly property int perPage: rows * columns
    readonly property int page: Math.floor((Math.max(1, Hypr.activeWsId) - 1) / perPage)

    function workspaceAt(row: int, column: int): int {
        return page * perPage + row * columns + column + 1;
    }

    implicitWidth: grid.implicitWidth + outerPadding * 2
    implicitHeight: grid.implicitHeight + outerPadding + IslandTokens.panelTopReserve

    Column {
        id: grid

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: IslandTokens.panelTopReserve

        spacing: root.cellSpacing

        Repeater {
            model: root.rows

            Row {
                id: gridRow

                required property int index

                spacing: root.cellSpacing

                Repeater {
                    model: root.columns

                    StyledClippingRect {
                        id: cell

                        required property int index

                        readonly property int workspaceId: root.workspaceAt(gridRow.index, index)
                        readonly property bool active: workspaceId === Hypr.activeWsId
                        readonly property bool atLeft: index === 0
                        readonly property bool atRight: index === root.columns - 1
                        readonly property bool atTop: gridRow.index === 0
                        readonly property bool atBottom: gridRow.index === root.rows - 1
                        readonly property bool receiving: drop.containsDrag

                        implicitWidth: root.cellWidth
                        implicitHeight: root.cellHeight

                        // Only the slab's own four corners are round; every
                        // corner that meets another cell is the small radius.
                        topLeftRadius: atLeft && atTop ? root.largeRadius : root.smallRadius
                        topRightRadius: atRight && atTop ? root.largeRadius : root.smallRadius
                        bottomLeftRadius: atLeft && atBottom ? root.largeRadius : root.smallRadius
                        bottomRightRadius: atRight && atBottom ? root.largeRadius : root.smallRadius

                        color: Colours.tPalette.m3surfaceContainer

                        Image {
                            anchors.fill: parent

                            source: Wallpapers.current ? `file://${Wallpapers.current}` : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: Math.round(root.cellWidth * 1.75)
                            asynchronous: true
                            cache: true
                            opacity: 0.92
                        }

                        // Tide darkens every cell so the window previews read
                        // against the wallpaper, and lifts the one being
                        // dragged onto.
                        Rectangle {
                            anchors.fill: parent

                            color: cell.receiving ? Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.18) : Qt.rgba(0, 0, 0, 0.26)

                            Behavior on color {
                                CAnim {}
                            }
                        }

                        Repeater {
                            model: [...Hypr.toplevels.values].filter(t => t.workspace?.id === cell.workspaceId)

                            WindowThumb {
                                required property var modelData

                                client: modelData
                                scaleFactor: root.thumbScale
                                live: root.island.panel === IslandWindow.State.Overview
                                // Window geometry is in compositor
                                // coordinates, which include the monitor's own
                                // offset and its reserved strip.
                                originX: (root.monitorData?.x ?? 0) + root.reserved[0]
                                originY: (root.monitorData?.y ?? 0) + root.reserved[1]

                                cornerTopLeft: cell.topLeftRadius
                                cornerTopRight: cell.topRightRadius
                                cornerBottomLeft: cell.bottomLeftRadius
                                cornerBottomRight: cell.bottomRightRadius

                                onActivated: {
                                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${modelData.address}" })` : `focuswindow address:0x${modelData.address}`);
                                    root.island.close();
                                }

                                onCloseRequested: Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${modelData.address}" })` : `closewindow address:0x${modelData.address}`)
                            }
                        }

                        // The active workspace is outlined rather than filled:
                        // the cell already shows what is on it.
                        Rectangle {
                            anchors.fill: parent

                            color: "transparent"
                            border.width: cell.active ? 2 : 1
                            border.color: cell.active ? Colours.palette.m3primary : Qt.rgba(1, 1, 1, 0.12)
                            topLeftRadius: cell.topLeftRadius
                            topRightRadius: cell.topRightRadius
                            bottomLeftRadius: cell.bottomLeftRadius
                            bottomRightRadius: cell.bottomRightRadius
                        }

                        // Clicking the cell itself -- not a window on it --
                        // goes to that workspace. Below the thumbnails, so a
                        // window always wins the click.
                        MouseArea {
                            anchors.fill: parent

                            z: -1

                            onClicked: {
                                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${cell.workspaceId}" })` : `workspace ${cell.workspaceId}`);
                                root.island.close();
                            }
                        }

                        DropArea {
                            id: drop

                            anchors.fill: parent

                            onDropped: event => {
                                const client = event.source?.client;
                                if (client && client.workspace?.id !== cell.workspaceId)
                                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "address:0x${client.address}", workspace = "${cell.workspaceId}", follow = false })` : `movetoworkspacesilent ${cell.workspaceId},address:0x${client.address}`);
                                event.accept();
                            }
                        }

                        IslandText {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: Tokens.padding.small

                            text: `${cell.workspaceId}`
                            color: cell.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }
            }
        }
    }
}
