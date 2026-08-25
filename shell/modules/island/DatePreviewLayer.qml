pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// The page left of the clock: what the machine is doing right now.
//
// Tide's left page is a *configured list* of small readings rather than a
// fixed widget -- date, battery, the level strip, the volume, the workspace,
// CPU, memory, disk -- so the strip says whatever you actually want to glance
// at (Panels -> Island -> Left page). It arrives from the right as the clock
// leaves to the left (see RestingPage), and the capsule is exactly as wide as
// the row it ends up with.
RestingPage {
    id: root

    readonly property real preferredWidth: Math.max(IslandTokens.swipeMinWidth, row.implicitWidth + IslandTokens.pagePadding * 2 + 28)

    side: -1

    Row {
        id: row

        anchors.centerIn: parent

        spacing: IslandTokens.contentSpacing * 3

        Repeater {
            model: IslandConfig.leftItems

            StripItem {
                required property string modelData

                anchors.verticalCenter: parent?.verticalCenter ?? undefined

                kind: modelData
            }
        }
    }
}
