pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Now playing, at Tide's expanded size: 410 by 165, 20px margins, a 60px cover,
// the scrubber, and the transport centred under it.
//
// This is what hovering the notch opens, so the island's other views hang off
// the corner of it rather than off a click on the capsule.
SlidingLayer {
    id: root

    required property var island

    readonly property MprisPlayer player: Players.active

    function formatTime(seconds: real): string {
        if (!isFinite(seconds) || seconds <= 0)
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    // MPRIS position does not tick on its own; the shell has to ask.
    readonly property Timer positionTimer: Timer {
        running: root.player?.isPlaying ?? false
        repeat: true
        interval: 1000
        onTriggered: root.player?.positionChanged()
    }

    ColumnLayout {
        anchors.fill: parent
        // Fixed, not Tokens.padding/spacing: those are scaled for the bar's
        // full-size popups and overflowed this fixed 165px capsule, pushing
        // the transport row into the bottom corner radius. IslandTokens'
        // horizontalPadding/contentSpacing are sized for swipe pages, not a
        // three-row panel, so this stays a literal 20px per the layout this
        // panel was built to (see file header).
        anchors.margins: 20
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.large

            StyledClippingRect {
                implicitWidth: 60
                implicitHeight: 60
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainerHigh

                Image {
                    anchors.fill: parent

                    source: Players.getArtUrl(root.player)
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 120
                    sourceSize.height: 120
                    asynchronous: true
                    visible: status === Image.Ready
                }

                MaterialIcon {
                    anchors.centerIn: parent

                    text: "music_note"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.large.build()
                    visible: !Players.getArtUrl(root.player)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                IslandText {
                    Layout.fillWidth: true

                    animate: true
                    text: root.player?.trackTitle || qsTr("Nothing playing")
                    elide: Text.ElideRight
                }

                IslandText {
                    Layout.fillWidth: true

                    dim: true
                    animate: true
                    text: root.player?.trackArtist || qsTr("Try playing something")
                    elide: Text.ElideRight
                }
            }

        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IslandText {
                dim: true
                font.pixelSize: IslandTokens.bodyPixelSize - 4
                text: root.formatTime(root.player?.position ?? 0)
            }

            StyledRect {
                Layout.fillWidth: true

                implicitHeight: 6
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                StyledRect {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    implicitWidth: parent.width * Math.max(0, Math.min(1, (root.player?.length ?? 0) > 0 ? (root.player?.position ?? 0) / root.player.length : 0))
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primary

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.player?.canSeek ?? false
                    onClicked: event => {
                        if (root.player?.length > 0)
                            root.player.position = root.player.length * (event.x / width);
                    }
                }
            }

            IslandText {
                dim: true
                font.pixelSize: IslandTokens.bodyPixelSize - 4
                text: root.formatTime(root.player?.length ?? 0)
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.extraLarge

            IconButton {
                icon: "skip_previous"
                type: IconButton.Text
                font: Tokens.font.icon.large
                disabled: !(root.player?.canGoPrevious ?? false)
                onClicked: root.player?.previous()
            }

            IconButton {
                icon: root.player?.isPlaying ? "pause" : "play_arrow"
                type: IconButton.Text
                font: Tokens.font.icon.large
                disabled: !(root.player?.canTogglePlaying ?? false)
                onClicked: root.player?.togglePlaying()
            }

            IconButton {
                icon: "skip_next"
                type: IconButton.Text
                font: Tokens.font.icon.large
                disabled: !(root.player?.canGoNext ?? false)
                onClicked: root.player?.next()
            }
        }
    }
}
