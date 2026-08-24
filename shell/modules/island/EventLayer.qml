pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// The long capsule: one line about something that just changed.
//
// Workspace switches are the case Tide built it for, and they keep its
// treatment -- the number you landed on, with a dot per workspace. Everything
// else is an icon and a phrase.
SlidingLayer {
    id: root

    required property int kind
    required property string icon
    required property string title
    required property string detail

    readonly property bool isWorkspace: kind === EventWatcher.Kind.Workspace

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: IslandTokens.horizontalPadding * 0.875
        anchors.rightMargin: IslandTokens.horizontalPadding * 0.875
        anchors.verticalCenter: parent.verticalCenter

        spacing: IslandTokens.contentSpacing * 2

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter

            text: root.icon
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.builders.medium.build()
            fill: 1
            visible: !root.isWorkspace
        }

        IslandText {
            Layout.alignment: Qt.AlignVCenter

            hero: true
            animate: true
            text: `${Hypr.activeWsId}`
            color: Colours.palette.m3primary
            visible: root.isWorkspace
        }

        IslandText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: root.detail.length > 0 ? `${root.title} · ${root.detail}` : root.title
            elide: Text.ElideRight
            horizontalAlignment: root.isWorkspace ? Text.AlignLeft : Text.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter

            spacing: Tokens.spacing.extraSmall
            visible: root.isWorkspace

            Repeater {
                // Only the workspaces on this monitor, and never the special
                // ones -- they are not somewhere you switch to in sequence.
                model: [...Hypr.workspaces.values].filter(w => !w.name.startsWith("special:") && w.monitor === Hypr.focusedMonitor).sort((a, b) => a.id - b.id)

                StyledRect {
                    required property var modelData

                    readonly property bool active: modelData.id === Hypr.activeWsId

                    Layout.alignment: Qt.AlignVCenter

                    implicitWidth: active ? Tokens.padding.large : Tokens.padding.small
                    implicitHeight: Tokens.padding.small
                    radius: Tokens.rounding.full
                    color: active ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                    Behavior on implicitWidth {
                        Anim {}
                    }
                }
            }
        }
    }
}
