pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

// Everything that came through and is still around.
//
// Tide keeps its own notification history; this reads Notifs, the same list the
// sidebar shows, so dismissing something here dismisses it everywhere. The
// panel grows with its content up to a cap and then scrolls.
SlidingLayer {
    id: root

    required property var island

    readonly property list<NotifData> notifs: Notifs.notClosed

    implicitHeight: Math.min(IslandTokens.notifCenterMaxHeight, layout.implicitHeight + Tokens.padding.extraLarge * 2)

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraLarge

        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IslandText {
                Layout.fillWidth: true

                text: root.notifs.length > 0 ? qsTr("%1 notifications").arg(root.notifs.length) : qsTr("Nothing new")
                elide: Text.ElideRight
            }

            IconButton {
                icon: Notifs.dnd ? "notifications_off" : "notifications"
                type: IconButton.Text
                isToggle: true
                checked: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            IconButton {
                icon: "clear_all"
                type: IconButton.Text
                disabled: root.notifs.length === 0
                onClicked: {
                    for (const n of [...root.notifs])
                        n.close();
                }
            }
        }

        StyledListView {
            Layout.fillWidth: true
            // A ListView has no implicit height, and the capsule sizes itself
            // to this layer, so the list has to say how tall it wants to be.
            Layout.preferredHeight: Math.min(IslandTokens.notifCenterListHeight, contentHeight)

            model: root.notifs
            spacing: Tokens.spacing.extraSmall
            clip: true

            delegate: StyledRect {
                id: item

                required property NotifData modelData

                readonly property bool isCritical: modelData.urgency === NotificationUrgency.Critical

                width: ListView.view.width
                implicitHeight: itemLayout.implicitHeight + Tokens.padding.medium * 2
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.medium

                StateLayer {
                    radius: parent.radius
                    onClicked: item.modelData.close()
                }

                RowLayout {
                    id: itemLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.medium

                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter

                        text: Icons.getNotifIcon(item.modelData.summary, item.modelData.urgency)
                        color: item.isCritical ? Colours.palette.m3error : Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.builders.medium.build()
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        IslandText {
                            Layout.fillWidth: true

                            text: item.modelData.summary
                            color: item.isCritical ? Colours.palette.m3error : Colours.palette.m3onSurface
                            font.pixelSize: IslandTokens.bodyPixelSize - 2
                            elide: Text.ElideRight
                        }

                        IslandText {
                            Layout.fillWidth: true

                            dim: true
                            text: item.modelData.body
                            font.pixelSize: IslandTokens.bodyPixelSize - 3
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }
                    }

                    IslandText {
                        Layout.alignment: Qt.AlignVCenter

                        dim: true
                        text: item.modelData.timeStr
                        font.pixelSize: IslandTokens.bodyPixelSize - 4
                    }
                }
            }
        }

        IslandActions {
            Layout.alignment: Qt.AlignHCenter

            island: root.island
        }
    }
}
