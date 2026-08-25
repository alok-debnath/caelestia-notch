pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

// Tide's battery: the outline of a cell, filled to the charge, with the figure
// written across it and a bolt over the fill while it is charging.
//
// Drawn rather than set as an icon glyph because the fill is the reading --
// a battery icon that steps through five states says less than one that is
// simply as full as the battery is, and it is the same three rectangles.
Item {
    id: root

    readonly property real percent: UPower.displayDevice?.ready ? UPower.displayDevice.percentage : 0
    readonly property bool charging: !UPower.onBattery

    // Low enough to matter, and not while it is being fixed.
    readonly property bool low: percent <= 0.2 && !charging

    readonly property color accent: low ? Colours.palette.m3error : Colours.palette.m3onSurface

    implicitWidth: 37 + tip.width
    implicitHeight: 17

    visible: UPower.displayDevice?.ready ?? false

    Rectangle {
        id: shell

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: 37
        implicitHeight: parent.height
        radius: 6
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)

        // The charge itself. Sized off the outline's inside, so it never
        // overlaps the border at either end.
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter

            width: Math.max(2, (parent.width - 4) * Math.max(0, Math.min(1, root.percent)))
            height: parent.height - 4
            radius: 3
            color: root.accent
            opacity: 0.32

            Behavior on width {
                NumberAnimation {
                    duration: IslandTokens.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
        }

        // The bolt sits beside the figure rather than over it: charging is a
        // second fact about the battery, not a replacement for the reading.
        Row {
            anchors.centerIn: parent

            spacing: 1

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter

                text: "bolt"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.small
                fill: 1
                visible: root.charging
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter

                text: `${Math.round(root.percent * 100)}`
                color: root.accent
                // Assigned whole rather than part by part: StyledText binds
                // `font` itself, and setting one field of it here would fight
                // that binding instead of narrowing it.
                font: Qt.font({
                    family: Tokens.font.title.medium.family,
                    pixelSize: root.charging ? 12 : 13,
                    weight: Font.DemiBold
                })
            }
        }
    }

    // The terminal, on the right, as every battery in every UI has had since
    // the first one.
    Rectangle {
        id: tip

        anchors.left: shell.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: 2
        implicitHeight: 5
        radius: 1
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
    }
}
