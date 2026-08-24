pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Services
import qs.services

// Tide's cava strip: fixed-width rounded bars that never drop to nothing.
//
// Caelestia has a visualiser of its own, but it is a wall-sized one -- bars as
// wide as the screen allows. This is the notch's: 4px bars, 3px apart, with a
// floor so the strip still reads as a strip when the track is quiet.
Item {
    id: root

    // Reading the service here is what keeps the cava subprocess alive, so the
    // strip is only mounted while something is playing.
    readonly property var levels: Audio.cava.values ?? []
    readonly property int barCount: Math.max(1, levels.length)

    implicitWidth: barCount * IslandTokens.barWidth + Math.max(0, barCount - 1) * IslandTokens.barSpacing
    implicitHeight: IslandTokens.barAreaHeight

    ServiceRef {
        service: Audio.cava
    }

    Row {
        anchors.fill: parent
        spacing: IslandTokens.barSpacing

        Repeater {
            model: root.barCount

            Rectangle {
                required property int index

                readonly property real level: Math.max(0, Math.min(1, root.levels[index] ?? 0))

                width: IslandTokens.barWidth
                height: IslandTokens.barMinHeight + (root.height - IslandTokens.barMinHeight) * level
                radius: width / 2
                color: Colours.palette.m3primary
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }
}
