pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// The long capsule: one line about something that just changed.
//
// Workspace switches just say "Workspace N" -- no dot-per-workspace
// indicator, since the number already says where you landed and the row of
// dots was one more thing to parse for the same information. Everything
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
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            hero: root.isWorkspace
            animate: root.isWorkspace
            text: root.isWorkspace ? `${root.title} ${Hypr.activeWsId}` : (root.detail.length > 0 ? `${root.title} · ${root.detail}` : root.title)
            color: root.isWorkspace ? Colours.palette.m3primary : Colours.palette.m3onSurface
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
