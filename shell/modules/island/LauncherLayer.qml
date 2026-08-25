pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher
import qs.modules.launcher.services

// The launcher, as Tide draws it: a field, and a strip of applications you
// scroll sideways.
//
// Tide's layout exactly -- a 46px pill capped at 650 wide with the magnifier
// in it, and under it a horizontally-flowing grid of 126px columns, each a
// 64px icon with its name under it. Favourites are pinned to the front with a
// number on them, starred by right-clicking, and launched by number.
//
// The *matching* is Caelestia's, not Tide's: `Apps.search` is the shell's own
// fuzzy search with its frequency ordering and its prefixes, so this is Tide's
// front end over the launcher that is already here. And anything Caelestia's
// launcher can do that a grid of applications cannot -- an action, a
// calculation, a scheme, the wallpaper list -- hands off to its real list the
// moment the query starts with a prefix, rather than being reimplemented worse.
Item {
    id: root

    required property var island

    readonly property var screenState: island.screenState

    property string query: ""
    property int selected: 0

    // Caelestia's own prefixes. `>` is actions, and the special prefix carries
    // calc, schemes, variants and wallpapers.
    readonly property bool prefixed: query.startsWith(GlobalConfig.launcher.actionPrefix) || query.startsWith(GlobalConfig.launcher.specialPrefix)

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge
    readonly property real maxHeight: IslandTokens.windowHeight - IslandTokens.searchBarHeight - padding * 4

    // Favourites first, in the order they were starred, then everything the
    // search turned up.
    readonly property var entries: {
        const results = Apps.search(query);
        if (query.length > 0)
            return results;

        const favourites = [];
        for (const id of IslandConfig.favourites) {
            const entry = results.find(e => e.id === id);
            if (entry)
                favourites.push(entry);
        }
        return [...favourites, ...results.filter(e => !IslandConfig.favourites.includes(e.id))];
    }

    readonly property real fieldHeight: 46

    implicitWidth: prefixed ? listWrapper.implicitWidth + padding * 2 : Math.min(island.width - IslandTokens.swipeSideMargin, IslandTokens.shelfWidth)
    implicitHeight: prefixed ? input.height + listWrapper.implicitHeight + padding : IslandTokens.shelfHeight

    function launch(entry: var): void {
        if (!entry)
            return;
        Apps.launch(entry);
        root.screenState.launcher = false;
    }

    function toggleFavourite(entry: var): void {
        if (!entry)
            return;
        const favourites = [...IslandConfig.favourites];
        const at = favourites.indexOf(entry.id);
        if (at >= 0)
            favourites.splice(at, 1);
        else
            favourites.push(entry.id);
        IslandConfig.favourites = favourites;
    }

    function favouriteNumber(entry: var): int {
        if (root.query.length > 0)
            return 0;
        const at = IslandConfig.favourites.indexOf(entry?.id ?? "");
        return at >= 0 && at < 9 ? at + 1 : 0;
    }

    function move(by: int): void {
        const count = entries.length;
        if (count === 0)
            return;
        selected = Math.max(0, Math.min(count - 1, selected + by));
        grid.positionViewAtIndex(selected, GridView.Contain);
    }

    onQueryChanged: selected = 0

    // The field takes the keyboard the moment the layer exists. Closing is what
    // gives it back -- see IslandWindow's focus grab.
    Component.onCompleted: input.forceActiveFocus()

    // -- Tide's search pill ----------------------------------------------
    //
    // Caelestia's own SearchBar, wearing Tide's shape: 46 tall, capped at 650,
    // radius 17 with a hairline that lights on focus. It stays the shell's
    // field rather than a TextInput of my own because Caelestia's launcher
    // list is handed this object and reads its text, its focus and its
    // keybinds -- a lookalike would break every prefix the launcher has.
    SearchBar {
        id: input

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: root.prefixed ? 0 : IslandTokens.panelPadding

        objectName: "launcherSearch"

        implicitWidth: root.prefixed ? parent.width - root.padding * 2 : Math.min(650, parent.width - 120)
        implicitHeight: root.fieldHeight

        topPadding: 0
        bottomPadding: 0
        font.family: IslandConfig.fontFamily
        font.pixelSize: 15
        placeholderText: qsTr("Search")

        onTextChanged: root.query = text

        Component.onCompleted: {
            bg.radius = 17;
            bg.border.width = 1;
        }

        Binding {
            target: input.bg
            property: "color"
            value: input.activeFocus ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surfaceContainer
        }

        Binding {
            target: input.bg
            property: "border.color"
            value: input.activeFocus ? Colours.palette.m3outline : Colours.palette.m3outlineVariant
        }

        Keys.onPressed: event => {
            // Alt and a number launches that favourite, wherever the pointer
            // or the selection happens to be.
            if ((event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                const index = event.key - Qt.Key_1;
                const id = IslandConfig.favourites[index];
                if (id)
                    root.launch(root.entries.find(e => e.id === id));
                event.accepted = true;
                return;
            }

            switch (event.key) {
            case Qt.Key_Escape:
                root.screenState.launcher = false;
                event.accepted = true;
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (root.prefixed)
                    return;
                root.launch(root.entries[root.selected]);
                event.accepted = true;
                return;
            case Qt.Key_Right:
            case Qt.Key_Down:
            case Qt.Key_Tab:
                if (root.prefixed)
                    return;
                root.move(1);
                event.accepted = true;
                return;
            case Qt.Key_Left:
            case Qt.Key_Up:
            case Qt.Key_Backtab:
                if (root.prefixed)
                    return;
                root.move(-1);
                event.accepted = true;
                return;
            }
        }
    }

    // -- Tide's application strip ----------------------------------------
    GridView {
        id: grid

        anchors.top: input.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 10
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.bottomMargin: 12

        visible: !root.prefixed
        model: root.visible && !root.prefixed ? root.entries : []
        cellWidth: 126
        cellHeight: height
        flow: GridView.FlowTopToBottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 1800
        keyNavigationEnabled: false

        delegate: Item {
            id: tile

            required property var modelData
            required property int index

            readonly property bool isSelected: index === root.selected
            readonly property bool favourite: IslandConfig.favourites.includes(modelData.id)
            readonly property int number: root.favouriteNumber(modelData)

            width: grid.cellWidth
            height: grid.cellHeight

            Item {
                anchors.centerIn: parent

                width: parent.width - 10
                height: 124
                scale: area.pressed ? 0.95 : (tile.isSelected || area.containsMouse ? 1.035 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: iconArea

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 76
                    height: 76

                    IconImage {
                        id: icon

                        anchors.centerIn: parent

                        implicitSize: 64
                        source: Quickshell.iconPath(tile.modelData.icon, true)
                        asynchronous: true
                        mipmap: true
                    }

                    // Not every entry has an icon that resolves; the initial
                    // is better than a hole in the strip.
                    IslandText {
                        anchors.centerIn: parent

                        visible: icon.source.toString() === ""
                        text: (tile.modelData.name ?? "?").charAt(0).toUpperCase()
                        font.pixelSize: 24
                    }

                    IslandText {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.topMargin: -2
                        anchors.leftMargin: -2

                        visible: tile.number > 0
                        text: `${tile.number}`
                        dim: true
                        font.pixelSize: 12
                    }

                    // The star, as Tide has it: only there once the entry is a
                    // favourite or the pointer is on it.
                    MaterialIcon {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -2
                        anchors.rightMargin: -4

                        text: "star"
                        color: tile.favourite ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.small
                        fill: tile.favourite ? 1 : 0
                        opacity: tile.favourite ? 1 : (area.containsMouse ? 0.68 : 0)
                        scale: tile.favourite ? 1 : 0.9

                        Behavior on opacity {
                            CAnim {}
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutBack
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6

                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleFavourite(tile.modelData)
                        }
                    }
                }

                IslandText {
                    anchors.top: iconArea.bottom
                    anchors.topMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: parent.width - 8
                    text: tile.modelData.name ?? ""
                    color: tile.isSelected ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent

                z: -1
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: root.selected = tile.index

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        root.toggleFavourite(tile.modelData);
                    else
                        root.launch(tile.modelData);
                }
            }
        }
    }

    // -- Caelestia's own list, for everything a grid of applications is not --
    Item {
        id: listWrapper

        anchors.top: input.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: list.implicitWidth
        implicitHeight: list.implicitHeight + root.padding
        visible: root.prefixed

        ContentList {
            id: list

            content: root
            screenState: root.screenState
            panels: root.island.panels
            maxHeight: root.maxHeight
            search: input
            padding: root.padding
            rounding: root.rounding
        }
    }
}
