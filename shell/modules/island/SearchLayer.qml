pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher
import qs.modules.launcher.services

// The notch as Caelestia's launcher.
//
// This is not a second launcher: it is `modules/launcher/ContentList` -- the
// real one, apps and actions and calc and schemes and variants and the
// wallpaper picker -- hosted in the island's shape instead of in a drawer at
// the bottom of the screen. Everything Caelestia's launcher does, it does here,
// because it is the same code: the same fuzzy matching, the same frequency
// ordering, the same `>` actions and `:` prefixes, the same keybinds.
//
// The only real change is the direction. The drawer put its field at the bottom
// with results growing up out of it; the notch puts the field where the clock
// was and hangs the results underneath.
Item {
    id: root

    required property var island

    readonly property var screenState: island.screenState

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge

    // The window the island draws into is a fixed height, so the list has to be
    // told to stop before it runs out of surface.
    readonly property real maxHeight: IslandTokens.windowHeight - IslandTokens.searchBarHeight - padding * 4

    implicitWidth: listWrapper.implicitWidth + padding * 2
    implicitHeight: search.height + listWrapper.implicitHeight + padding

    // The field takes the keyboard the moment the layer exists. Closing is what
    // gives it back -- see IslandWindow's focus grab.
    Component.onCompleted: search.forceActiveFocus()

    SearchBar {
        id: search

        objectName: "launcherSearch"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: IslandTokens.contentSpacing
        anchors.rightMargin: IslandTokens.contentSpacing

        topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
        bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)

        placeholderText: qsTr("Type \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix)

        // The capsule is the field. SearchBar draws its own filled pill, which
        // inside the notch would be a surface on a surface.
        Component.onCompleted: bg.color = "transparent"

        onAccepted: {
            const currentItem = list.currentList?.currentItem;
            if (!currentItem)
                return;

            if (list.showWallpapers) {
                if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.actualCurrent)
                    Wallpapers.previewColourLock = true;
                Wallpapers.setWallpaper(currentItem.modelData.path);
                root.screenState.launcher = false;
            } else if (text.startsWith(GlobalConfig.launcher.actionPrefix)) {
                if (text.startsWith(`${GlobalConfig.launcher.actionPrefix}calc `))
                    currentItem.onClicked();
                else
                    currentItem.modelData.onClicked(list.currentList);
            } else {
                Apps.launch(currentItem.modelData);
                root.screenState.launcher = false;
            }
        }

        Keys.onUpPressed: list.currentList?.decrementCurrentIndex()
        Keys.onDownPressed: list.currentList?.incrementCurrentIndex()

        Keys.onEscapePressed: root.screenState.launcher = false

        Keys.onPressed: event => {
            if (!GlobalConfig.launcher.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab) {
                list.currentList?.incrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                list.currentList?.decrementCurrentIndex();
                event.accepted = true;
            }
        }
    }

    Item {
        id: listWrapper

        // Implicit rather than actual width: ContentList anchors itself to this
        // item's edges, so sizing this item to the list's *actual* width would
        // be each one waiting on the other.
        implicitWidth: list.implicitWidth
        implicitHeight: list.implicitHeight + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: search.bottom

        ContentList {
            id: list

            content: root
            screenState: root.screenState
            panels: root.island.panels
            maxHeight: root.maxHeight
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }
}
