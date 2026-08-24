pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// The middle resting page: the time, and nothing else.
SlidingLayer {
    id: root

    IslandText {
        anchors.centerIn: parent

        hero: true
        animate: true
        // Time.timeStr joins its parts with colons so callers can split them;
        // the notch wants a readable string, and amPmStr is empty on 24h.
        text: Time.amPmStr ? `${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr}` : `${Time.hourStr}:${Time.minuteStr}`
    }
}
