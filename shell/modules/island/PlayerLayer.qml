pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.services

// The expanded panel, at Tide's size: 410 by 190, and two pages wide.
//
// Page one is what is playing -- cover, track, the level strip, a scrubber you
// can drag, and the transport under it. Page two is Tide's kitchen timer. They
// are one strip that slides, not a stack that swaps: drag anywhere on the
// panel that is not a control, or use the two dots.
//
// This is what hovering the notch opens, so the island's other views hang off
// the corner of it rather than off a click on the capsule.
SlidingLayer {
    id: root

    required property var island

    readonly property MprisPlayer player: Players.active
    readonly property bool playing: player?.isPlaying ?? false

    // 0 on the player, 1 on the timer, fractional under a drag.
    property real pageProgress: 0
    property int currentPage: 0

    readonly property real page: Math.max(0, Math.min(1, pageProgress))
    readonly property real pageTravel: Math.max(1, width + 24)

    function settlePage(target: int): void {
        currentPage = Math.max(0, Math.min(1, target));
        pageSettle.to = currentPage;
        pageSettle.restart();
    }

    function formatTime(seconds: real): string {
        if (!isFinite(seconds) || seconds <= 0)
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    // MPRIS position does not tick on its own; the shell has to ask.
    readonly property Timer positionTimer: Timer {
        running: (root.player?.isPlaying ?? false) && root.page < 0.5
        repeat: true
        interval: 1000
        onTriggered: root.player?.positionChanged()
    }

    readonly property NumberAnimation pageSettle: NumberAnimation {
        target: root
        property: "pageProgress"
        duration: IslandTokens.morphDuration
        easing.type: Easing.OutQuint
    }

    // The page drag. Below everything, so a press on a button is a button
    // press; a press anywhere else can still pull the strip across.
    MouseArea {
        anchors.fill: parent

        property real startX: 0
        property real startProgress: 0
        property bool moved: false

        onPressed: mouse => {
            pageSettle.stop();
            startX = mouse.x;
            startProgress = root.page;
            moved = false;
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const dx = mouse.x - startX;
            moved = moved || Math.abs(dx) > 8;
            root.pageProgress = Math.max(0, Math.min(1, startProgress - dx / root.pageTravel));
        }

        onReleased: {
            if (!moved) {
                root.settlePage(root.currentPage);
                return;
            }
            // Tide's thresholds: a fifth of the way over commits, coming back
            // needs the same fifth in the other direction.
            if (root.currentPage === 0)
                root.settlePage(root.page > 0.22 ? 1 : 0);
            else
                root.settlePage(root.page < 0.78 ? 0 : 1);
        }

        onCanceled: root.settlePage(root.currentPage)
    }

    // -- Page one: now playing ------------------------------------------
    Item {
        anchors.fill: parent

        x: root.page * root.pageTravel
        opacity: 1 - root.page
        enabled: opacity > 0.001

        Column {
            anchors.fill: parent
            // Fixed, not Tokens.padding/spacing: those are scaled for the
            // bar's full-size popups and overflow this fixed capsule. These
            // are Tide's own panel metrics.
            anchors.margins: 20
            anchors.topMargin: IslandTokens.panelTopReserve

            spacing: 14

            Item {
                width: parent.width
                height: 60

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 16

                    StyledClippingRect {
                        implicitWidth: 60
                        implicitHeight: 60
                        radius: 14
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

                    Column {
                        anchors.verticalCenter: parent.verticalCenter

                        spacing: 4

                        IslandRollText {
                            width: 180

                            text: root.player?.trackTitle || qsTr("Nothing playing")
                            elide: Text.ElideRight
                        }

                        IslandRollText {
                            width: 180

                            dim: true
                            text: root.player?.trackArtist || qsTr("Try playing something")
                            elide: Text.ElideRight
                        }
                    }
                }

                // The level strip, where Tide puts it: hard right of the
                // track, small enough to read as a state rather than as a
                // control. Real cava, not the sine wave Tide draws -- the
                // shell already has the spectrum.
                CavaBars {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    visible: IslandConfig.visualiser

                    barCount: 5
                    barWidth: 4
                    barSpacing: 4
                    minBarHeight: 6
                    barColour: root.playing ? Colours.palette.m3primary : Colours.palette.m3outline

                    implicitHeight: 22
                }
            }

            // The scrubber. Tide draws a bar; this one seeks, because the
            // island is the only place in the shell that shows it.
            Item {
                width: parent.width
                height: 16

                IslandText {
                    id: elapsed

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    dim: true
                    text: root.formatTime(root.player?.position ?? 0)
                    font.pixelSize: IslandTokens.bodyPixelSize - 4
                }

                IslandText {
                    id: total

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    dim: true
                    text: root.formatTime(root.player?.length ?? 0)
                    font.pixelSize: IslandTokens.bodyPixelSize - 4
                }

                Item {
                    id: track

                    anchors.left: elapsed.right
                    anchors.right: total.left
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter

                    height: 16

                    readonly property real fraction: {
                        const length = root.player?.length ?? 0;
                        if (length <= 0)
                            return 0;
                        return Math.max(0, Math.min(1, (root.player?.position ?? 0) / length));
                    }

                    StyledRect {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        implicitHeight: 6
                        radius: height / 2
                        color: Colours.palette.m3surfaceContainerHighest

                        StyledRect {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            implicitWidth: parent.width * (seek.pressed ? seek.dragFraction : track.fraction)
                            implicitHeight: parent.height
                            radius: height / 2
                            color: Colours.palette.m3primary

                            Behavior on implicitWidth {
                                enabled: !seek.pressed

                                NumberAnimation {
                                    duration: 500
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: seek

                        anchors.fill: parent

                        property real dragFraction: 0

                        enabled: root.player?.canSeek ?? false
                        preventStealing: true

                        function fractionAt(x: real): real {
                            return Math.max(0, Math.min(1, x / Math.max(1, width)));
                        }

                        onPressed: mouse => dragFraction = fractionAt(mouse.x)
                        onPositionChanged: mouse => {
                            if (pressed)
                                dragFraction = fractionAt(mouse.x);
                        }
                        onReleased: mouse => {
                            const length = root.player?.length ?? 0;
                            if (length > 0 && root.player)
                                root.player.position = fractionAt(mouse.x) * length;
                        }
                    }
                }
            }

            // The transport. Tide's spacing, and Tide's press: the glyph
            // shrinks under the finger rather than lighting up behind it.
            Item {
                width: parent.width
                height: 36

                Row {
                    anchors.centerIn: parent

                    spacing: 50

                    TransportButton {
                        icon: "skip_previous"
                        enabled: root.player?.canGoPrevious ?? false
                        onTriggered: root.player?.previous()
                    }

                    TransportButton {
                        icon: root.playing ? "pause" : "play_arrow"
                        enabled: root.player?.canTogglePlaying ?? false
                        onTriggered: root.player?.togglePlaying()
                    }

                    TransportButton {
                        icon: "skip_next"
                        enabled: root.player?.canGoNext ?? false
                        onTriggered: root.player?.next()
                    }
                }
            }
        }
    }

    // -- Page two: the timer ---------------------------------------------
    TimerPage {
        anchors.fill: parent

        x: -(1 - root.page) * root.pageTravel
        opacity: root.page
        enabled: opacity > 0.001
    }

    // Which page you are on, and how to get to the other one. Same row the
    // panels use for their own tabs -- see PageDots.
    PageDots {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: IslandTokens.dotsMargin

        count: 2
        position: root.page
        labels: [qsTr("Now playing"), qsTr("Timer")]
        travel: root.pageTravel / 3

        onSelected: index => root.settlePage(index)
    }
}
