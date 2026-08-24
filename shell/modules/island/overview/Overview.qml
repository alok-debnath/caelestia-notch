pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.modules.island
import qs.services

// The workspace overview: every workspace on the screen at once.
//
// Tide's overview is a window of its own rather than a state of the notch, and
// so is this one -- it covers the screen, takes the keyboard, and closes on Esc
// or on picking something. The notch opens it and then gets out of the way.
Scope {
    id: root

    Variants {
        model: Screens.screens

        PanelWindow {
            id: win

            required property var modelData

            readonly property var monitor: Hypr.monitorFor(modelData)

            // Workspaces on this monitor, plus one empty one to move things
            // into, which is how you get a new workspace out of an overview.
            readonly property var workspaces: {
                const own = [...Hypr.workspaces.values].filter(w => !w.name.startsWith("special:") && w.monitor === monitor).sort((a, b) => a.id - b.id);
                const ids = own.map(w => w.id);
                const next = (ids.length ? Math.max(...ids) : 0) + 1;
                return [...ids, next];
            }

            screen: modelData
            visible: OverviewState.visible
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "caelestia-overview"
            WlrLayershell.keyboardFocus: OverviewState.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // A plain Rectangle: StyledRect carries the shell's transparency
            // tokens, and the scrim wants to be exactly as dark as it says.
            Rectangle {
                anchors.fill: parent

                color: Qt.rgba(0, 0, 0, 0.55)

                MouseArea {
                    anchors.fill: parent
                    onClicked: OverviewState.close()
                }

                Keys.onEscapePressed: OverviewState.close()
                focus: true
            }

            GridLayout {
                anchors.centerIn: parent

                width: parent.width * 0.8
                columns: Math.min(3, win.workspaces.length)
                rowSpacing: Tokens.spacing.large
                columnSpacing: Tokens.spacing.large

                Repeater {
                    model: win.workspaces

                    WorkspaceCard {
                        required property int modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: width * (win.modelData.height / win.modelData.width)

                        workspaceId: modelData
                        screen: win.modelData
                        clients: [...Hypr.toplevels.values].filter(t => t.workspace?.id === modelData)

                        onActivated: {
                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${modelData}" })` : `workspace ${modelData}`);
                            OverviewState.close();
                        }
                    }
                }
            }
        }
    }
}
