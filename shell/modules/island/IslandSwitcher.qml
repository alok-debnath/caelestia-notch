pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The panel switcher: one pill, fixed at the same spot above every panel, so
// jumping between Calendar/Performance/notifications/the overview never
// means hunting for where the switcher landed this time -- it doesn't move.
//
// Hovering an icon switches straight to it, the same way the capsule itself
// opens on hover: no click in between wanting a panel and seeing it. A click
// on the icon that is already active closes the panel instead, since hover
// alone can only ever open or switch, never close.
StyledRect {
    id: root

    required property var island

    readonly property list<var> items: [
        { icon: "calendar_month", state: IslandWindow.State.Calendar },
        { icon: "monitoring", state: IslandWindow.State.Performance },
        { icon: "inbox", state: IslandWindow.State.NotifCenter },
        { icon: "grid_view", state: IslandWindow.State.Overview }
    ]

    readonly property int activeIndex: {
        for (let i = 0; i < items.length; i++)
            if (items[i].state === island.islandState)
                return i;
        return -1;
    }

    readonly property real cellSize: IslandTokens.switcherHeight
    readonly property real rimPadding: Tokens.padding.extraSmall / 2

    implicitWidth: cellSize * items.length + rimPadding * 2
    implicitHeight: cellSize + rimPadding * 2
    radius: height / 2
    color: Colours.tPalette.m3surfaceContainer

    // The sliding highlight behind whichever icon is active.
    Rectangle {
        x: Math.max(0, root.activeIndex) * root.cellSize + root.rimPadding
        y: root.rimPadding
        width: root.cellSize
        height: root.cellSize
        radius: width / 2
        color: Colours.palette.m3primaryContainer
        visible: root.activeIndex >= 0

        Behavior on x {
            Anim {
                type: Anim.FastEffects
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: root.items

            Item {
                id: cell

                required property var modelData
                required property int index

                width: root.cellSize
                height: root.cellSize

                MaterialIcon {
                    anchors.centerIn: parent

                    text: cell.modelData.icon
                    color: root.activeIndex === cell.index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.small
                    fill: root.activeIndex === cell.index ? 1 : 0

                    Behavior on color {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                HoverHandler {
                    onHoveredChanged: if (hovered && root.island.panel !== cell.modelData.state)
                        root.island.openPanel(cell.modelData.state)
                }

                TapHandler {
                    onTapped: if (root.island.panel === cell.modelData.state)
                        root.island.openPanel(cell.modelData.state)
                }
            }
        }
    }
}
