pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Tide's wallpaper switcher: the library as one long strip you scroll through,
// in the wide capsule the shelf uses.
//
// Tide builds its own thumbnail cache with a Python scan and applies through
// swww. None of that is here, because Caelestia already has both -- the
// Wallpapers service knows the library and `caelestia wallpaper` does the
// switch, colours and all. What is ported is the *surface*: the strip, the
// proportions, the current one called out, and the live preview under the
// pointer, which is the part that makes picking a wallpaper feel like turning
// pages rather than filling in a form.
SlidingLayer {
    id: root

    required property var island

    readonly property real cardWidth: 208
    readonly property real cardHeight: Math.round(cardWidth * 9 / 16)

    // Preview follows the pointer, and is dropped the moment the strip is not
    // the thing being looked at -- an island that wanders off leaving the
    // wallpaper previewed would be a bug you have to log out of.
    function preview(path: string): void {
        if (Colours.scheme === "dynamic")
            Wallpapers.preview(path);
    }

    function stopPreview(): void {
        Wallpapers.stopPreview();
    }

    Component.onDestruction: stopPreview()

    ListView {
        id: strip

        anchors.fill: parent
        anchors.topMargin: IslandTokens.panelTopReserve
        anchors.bottomMargin: IslandTokens.panelPadding
        anchors.leftMargin: IslandTokens.panelPadding
        anchors.rightMargin: IslandTokens.panelPadding

        orientation: ListView.Horizontal
        spacing: Tokens.spacing.medium
        clip: true
        model: Wallpapers.list

        // Land on what is up now, so the strip opens where you left off.
        Component.onCompleted: {
            const index = Wallpapers.list.findIndex(w => w.path === Wallpapers.actualCurrent);
            if (index >= 0)
                positionViewAtIndex(index, ListView.Center);
        }

        delegate: StyledClippingRect {
            id: card

            required property var modelData

            readonly property bool current: modelData.path === Wallpapers.actualCurrent

            implicitWidth: root.cardWidth
            implicitHeight: root.cardHeight

            anchors.verticalCenter: parent?.verticalCenter ?? undefined

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer
            border.width: current ? 2 : 1
            border.color: current ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

            scale: area.containsMouse ? 1.03 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: IslandTokens.contentFadeDuration
                    easing.type: Easing.OutCubic
                }
            }

            Image {
                anchors.fill: parent

                source: `file://${card.modelData.path}`
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 416
                asynchronous: true
                cache: true
            }

            // The name, on a scrim rather than beside the card: the strip is
            // pictures, and the text is only there for the ones that look
            // alike.
            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                implicitHeight: label.implicitHeight + Tokens.padding.small * 2
                color: Qt.rgba(0, 0, 0, 0.45)
                opacity: area.containsMouse || card.current ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: IslandTokens.contentFadeDuration
                        easing.type: Easing.OutCubic
                    }
                }

                IslandText {
                    id: label

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small

                    text: card.modelData.name ?? card.modelData.relativePath ?? ""
                    color: "white"
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent

                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: root.preview(card.modelData.path)
                onExited: root.stopPreview()

                onClicked: {
                    if (Colours.scheme === "dynamic" && card.modelData.path !== Wallpapers.actualCurrent)
                        Wallpapers.previewColourLock = true;
                    Wallpapers.setWallpaper(card.modelData.path);
                }
            }
        }
    }
}
