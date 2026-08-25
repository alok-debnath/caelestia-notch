pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

// The calendar, expanded out of the notch.
//
// Ported from Caelestia's dashboard, which this shell no longer has. The
// calendar itself is unchanged apart from owning its own view date; the wrapper
// gives it a width to lay out in and carries the island's actions, so the view
// closes from the same button that opened it.
SlidingLayer {
    id: root

    required property var island

    readonly property alias viewDate: calendar.viewDate

    implicitHeight: layout.implicitHeight + Tokens.padding.extraLarge * 2

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.extraLarge

        spacing: Tokens.spacing.small

        // Reserves the space IslandSwitcher floats above, fixed at the top of
        // every panel -- see IslandTokens.switcherReserve.
        Item {
            Layout.preferredHeight: IslandTokens.switcherReserve
        }

        Item {
            Layout.fillWidth: true

            implicitHeight: calendar.implicitHeight

            Calendar {
                id: calendar

                anchors.left: parent.left
                anchors.right: parent.right
            }
        }
    }
}
