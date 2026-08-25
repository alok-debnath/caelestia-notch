pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

// Clipboard history: a card per cliphist entry, images previewing themselves
// the way shelf files do. Clicking a card copies it back to the clipboard;
// the corner button deletes just that entry, "clear_all" wipes the lot.
SlidingLayer {
    id: root

    required property var island

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.extraLarge

        spacing: Tokens.spacing.small

        // No switcher pill reserve here: Clipboard isn't in `showSwitcher`
        // (opened only by its own keybind, like Player), so nothing floats
        // above this panel's content to leave room for.

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IslandText {
                Layout.fillWidth: true

                text: Clipboard.entries.length > 0 ? qsTr("%1 in clipboard history").arg(Clipboard.entries.length) : qsTr("Nothing copied yet")
                elide: Text.ElideRight
            }

            IconButton {
                icon: "clear_all"
                type: IconButton.Text
                disabled: Clipboard.entries.length === 0
                onClicked: Clipboard.clear()
            }
        }

        StyledListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true

            model: Clipboard.entries
            spacing: Tokens.spacing.small
            clip: true

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: list
            }

            delegate: StyledRect {
                id: card

                required property var modelData
                required property int index

                width: ListView.view.width
                implicitHeight: IslandTokens.shelfCardWidth * 0.6
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.large

                StateLayer {
                    radius: parent.radius
                    onClicked: {
                        Clipboard.copy(card.modelData);
                        root.island.close();
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium

                    spacing: Tokens.spacing.medium

                    StyledClippingRect {
                        id: thumb

                        // The box keeps the card's fixed row height but
                        // takes on the image's own aspect ratio for width,
                        // capped so a panorama-shaped copy can't blow the
                        // list out sideways -- PreserveAspectCrop would
                        // otherwise just crop every image square regardless
                        // of its actual shape.
                        readonly property real aspect: card.modelData.isImage && card.modelData.height > 0 ? card.modelData.width / card.modelData.height : 1

                        Layout.preferredHeight: parent.height - Tokens.padding.medium * 2
                        Layout.preferredWidth: Math.min(Layout.preferredHeight * 2, Layout.preferredHeight * aspect)
                        Layout.alignment: Qt.AlignVCenter

                        radius: Tokens.rounding.small
                        color: Colours.palette.m3surfaceContainerHigh
                        visible: card.modelData.isImage

                        Image {
                            anchors.fill: parent

                            source: card.modelData.isImage ? `file://${Clipboard.thumbPath(card.modelData)}` : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                            // Decode at card size, not at the copied image's
                            // full resolution -- undecorated, a multi-MB
                            // screenshot was being decoded to its full
                            // pixel size just to draw a ~50px square, which
                            // is most of why this was slow.
                            sourceSize.width: 192
                            sourceSize.height: 96
                            visible: status === Image.Ready
                        }
                    }

                    IslandText {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        text: card.modelData.isImage ? qsTr("Image · %1×%2").arg(card.modelData.width).arg(card.modelData.height) : card.modelData.preview
                        font.pixelSize: IslandTokens.bodyPixelSize - 2
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignVCenter

                        icon: "close"
                        type: IconButton.Text
                        padding: 0
                        font: Tokens.font.icon.small
                        onClicked: Clipboard.remove(card.modelData)
                    }
                }
            }
        }
    }

    // The Loader recreates this component each time the panel opens (see
    // IslandLayer's active/fadeOutTimer), so this is "on open", not just
    // "on first ever open".
    Component.onCompleted: Clipboard.refresh()
}
