pragma ComponentBehavior: Bound

import QtQuick

// Text that scrolls when it does not fit, and sits still when it does.
//
// The media page is a fixed narrow capsule, and a track title is whatever
// length it is. Eliding it hides the half that says which song this is, so it
// scrolls instead: a pause at the start, a slow pass, a pause at the end, back.
Item {
    id: root

    property alias text: label.text
    property alias font: label.font
    property alias color: label.color
    property bool dim

    readonly property real textWidth: label.implicitWidth
    readonly property bool overflowing: textWidth > width + 1

    implicitWidth: textWidth
    implicitHeight: label.implicitHeight

    clip: true

    IslandText {
        id: label

        dim: root.dim
        width: implicitWidth
        anchors.verticalCenter: parent.verticalCenter

        onTextChanged: {
            scroll.stop();
            x = 0;
            if (root.overflowing)
                scroll.restart();
        }
    }

    onOverflowingChanged: {
        scroll.stop();
        label.x = 0;
        if (overflowing)
            scroll.restart();
    }

    SequentialAnimation {
        id: scroll

        loops: Animation.Infinite

        PauseAnimation {
            duration: IslandTokens.marqueePause
        }
        NumberAnimation {
            target: label
            property: "x"
            to: Math.min(0, root.width - root.textWidth)
            // Constant speed rather than constant duration: a long title should
            // not scroll faster than a short one.
            duration: Math.max(1, root.textWidth - root.width) * IslandTokens.marqueeMsPerPixel
            easing.type: Easing.InOutQuad
        }
        PauseAnimation {
            duration: IslandTokens.marqueePause
        }
        NumberAnimation {
            target: label
            property: "x"
            to: 0
            duration: Math.max(1, root.textWidth - root.width) * IslandTokens.marqueeMsPerPixel
            easing.type: Easing.InOutQuad
        }
    }
}
