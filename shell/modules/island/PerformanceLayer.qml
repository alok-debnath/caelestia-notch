pragma ComponentBehavior: Bound

import QtQuick

// System resources, expanded out of the notch.
//
// Ported from Caelestia's dashboard. The cards still read
// Config.dashboard.performance.* -- that config object is provided by
// Caelestia.Config and outlives the drawer it was named after, so the same
// settings keep working.
Item {
    id: root

    implicitWidth: performance.implicitWidth
    implicitHeight: performance.implicitHeight

    Performance {
        id: performance

        anchors.centerIn: parent
    }
}
