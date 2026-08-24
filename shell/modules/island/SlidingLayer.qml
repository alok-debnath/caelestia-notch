pragma ComponentBehavior: Bound

import QtQuick

// A page of the notch that can slide.
//
// Tide's resting states are three pages side by side -- a date preview, the
// clock, whatever is playing -- and a drag moves between them. Each page knows
// only how far it is from the middle: `offset` is in pages, so 0 is centred, -1
// is one page off to the left, and a drag puts the pages at fractions in
// between. Everything else here follows from that.
Item {
    id: root

    // Distance from the centre, in pages.
    property real offset: 0

    // Whether the page is showing at all. A page that is off-centre is still
    // mounted during a drag, which is what makes the drag read as one strip
    // moving rather than two layers cross-fading.
    property bool showCondition: true

    // Suspended while the finger is down: the pages follow it directly then.
    property bool animated: true

    readonly property real clampedOffset: Math.max(-1, Math.min(1, offset))

    default property alias content: inner.data

    anchors.fill: parent
    clip: true
    opacity: showCondition ? 1 - Math.abs(clampedOffset) : 0

    Behavior on opacity {
        enabled: root.animated

        NumberAnimation {
            duration: IslandTokens.swipeDuration
            easing.type: Easing.InOutQuad
        }
    }

    Item {
        id: inner

        anchors.verticalCenter: parent.verticalCenter

        // A page one off-centre sits just past the edge, not exactly on it, so
        // it is fully gone before the next one arrives.
        x: root.clampedOffset * (root.width + IslandTokens.hiddenPadding)
        width: parent.width
        height: parent.height

        Behavior on x {
            enabled: root.animated

            NumberAnimation {
                duration: IslandTokens.swipeDuration
                easing.type: Easing.OutQuint
            }
        }
    }
}
