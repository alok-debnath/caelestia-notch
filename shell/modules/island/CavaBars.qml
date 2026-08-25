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

    // A fixed number of bars, not however many cava happens to report. The
    // service is configured for Caelestia's wall-sized visualiser, which is
    // sixty-odd; drawn at Tide's bar metrics that is a strip wider than the
    // whole notch. Each bar here stands for a slice of that spectrum.
    property int barCount: IslandTokens.mediaBarCount

    // Overridable so the same strip can be the wide one on the media page and
    // the short one beside a track title in the player panel.
    property real barWidth: IslandTokens.barWidth
    property real barSpacing: IslandTokens.barSpacing
    property real minBarHeight: IslandTokens.barMinHeight
    property color barColour: Colours.palette.m3primary

    function levelAt(i: int): real {
        const n = levels.length;
        if (n === 0)
            return 0;
        const from = Math.floor(i * n / barCount);
        const to = Math.max(from + 1, Math.floor((i + 1) * n / barCount));
        let sum = 0;
        for (let j = from; j < to; j++)
            sum += levels[j] ?? 0;
        return sum / (to - from);
    }

    implicitWidth: barCount * barWidth + Math.max(0, barCount - 1) * barSpacing
    implicitHeight: IslandTokens.barAreaHeight

    ServiceRef {
        service: Audio.cava
    }

    Row {
        anchors.fill: parent
        spacing: root.barSpacing

        Repeater {
            model: root.barCount

            Rectangle {
                required property int index

                readonly property real level: Math.max(0, Math.min(1, root.levelAt(index)))

                width: root.barWidth
                height: root.minBarHeight + (root.height - root.minBarHeight) * level
                radius: width / 2
                color: root.barColour
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
