pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.modules.island.overview
import qs.services

// The workspace overview, as a panel of the notch rather than a window of its
// own -- every workspace on this screen, to scale, one morph away from the
// clock instead of a separate full-screen surface.
SlidingLayer {
    id: root

    required property var island

    readonly property var monitor: Hypr.monitorFor(root.island.screen)

    // Workspaces on this monitor, plus one empty one to move things into,
    // which is how you get a new workspace out of the overview.
    readonly property var workspaces: {
        const own = [...Hypr.workspaces.values].filter(w => !w.name.startsWith("special:") && w.monitor === root.monitor).sort((a, b) => a.id - b.id);
        const ids = own.map(w => w.id);
        const next = (ids.length ? Math.max(...ids) : 0) + 1;
        return [...ids, next];
    }

    implicitWidth: IslandTokens.overviewWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.extraLarge * 2

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.extraLarge

        spacing: Tokens.spacing.large

        // Reserves the space IslandSwitcher floats above, fixed at the top of
        // every panel -- see IslandTokens.switcherReserve.
        Item {
            Layout.preferredHeight: IslandTokens.switcherReserve
        }

        GridLayout {
            Layout.fillWidth: true

            columns: Math.min(3, root.workspaces.length)
            rowSpacing: Tokens.spacing.large
            columnSpacing: Tokens.spacing.large

            Repeater {
                model: root.workspaces

                WorkspaceCard {
                    required property int modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: width * (root.island.screen.height / root.island.screen.width)

                    workspaceId: modelData
                    screen: root.island.screen
                    clients: [...Hypr.toplevels.values].filter(t => t.workspace?.id === modelData)
                    capturesLive: root.island.panel === IslandWindow.State.Overview

                    onActivated: {
                        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${modelData}" })` : `workspace ${modelData}`);
                        root.island.close();
                    }
                }
            }
        }
    }
}
