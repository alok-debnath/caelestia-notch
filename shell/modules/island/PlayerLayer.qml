pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Now playing: album art, track, and transport controls, driven by Caelestia's
// Players service rather than a second MPRIS client of the island's own.
Item {
    id: root

    readonly property MprisPlayer player: Players.active

    implicitWidth: Math.min(IslandTokens.maxWidth, layout.implicitWidth + IslandTokens.horizontalPadding * 2)
    implicitHeight: layout.implicitHeight + IslandTokens.verticalPadding * 2

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: IslandTokens.contentSpacing * 2

        StyledClippingRect {
            Layout.alignment: Qt.AlignVCenter

            implicitWidth: IslandTokens.artSize
            implicitHeight: IslandTokens.artSize
            radius: Tokens.rounding.small
            color: Colours.palette.m3surfaceContainerHigh

            Image {
                anchors.fill: parent

                source: Players.getArtUrl(root.player)
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: IslandTokens.artSize
                sourceSize.height: IslandTokens.artSize
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true

                animate: true
                text: root.player?.trackTitle || qsTr("Nothing playing")
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true

                animate: true
                text: root.player?.trackArtist ?? ""
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
                visible: text.length > 0
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            IconButton {
                icon: "skip_previous"
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player?.previous()
            }

            IconButton {
                icon: root.player?.isPlaying ? "pause" : "play_arrow"
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: root.player?.togglePlaying()
            }

            IconButton {
                icon: "skip_next"
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player?.next()
            }
        }
    }
}
