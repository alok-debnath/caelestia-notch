pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

// System resources, expanded out of the notch.
//
// The readings are the dashboard's; the layout is not. A dashboard could spend
// a full screen on them, the notch cannot, so Performance.qml lays the same
// numbers out as rows instead of cards.
SlidingLayer {
    id: root

    required property var island

    implicitHeight: layout.implicitHeight + IslandTokens.panelPadding + IslandTokens.panelTopReserve

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        // Top-anchored, not centred: a centred layout ignores the top
        // reserve and splits the extra height evenly instead, which is what
        // made this panel sit lower than the ones that anchor to the top.
        anchors.top: parent.top
        anchors.margins: IslandTokens.panelPadding
        anchors.topMargin: IslandTokens.panelTopReserve

        spacing: Tokens.spacing.small


        Performance {
            Layout.fillWidth: true
        }
    }
}
