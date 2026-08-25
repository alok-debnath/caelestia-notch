pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// What is on the shelf, as a bubble beside the capsule.
//
// Tide keeps the file shelf discoverable without keeping it open: a clip and a
// count sit next to the island whenever it is holding anything, and clicking
// them opens the shelf. Without it the shelf is a panel you have to remember
// you filled.
Item {
    id: root

    signal triggered

    property real reveal: 0

    readonly property bool wanted: FileShelf.count > 0

    implicitWidth: 36
    implicitHeight: 36

    visible: reveal > 0.001
    scale: 0.55 + reveal * 0.45
    transformOrigin: Item.Center

    onWantedChanged: {
        show.stop();
        hide.stop();
        (wanted ? show : hide).restart();
    }

    Component.onCompleted: reveal = wanted ? 1 : 0

    NumberAnimation {
        id: show

        target: root
        property: "reveal"
        to: 1
        duration: 360
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hide

        target: root
        property: "reveal"
        to: 0
        duration: 280
        easing.type: Easing.InCubic
    }

    StyledRect {
        anchors.fill: parent

        radius: width / 2
        color: Colours.tPalette.m3surfaceContainer

        MaterialIcon {
            anchors.centerIn: parent

            text: "attach_file"
            color: Colours.palette.m3onSurface
            fontStyle: Tokens.font.icon.small
            rotation: -18
        }
    }

    // The count, hanging off the corner the way a badge does.
    StyledRect {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -2
        anchors.bottomMargin: -2

        implicitWidth: Math.max(17, count.implicitWidth + 8)
        implicitHeight: 17
        radius: height / 2
        color: Colours.palette.m3primary

        StyledText {
            id: count

            anchors.centerIn: parent

            text: FileShelf.count > 99 ? "99+" : `${FileShelf.count}`
            color: Colours.palette.m3onPrimary
            font: Qt.font({
                family: Tokens.font.title.medium.family,
                pixelSize: 10,
                weight: Font.DemiBold
            })
        }
    }

    MouseArea {
        anchors.fill: parent

        cursorShape: Qt.PointingHandCursor

        onClicked: root.triggered()
    }
}
