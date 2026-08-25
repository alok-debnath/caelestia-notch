pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// The page right of the clock: cover, the line that is playing, the bars.
//
// Tide's layout exactly -- a small cover held left, the line centred between
// it and the strip, the strip pinned right -- and Tide's motion: the line
// arrives from the left as the clock leaves to the right (see RestingPage),
// and a new lyric rolls in place rather than cutting.
//
// The text is the current lyric when the helper is running and the track title
// when it is not, so the page is useful either way.
RestingPage {
    id: root

    property real maximumWidth: IslandTokens.swipeMinWidth

    readonly property var player: Players.active
    readonly property string lineText: lyrics.hasLine ? lyrics.line : (player?.trackTitle ?? "")

    // Capped at Tide's media width rather than growing to fit the title: a
    // page of the notch stays a page of the notch.
    readonly property real preferredWidth: Math.max(IslandTokens.swipeMinWidth, Math.min(maximumWidth, IslandTokens.mediaMaxWidth, metrics.advanceWidth + IslandTokens.smallArtSize + bars.implicitWidth + IslandTokens.pageVisualSpacing * 2 + IslandTokens.pagePadding * 2))

    readonly property TextMetrics metrics: TextMetrics {
        font: line.font
        text: root.lineText
    }

    readonly property LyricsProvider lyrics: LyricsProvider {}

    side: 1

    StyledClippingRect {
        id: cover

        anchors.left: parent.left
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

    IslandRollText {
        id: line

        anchors.left: cover.right
        anchors.right: bars.left
        anchors.leftMargin: IslandTokens.pageVisualSpacing
        anchors.rightMargin: IslandTokens.pageVisualSpacing
        anchors.verticalCenter: parent.verticalCenter

        text: root.lineText
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    CavaBars {
        id: bars

        visible: IslandConfig.visualiser

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }
}
