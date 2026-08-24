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

    implicitHeight: layout.implicitHeight + Tokens.padding.extraLarge * 2

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.extraLarge

        spacing: Tokens.spacing.small

        IslandActions {
            Layout.alignment: Qt.AlignHCenter

            island: root.island
        }

        Performance {
            Layout.fillWidth: true
        }
    }
}
