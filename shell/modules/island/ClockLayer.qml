pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The resting layer: just the time, sized to the notch.
Item {
    id: root

    implicitWidth: label.implicitWidth + IslandTokens.horizontalPadding * 2
    implicitHeight: label.implicitHeight + IslandTokens.verticalPadding * 2

    StyledText {
        id: label

        anchors.centerIn: parent

        animate: true
        // Time.timeStr joins its parts with colons so callers can split them;
        // the notch wants a readable string, and amPmStr is empty on 24h.
        text: Time.amPmStr ? `${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr}` : `${Time.hourStr}:${Time.minuteStr}`
        font: Tokens.font.clock.size(Tokens.font.title.medium.pointSize).weight(Font.Medium).build()
        color: Colours.palette.m3onSurface
    }
}
