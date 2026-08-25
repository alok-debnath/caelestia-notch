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
RowLayout {
    id: root

    readonly property MprisPlayer player: Players.active

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
        Layout.maximumWidth: IslandTokens.maxWidth / 2
        spacing: 0

        IslandRollText {
            Layout.fillWidth: true

            text: root.player?.trackTitle || qsTr("Nothing playing")
            fontStyle: Tokens.font.body.small
            color: Colours.palette.m3onSurface
            elide: Text.ElideRight
        }

        IslandRollText {
            Layout.fillWidth: true

            text: root.player?.trackArtist ?? ""
            fontStyle: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
            elide: Text.ElideRight
            visible: text.length > 0
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignVCenter
        spacing: 0
        visible: !!root.player

        IconButton {
            icon: "skip_previous"
            type: IconButton.Text
            enabled: root.player?.canGoPrevious ?? false
            onClicked: root.player?.previous()
        }

        IconButton {
            icon: root.player?.isPlaying ? "pause" : "play_arrow"
            type: IconButton.Text
            enabled: root.player?.canTogglePlaying ?? false
            onClicked: root.player?.togglePlaying()
        }

        IconButton {
            icon: "skip_next"
            type: IconButton.Text
            enabled: root.player?.canGoNext ?? false
            onClicked: root.player?.next()
        }
    }
}
