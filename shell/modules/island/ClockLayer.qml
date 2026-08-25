pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The clock, when it is the only thing there is.
//
// Normally the time is drawn by whichever resting page is mounted -- the strip
// hands it back and forth as you swipe (see RestingPage). This layer is the
// fallback for a notch with both side pages turned off: then there is no page
// to carry the clock, and it needs one of its own.
Item {
    id: root

    // A dot while the screen is being recorded, as Tide has it: small enough
    // to live on the resting page, impossible to miss once you know it.
    StyledRect {
        id: dot

        anchors.right: label.left
        anchors.rightMargin: IslandTokens.contentSpacing
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: IslandTokens.barWidth + 2
        implicitHeight: implicitWidth
        radius: Tokens.rounding.full
        color: Colours.palette.m3error
        visible: Recorder.running
        opacity: Recorder.paused ? 0.4 : 1

        SequentialAnimation on opacity {
            running: Recorder.running && !Recorder.paused
            loops: Animation.Infinite

            NumberAnimation {
                to: 0.3
                duration: 900
                easing.type: Easing.InOutQuad
            }

            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutQuad
            }
        }
    }

    ClockText {
        id: label

        anchors.centerIn: parent

        text: Time.amPmStr ? `${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr}` : `${Time.hourStr}:${Time.minuteStr}`
    }
}
