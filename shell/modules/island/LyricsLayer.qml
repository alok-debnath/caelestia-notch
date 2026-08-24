pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The right resting page: cover, the line that is playing, and the cava strip.
//
// Tide's layout exactly -- a 24px cover, the text, and the bars pinned right.
// The text is the current lyric when the helper is running and the track title
// when it is not, so the page is useful either way.
SlidingLayer {
    id: root

    property real maximumWidth: IslandTokens.swipeMinWidth

    readonly property var player: Players.active
    readonly property string lineText: lyrics.hasLine ? lyrics.line : (player?.trackTitle ?? "")

    readonly property real preferredWidth: Math.max(IslandTokens.swipeMinWidth, Math.min(maximumWidth, metrics.advanceWidth + IslandTokens.smallArtSize + bars.implicitWidth + IslandTokens.horizontalPadding * 4))

    readonly property TextMetrics metrics: TextMetrics {
        font: label.font
        text: root.lineText
    }

    readonly property LyricsProvider lyrics: LyricsProvider {}

    StyledClippingRect {
        id: cover

        anchors.left: parent.left
        anchors.leftMargin: IslandTokens.horizontalPadding * 0.875
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: IslandTokens.smallArtSize
        implicitHeight: IslandTokens.smallArtSize
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

    IslandText {
        id: label

        anchors.left: cover.right
        anchors.right: bars.left
        anchors.leftMargin: IslandTokens.contentSpacing * 2
        anchors.rightMargin: IslandTokens.contentSpacing * 2
        anchors.verticalCenter: parent.verticalCenter

        animate: true
        text: root.lineText
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignLeft
    }

    CavaBars {
        id: bars

        visible: IslandConfig.visualiser

        anchors.right: parent.right
        anchors.rightMargin: IslandTokens.horizontalPadding * 0.875
        anchors.verticalCenter: parent.verticalCenter

    }
}
