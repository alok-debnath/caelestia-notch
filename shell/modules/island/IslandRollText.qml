pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// A label that changes by rolling, not by blinking.
//
// StyledText's own `animate` fades the string out, swaps it, and fades the new
// one back in. One Text can only hold one string, so those two halves have to
// be sequential, and the gap between them is the blink -- for a clock that is
// every minute, on the one element of the notch that is always on screen.
//
// Here there are two copies of the label stacked on the same spot. On a change
// the old one leaves upward while the new one arrives from below, at the same
// time, clipped to the line box: the swap reads as one strip of type rolling
// past a window, and there is never a frame with nothing in it.
//
// Widths are animated too, so a label that gets longer ("Face ID" ->
// "Not recognised") does not shove its neighbours aside on a single frame.
Item {
    id: root

    property string text

    // Forwarded to both copies -- see IslandText for what they mean.
    property bool hero
    property bool dim
    property color color: root.dim ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
    property int elide: Text.ElideNone
    property int horizontalAlignment: Text.AlignLeft

    // For callers whose type is not the island's own scale: the media strip
    // uses the shell's body font. Null leaves IslandText's rules alone.
    property var fontStyle: null

    // What the copies are actually drawn in, for callers that need to measure
    // a string before it is on screen (the media page sizes the capsule off
    // its own line).
    readonly property alias font: cur.font

    // How far the copies travel, as a fraction of the line height.
    property real travel: IslandTokens.textRollTravel

    readonly property real slide: height * travel

    // False until the first string is in place: the initial value appears, it
    // does not roll in from nowhere.
    property bool ready: false

    implicitWidth: cur.implicitWidth
    implicitHeight: cur.implicitHeight

    // The copies travel out of the line box, and are cut off at its edge
    // rather than drawn over whatever sits above and below.
    clip: true

    onTextChanged: {
        if (!ready || cur.text === text) {
            cur.text = text;
            return;
        }

        prev.text = cur.text;
        cur.text = text;
        roll.restart();
    }

    Component.onCompleted: {
        cur.text = text;
        ready = true;
    }

    Behavior on implicitWidth {
        enabled: root.ready

        NumberAnimation {
            duration: IslandTokens.textRollInDuration
            easing.type: Easing.OutCubic
        }
    }

    // The outgoing copy. Parked empty and invisible between swaps.
    IslandText {
        id: prev

        property real shift: 0

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: shift

        hero: root.hero
        dim: root.dim
        color: root.color
        elide: root.elide
        horizontalAlignment: root.horizontalAlignment
        opacity: 0
    }

    IslandText {
        id: cur

        property real shift: 0

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: shift

        hero: root.hero
        dim: root.dim
        color: root.color
        elide: root.elide
        horizontalAlignment: root.horizontalAlignment
    }

    // A whole font, when the caller has one. Bindings rather than a plain
    // assignment so that IslandText's own family/size/weight rules stay in
    // force for everyone who does not pass one.
    Binding {
        target: prev
        property: "font"
        value: root.fontStyle
        when: root.fontStyle !== null
    }

    Binding {
        target: cur
        property: "font"
        value: root.fontStyle
        when: root.fontStyle !== null
    }

    // Both copies move on the same curve over the same time, so they travel as
    // one rigid strip -- an odometer wheel turning, not two labels animating
    // near each other. Only the opacities differ: the outgoing copy is faded
    // out well before the strip has stopped, which is what keeps the two
    // strings from being legible on top of each other in the middle of the
    // roll (they overlap for most of it, since the box is one line tall).
    ParallelAnimation {
        id: roll

        NumberAnimation {
            target: prev
            property: "opacity"
            from: 1
            to: 0
            duration: IslandTokens.textRollOutDuration
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: prev
            property: "shift"
            from: 0
            to: -root.slide
            duration: IslandTokens.textRollInDuration
            easing.type: Easing.OutQuint
        }
        NumberAnimation {
            target: cur
            property: "opacity"
            from: 0
            to: 1
            duration: IslandTokens.textRollInDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: cur
            property: "shift"
            from: root.slide
            to: 0
            duration: IslandTokens.textRollInDuration
            easing.type: Easing.OutQuint
        }
    }
}
