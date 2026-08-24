pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// The left resting page: the date, with the time following it out.
//
// Tide slides the two past each other rather than swapping them, so the page
// reads as the clock turning into the date rather than as a second widget.
SlidingLayer {
    id: root

    readonly property real preferredWidth: date.implicitWidth + time.implicitWidth + IslandTokens.horizontalPadding * 4

    IslandText {
        id: date

        anchors.left: parent.left
        anchors.leftMargin: IslandTokens.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter

        hero: true
        animate: true
        text: Time.format("ddd, MMM dd")
    }

    IslandText {
        id: time

        anchors.right: parent.right
        anchors.rightMargin: IslandTokens.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter

        hero: true
        dim: true
        animate: true
        text: Time.amPmStr ? `${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr}` : `${Time.hourStr}:${Time.minuteStr}`
    }
}
