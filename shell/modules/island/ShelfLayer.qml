pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// The file shelf: whatever has been dropped on the notch, waiting to be picked
// up again. Tide's tray, card for card.
//
// A row of big system icons with their names under them. Five fit; past that
// the tray scrolls. Nothing here copies or moves anything -- the shelf is a
// list of paths, and taking one off it never touches the file.
//
// The gesture on a card is one gesture with two meanings, classified as it
// runs, which is Tide's trick: move sideways and you are sorting the shelf,
// move up/down or leave the tray and it becomes a real Wayland drag carrying
// the file to another application. Starting the native drag on press instead
// would eat every horizontal pixel of a sort.
SlidingLayer {
    id: root

    required property var island

    property int selectedIndex: FileShelf.count > 0 ? 0 : -1

    // Sorting state. `committing` exists for one frame after a move lands: the
    // displaced cards are already sitting in their final slots, so their shift
    // animation has to be off while the model indices catch up, or each one
    // flies in from an outer edge.
    property bool reorderActive: false
    property bool reorderCommitting: false
    property int reorderSourceIndex: -1
    property int reorderTargetIndex: -1
    property real reorderStartContentX: 0
    property real reorderTranslationX: 0
    property real reorderPointerX: 0

    // A card that was just dragged must not also count as opened.
    property string suppressedOpenPath: ""

    readonly property bool showing: island.islandState === IslandWindow.State.Shelf
    // Open by a drag hovering the notch rather than by the user: the shelf is
    // only a target then, so it shows the drop hint instead of the tray.
    readonly property bool dropPreviewOnly: island.dropping

    onShowingChanged: {
        if (!showing)
            return;
        FileShelf.refresh();
        normalizeSelection();
    }

    function normalizeSelection(): void {
        selectedIndex = FileShelf.count <= 0 ? -1 : Math.max(0, Math.min(FileShelf.count - 1, selectedIndex));
    }

    function openAt(index: int): void {
        const entry = FileShelf.get(index);
        if (entry)
            FileShelf.open(entry.path);
    }

    function removeAt(index: int): void {
        if (index < 0 || index >= FileShelf.count || reorderActive)
            return;
        FileShelf.removeAt(index);
        selectedIndex = Math.min(index, FileShelf.count - 1);
    }

    function moveSelection(by: int): void {
        if (FileShelf.count <= 0)
            return;
        selectedIndex = (selectedIndex + by + FileShelf.count) % FileShelf.count;
        ensureSelectedVisible();
    }

    function ensureSelectedVisible(): void {
        if (selectedIndex < 0 || FileShelf.count <= IslandTokens.shelfCapacity)
            return;
        const centre = slotCentre(selectedIndex);
        tray.contentX = Math.max(0, Math.min(tray.contentWidth - tray.width, centre - tray.width / 2));
    }

    // Under capacity the cards are spread evenly across the tray; over it they
    // sit on a fixed grid that scrolls.
    function slotStep(): real {
        if (FileShelf.count <= IslandTokens.shelfCapacity)
            return tray.width / Math.max(1, FileShelf.count + 1);
        return IslandTokens.shelfCellWidth;
    }

    function slotCentre(index: int): real {
        if (FileShelf.count <= IslandTokens.shelfCapacity)
            return tray.width * (index + 1) / Math.max(1, FileShelf.count + 1);
        return IslandTokens.shelfCellWidth * index + IslandTokens.shelfCellWidth / 2;
    }

    function beginReorder(index: int): void {
        if (index < 0 || index >= FileShelf.count)
            return;
        reorderActive = true;
        reorderSourceIndex = index;
        reorderTargetIndex = index;
        reorderStartContentX = tray.contentX;
        reorderTranslationX = 0;
        reorderPointerX = 0;
        selectedIndex = index;
    }

    function updateReorder(translationX: real, pointerX: real): void {
        if (!reorderActive)
            return;
        reorderTranslationX = translationX;
        reorderPointerX = pointerX;
        refreshReorderTarget();
    }

    function refreshReorderTarget(): void {
        if (!reorderActive)
            return;
        const contentDelta = tray.contentX - reorderStartContentX;
        const columnDelta = Math.round((reorderTranslationX + contentDelta) / slotStep());
        reorderTargetIndex = Math.max(0, Math.min(FileShelf.count - 1, reorderSourceIndex + columnDelta));
    }

    // How far every *other* card has to slide to leave a hole where the one
    // being dragged is going.
    function reorderShiftFor(index: int): real {
        if (!reorderActive || index === reorderSourceIndex)
            return 0;
        if (reorderSourceIndex < reorderTargetIndex && index > reorderSourceIndex && index <= reorderTargetIndex)
            return -slotStep();
        if (reorderSourceIndex > reorderTargetIndex && index >= reorderTargetIndex && index < reorderSourceIndex)
            return slotStep();
        return 0;
    }

    function reorderVisualOffset(): real {
        return reorderActive ? reorderTranslationX + tray.contentX - reorderStartContentX : 0;
    }

    function finishReorder(): void {
        if (!reorderActive)
            return;

        const from = reorderSourceIndex;
        const to = reorderTargetIndex;
        const changed = from !== to;

        reorderCommitting = changed;
        reorderActive = false;
        reorderSourceIndex = -1;
        reorderTargetIndex = -1;
        reorderTranslationX = 0;
        reorderPointerX = 0;

        if (changed)
            FileShelf.move(from, to);
        selectedIndex = to;
        ensureSelectedVisible();
        if (changed)
            commitReset.restart();
        openReset.restart();
    }

    function cancelReorder(): void {
        if (!reorderActive)
            return;
        reorderActive = false;
        reorderSourceIndex = -1;
        reorderTargetIndex = -1;
        reorderTranslationX = 0;
        reorderPointerX = 0;
        openReset.restart();
    }

    Connections {
        target: FileShelf

        function onCountChanged(): void {
            root.normalizeSelection();
        }
    }

    Timer {
        id: commitReset

        interval: 0
        onTriggered: root.reorderCommitting = false
    }

    Timer {
        id: openReset

        interval: 0
        onTriggered: root.suppressedOpenPath = ""
    }

    // Sorting past the edge of a scrolling tray drags the tray along with it.
    Timer {
        interval: 16
        repeat: true
        running: root.reorderActive && FileShelf.count > IslandTokens.shelfCapacity

        onTriggered: {
            const edge = 54;
            const maxContentX = Math.max(0, tray.contentWidth - tray.width);
            let next = tray.contentX;
            if (root.reorderPointerX < edge)
                next = Math.max(0, next - 10);
            else if (root.reorderPointerX > tray.width - edge)
                next = Math.min(maxContentX, next + 10);

            if (next !== tray.contentX) {
                tray.contentX = next;
                root.refreshReorderTarget();
            }
        }
    }

    // The shelf is the one panel that takes the keyboard (see IslandWindow's
    // keyboardFocus), so Tide's key handling works here too.
    focus: root.showing && !root.dropPreviewOnly

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
            root.island.close();
            event.accepted = true;
            return;
        case Qt.Key_Right:
        case Qt.Key_Tab:
            root.moveSelection(1);
            event.accepted = true;
            return;
        case Qt.Key_Left:
        case Qt.Key_Backtab:
            root.moveSelection(-1);
            event.accepted = true;
            return;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            root.removeAt(root.selectedIndex);
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.openAt(root.selectedIndex);
            event.accepted = true;
            return;
        }
    }

    // Paste, alongside drag-and-drop: whatever the file manager has already
    // copied, without having to land a drag at all. Not Tide's -- Tide has no
    // fallback -- and small enough to stay out of the tray's way.
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: IslandTokens.dotsMargin
        anchors.rightMargin: IslandTokens.shelfPadding

        z: 3
        spacing: 2
        opacity: root.dropPreviewOnly ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            CAnim {}
        }

        IconButton {
            icon: "content_paste"
            type: IconButton.Text
            padding: 0
            font: Tokens.font.icon.small
            onClicked: FileShelf.pasteFromClipboard()
        }

        IconButton {
            icon: "clear_all"
            type: IconButton.Text
            padding: 0
            font: Tokens.font.icon.small
            disabled: FileShelf.count === 0
            onClicked: FileShelf.clear()
        }
    }

    // Empty, or being dropped onto: the hint, where the tray would be.
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: IslandTokens.panelTopReserve / 2

        z: 2
        spacing: Tokens.spacing.small
        visible: root.dropPreviewOnly || FileShelf.count === 0

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter

            text: "download"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.builders.extraLarge.build()
        }

        IslandText {
            anchors.horizontalCenter: parent.horizontalCenter

            visible: !root.dropPreviewOnly
            text: qsTr("Drag files or folders onto the notch")
            font.pixelSize: IslandTokens.bodyPixelSize - 4
        }

        IslandText {
            anchors.horizontalCenter: parent.horizontalCenter

            visible: !root.dropPreviewOnly
            dim: true
            text: qsTr("Drag a card to reorder it, or out to drop it into another application")
            font.pixelSize: IslandTokens.bodyPixelSize - 6
        }
    }

    Flickable {
        id: tray

        anchors.fill: parent
        anchors.topMargin: IslandTokens.panelTopReserve
        anchors.bottomMargin: 8
        anchors.leftMargin: IslandTokens.shelfPadding
        anchors.rightMargin: IslandTokens.shelfPadding

        z: 2
        visible: !root.dropPreviewOnly && FileShelf.count > 0
        clip: true
        contentWidth: FileShelf.count <= IslandTokens.shelfCapacity ? width : FileShelf.count * IslandTokens.shelfCellWidth
        contentHeight: height
        interactive: !root.reorderActive && FileShelf.count > IslandTokens.shelfCapacity
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1800

        Repeater {
            model: FileShelf.entries

            Item {
                id: card

                required property int index
                required property var modelData

                readonly property bool selected: index === root.selectedIndex
                readonly property bool reorderSource: root.reorderActive && index === root.reorderSourceIndex

                x: root.slotCentre(index) - width / 2
                y: Math.max(0, (tray.height - height) / 2)
                width: IslandTokens.shelfCardWidth
                height: IslandTokens.shelfCardHeight
                z: reorderSource ? 12 : selected ? 4 : 2

                Item {
                    id: face

                    anchors.centerIn: parent

                    width: parent.width
                    height: parent.height - 10
                    scale: cardDrag.active ? 1.07 : area.pressed ? 0.95 : (card.selected || area.containsMouse ? 1.035 : 1)

                    // The real thing: dragType Automatic hands the mime data
                    // to the platform, so this lands in another application
                    // rather than only inside the shell.
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.proposedAction: Qt.CopyAction
                    Drag.hotSpot: Qt.point(width / 2, height / 2)
                    Drag.imageSource: icon.source
                    Drag.mimeData: FileShelf.mimeData(card.modelData.path)

                    transform: [
                        Translate {
                            x: card.reorderSource ? root.reorderVisualOffset() : 0
                        },
                        Translate {
                            x: root.reorderShiftFor(card.index)

                            Behavior on x {
                                enabled: !root.reorderCommitting

                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    ]

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    Item {
                        id: iconBox

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter

                        width: 122
                        height: 122

                        // The system icon for the file's own mime type, not a
                        // glyph standing in for a category -- an image shows
                        // itself instead, which is the one place this goes
                        // further than Tide.
                        IconImage {
                            id: icon

                            anchors.centerIn: parent

                            implicitSize: 108
                            source: FileShelf.isImage(card.modelData.path) ? `file://${card.modelData.path}` : card.modelData.iconSource
                            asynchronous: true
                            mipmap: true
                        }

                        MaterialIcon {
                            anchors.centerIn: parent

                            visible: icon.source.toString() === "" || icon.status === Image.Error
                            text: card.modelData.directory ? "folder" : "draft"
                            color: Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.builders.extraLarge.build()
                        }
                    }

                    IslandText {
                        anchors.top: iconBox.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 7
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9

                        text: card.modelData.displayName
                        color: card.selected ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                        font.pixelSize: IslandTokens.bodyPixelSize - 5
                        font.weight: card.selected ? 500 : 400
                    }
                }

                MouseArea {
                    id: area

                    anchors.fill: parent

                    z: 1
                    hoverEnabled: true
                    cursorShape: cardDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    onClicked: root.selectedIndex = card.index
                    onDoubleClicked: {
                        if (root.suppressedOpenPath !== card.modelData.path)
                            FileShelf.open(card.modelData.path);
                    }
                }

                // Taking it off the shelf, on hover only: the card is mostly
                // icon, and a permanent button over it reads as part of the
                // file.
                StyledRect {
                    id: remove

                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 2
                    anchors.rightMargin: 16

                    z: 20
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: width / 2
                    color: Colours.palette.m3surfaceContainerHighest
                    opacity: (area.containsMouse || removeArea.containsMouse) && !cardDrag.active && !root.reorderActive ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent

                        text: "close"
                        color: Colours.palette.m3onSurface
                        fontStyle: Tokens.font.icon.small
                    }

                    MouseArea {
                        id: removeArea

                        anchors.fill: parent

                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            mouse.accepted = true;
                            root.removeAt(card.index);
                        }
                    }
                }

                DragHandler {
                    id: cardDrag

                    // Set once the gesture has been classified as a drag out
                    // of the shelf rather than a sort within it.
                    property bool exporting: false

                    target: null
                    acceptedButtons: Qt.LeftButton
                    xAxis.enabled: true
                    yAxis.enabled: true

                    function classify(): void {
                        if (!active || exporting)
                            return;

                        const point = card.mapToItem(tray, centroid.position.x, centroid.position.y);
                        const vertical = Math.abs(activeTranslation.y) >= 22 && Math.abs(activeTranslation.y) > Math.abs(activeTranslation.x);
                        const left = point.x < -12 || point.x > tray.width + 12 || point.y < -12 || point.y > tray.height + 12;

                        if (vertical || left) {
                            exporting = true;
                            root.cancelReorder();
                            face.Drag.active = true;
                            return;
                        }

                        root.updateReorder(activeTranslation.x, point.x);
                    }

                    onActiveChanged: {
                        if (active) {
                            exporting = false;
                            root.suppressedOpenPath = card.modelData.path;
                            root.beginReorder(card.index);
                            classify();
                        } else if (card.reorderSource) {
                            root.finishReorder();
                        } else {
                            face.Drag.active = false;
                            exporting = false;
                        }
                    }

                    onActiveTranslationChanged: classify()
                    onCentroidChanged: classify()
                }
            }
        }
    }
}
