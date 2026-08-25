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


        Item {
            Layout.fillWidth: true

            implicitHeight: calendar.implicitHeight

            Calendar {
                id: calendar

                // The panel already pads; the calendar padding itself would
                // sit the grid lower than every other panel's first row.
                padding: 0

                anchors.left: parent.left
                anchors.right: parent.right
            }
        }
    }
}
