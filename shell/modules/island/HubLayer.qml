pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// What hovering the notch opens.
//
// Whatever is playing (or the date, when nothing is), plus the buttons that
// open the views. This is the layer the pointer lands in, so everything
// reachable from the island is reachable from here.
Item {
    id: root

    required property var island

    implicitWidth: Math.min(IslandTokens.maxWidth, layout.implicitWidth + IslandTokens.horizontalPadding * 2)
    implicitHeight: layout.implicitHeight + IslandTokens.verticalPadding * 2

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: IslandTokens.contentSpacing * 2

        Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true

            sourceComponent: Players.active ? media : date
        }

        StyledRect {
            Layout.alignment: Qt.AlignVCenter

            implicitWidth: 1
            implicitHeight: IslandTokens.artSize * 0.7
            color: Colours.palette.m3outlineVariant
        }

        IslandActions {
            Layout.alignment: Qt.AlignVCenter

            island: root.island
        }
    }

    Component {
        id: media

        MediaBlock {}
    }

    Component {
        id: date

        ColumnLayout {
            spacing: 0

            StyledText {
                animate: true
                text: Time.amPmStr ? `${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr}` : `${Time.hourStr}:${Time.minuteStr}`
                font.family: Tokens.font.clock.build().family
                font.pixelSize: IslandTokens.clockPixelSize
                font.weight: Font.Bold
                font.letterSpacing: IslandTokens.clockLetterSpacing
                color: Colours.palette.m3onSurface
            }

            StyledText {
                animate: true
                text: Time.format("dddd, d MMMM")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
