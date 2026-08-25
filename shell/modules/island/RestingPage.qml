pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// One side of Tide's resting strip.
//
// The strip is one box, not a carousel. Tide swipes by moving *content*
// through that box: the clock leaves by the page's own edge exactly as the
// page's content arrives from the opposite one, so at no point are there two
// centred things, and at no point is the box empty. An earlier version of this
// island slid whole pages past each other instead -- it looked fine in
// isolation and wrong in motion, because the clock and the page were briefly
// two separate widgets crossing rather than one strip being pulled.
//
// `side` says which page this is: -1 for the page left of the clock, 1 for the
// page right of it. Everything else follows from that and from `offset`.
Item {
    id: root

    required property int side

    // How far this page is from the middle, in pages. 0 is fully arrived, 1 is
    // fully off; a drag puts it at fractions in between.
    property real offset: 0

    // Suspended while the finger is down: the strip follows it directly then,
    // and animating would make it lag the drag.
    property bool animated: true

    // Whether the clock half is drawn at all. A transient that came in from
    // this side has taken the clock's place in the box, so drawing it too
    // would put two things in there. Tide calls this `showSecondaryText`.
    property bool showClock: true

    // 0 at the clock, 1 at the page.
    readonly property real progress: 1 - Math.min(1, Math.abs(offset))

    // Tide animates the swipe position itself rather than the things that read
    // it, so the clock leaving and the content arriving cannot drift apart:
    // there is one number, and both halves are drawn from it.
    Behavior on offset {
        enabled: root.animated

        NumberAnimation {
            duration: IslandTokens.swipeDuration
            easing.type: Easing.OutCubic
        }
    }

    readonly property real innerWidth: Math.max(0, width - IslandTokens.pagePadding * 2)

    // Where each half sits when it is the one being shown, and where it is
    // parked when it is not: one `swipeHiddenPadding` past the box's edge, so
    // it is gone rather than clipped in half at the corner radius.
    readonly property real centredX: IslandTokens.pagePadding
    readonly property real contentHiddenX: side > 0 ? -innerWidth - IslandTokens.swipeHiddenPadding : width + IslandTokens.swipeHiddenPadding
    readonly property real clockHiddenX: side > 0 ? width + IslandTokens.swipeHiddenPadding : -innerWidth - IslandTokens.swipeHiddenPadding

    // Both halves travel the same distance, so they stay locked to each other
    // whichever of the two has further to go.
    readonly property real travel: Math.max(Math.abs(centredX - contentHiddenX), Math.abs(clockHiddenX - centredX))

    readonly property real contentX: centredX - side * (1 - progress) * travel
    readonly property real clockX: centredX + side * progress * travel

    readonly property string clockText: Time.amPmStr ? `${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr}` : `${Time.hourStr}:${Time.minuteStr}`

    default property alias pageContent: contentBox.data

    anchors.fill: parent
    clip: true

    Item {
        id: contentBox

        x: root.contentX
        y: 0
        width: root.innerWidth
        height: parent.height
        opacity: root.progress
    }

    // The clock half. It is drawn by whichever page is mounted rather than by
    // a layer of its own: at rest one of these two pages is always up, and the
    // time it shows *is* the resting island.
    Item {
        x: root.clockX
        y: 0
        width: root.innerWidth
        height: parent.height
        opacity: root.showClock ? 1 - root.progress : 0

        ClockText {
            id: clock

            anchors.centerIn: parent

            text: root.clockText
        }

        // A dot while the screen is being recorded, as Tide has it: small
        // enough to live on the resting page, impossible to miss once you
        // know it.
        StyledRect {
            anchors.right: clock.left
            anchors.rightMargin: IslandTokens.contentSpacing * 2
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

        Behavior on opacity {
            NumberAnimation {
                duration: IslandTokens.swipeDuration
                easing.type: Easing.InOutQuad
            }
        }
    }
}
