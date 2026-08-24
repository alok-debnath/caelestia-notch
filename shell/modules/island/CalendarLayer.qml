pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

// The calendar, expanded out of the notch.
//
// Ported from Caelestia's dashboard, which this shell no longer has. The
// calendar itself is unchanged apart from owning its own view date; all this
// wrapper does is give it a width to lay out in, since in the dashboard it
// filled a grid cell.
Item {
    id: root

    readonly property alias viewDate: calendar.viewDate

    implicitWidth: IslandTokens.calendarWidth
    implicitHeight: calendar.implicitHeight

    Calendar {
        id: calendar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }
}
