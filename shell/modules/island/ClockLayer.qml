pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The middle resting page: the time, and nothing else.
SlidingLayer {
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

    IslandText {
        id: label

        anchors.centerIn: parent

        hero: true
        animate: true
        // Time.timeStr joins its parts with colons so callers can split them;
        // the notch wants a readable string, and amPmStr is empty on 24h.
        text: Time.amPmStr ? `${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr}` : `${Time.hourStr}:${Time.minuteStr}`
    }
}
