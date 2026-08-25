pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

// The file shelf: whatever has been dropped on the notch, waiting to be picked
// up again.
//
// A card per file, images previewing themselves. Clicking opens it, the corner
// button takes it off the shelf. Nothing here copies or moves anything -- the
// shelf is a list of paths.
SlidingLayer {
    id: root

    required property var island

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: IslandTokens.panelPadding
        anchors.topMargin: IslandTokens.panelTopReserve

        spacing: Tokens.spacing.small


        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IslandText {
                Layout.fillWidth: true

                text: FileShelf.paths.length > 0 ? qsTr("%1 on the shelf").arg(FileShelf.paths.length) : qsTr("Drop a file on the notch, or paste one here")
                elide: Text.ElideRight
            }

            // Paste, alongside drag-and-drop: a fallback for whatever the
            // clipboard already has (Ctrl+C in the file manager), and less
            // finicky than landing a drag on the capsule at rest.
            IconButton {
                icon: "content_paste"
                type: IconButton.Text
                onClicked: FileShelf.pasteFromClipboard()
            }

            IconButton {
                icon: "clear_all"
                type: IconButton.Text
                disabled: FileShelf.paths.length === 0
                onClicked: FileShelf.clear()
            }
        }

        StyledListView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            model: FileShelf.paths
            orientation: ListView.Horizontal
            spacing: Tokens.spacing.small
            clip: true

            delegate: StyledRect {
                id: card

                required property string modelData

                implicitWidth: IslandTokens.shelfCardWidth
                height: ListView.view.height
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.large
                scale: cardDrag.active ? 1.05 : 1

                // A real Wayland drag out to another app's window, not just
                // an internal QML one -- dragType Automatic hands the mime
                // data to the platform's native drag-and-drop.
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.CopyAction
                Drag.proposedAction: Qt.CopyAction
                Drag.hotSpot: Qt.point(width / 2, height / 2)
                Drag.mimeData: FileShelf.mimeData(card.modelData)

                StateLayer {
                    radius: parent.radius
                    onClicked: FileShelf.open(card.modelData)
                }

                DragHandler {
                    id: cardDrag

                    target: null
                    acceptedButtons: Qt.LeftButton

                    onActiveChanged: card.Drag.active = active
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium

                    spacing: Tokens.spacing.extraSmall

                    StyledClippingRect {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        radius: Tokens.rounding.medium
                        color: Colours.palette.m3surfaceContainerHigh

                        MaterialIcon {
                            anchors.centerIn: parent

                            text: FileShelf.icon(card.modelData)
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.builders.extraLarge.build()
                            visible: !preview.visible
                        }

                        Image {
                            id: preview

                            anchors.fill: parent

                            source: FileShelf.isImage(card.modelData) ? `file://${card.modelData}` : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: IslandTokens.shelfCardWidth * 2
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        IslandText {
                            Layout.fillWidth: true

                            text: FileShelf.name(card.modelData)
                            font.pixelSize: IslandTokens.bodyPixelSize - 3
                            elide: Text.ElideMiddle
                        }

                        IconButton {
                            icon: "content_copy"
                            type: IconButton.Text
                            padding: 0
                            font: Tokens.font.icon.small
                            onClicked: FileShelf.copy(card.modelData)
                        }

                        IconButton {
                            icon: "close"
                            type: IconButton.Text
                            padding: 0
                            font: Tokens.font.icon.small
                            onClicked: FileShelf.remove(card.modelData)
                        }
                    }
                }
            }
        }
    }
}
