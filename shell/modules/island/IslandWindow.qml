pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

// The island's content window.
//
// Only content is drawn here: the notch shape itself belongs to the shell's blob
// group (see ContentWindow.qml), so this window is transparent and masked down
// to the capsule.
//
// The state machine is Tide Island's. Three states are *resting* -- the clock,
// and a swipe page either side of it -- and everything else either interrupts
// for a moment (a level, a workspace, a notification) or is a panel the user
// opened. The capsule morphs to a fixed size per state and the content lays out
// inside it, rather than the size following the content.
StyledWindow {
    id: root

    enum State {
        Normal,       // clock
        Custom,       // swipe left: date preview
        Lyrics,       // swipe right: lyrics / now playing
        Split,        // transient: an icon, or an icon and a level
        Long,         // transient: a line of text (workspace switches)
        Notification, // transient: a notification
        Player,       // panel: now playing
        Calendar,     // panel: calendar
        Performance,  // panel: system resources
        Overview,     // panel: workspace overview
        NotifCenter,  // panel: notification history
        Shelf,        // panel: the file shelf
        Search        // panel: the notch as a search field
    }

    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(root.screen)

    // The shell's per-screen state and panels. The island needs both because it
    // hosts Caelestia's launcher: `screenState.launcher` is what every shortcut,
    // IPC call and launcher item already toggles, so the notch claims that flag
    // rather than inventing a second one.
    readonly property ScreenState screenState: ShellState.forScreen(root.screen)
    readonly property var panels: ShellState.componentsFor(root.screen)?.panels ?? null

    readonly property bool searchOpen: (screenState?.launcher ?? false) && root.contentItem.Config.launcher.enabled


    // Mirrored by ContentWindow into the blob group.
    readonly property Item capsule: capsule

    // The resting state the island returns to. Moved by swiping.
    property int resting: IslandWindow.State.Normal

    // The panel the user opened, if any. Panels outrank transients: something
    // you opened does not get taken away by a volume key.
    property int panel: IslandWindow.State.Normal

    // Set by the hover timers, not by the pointer directly: crossing the notch
    // on the way somewhere else must not open it.
    property bool hoverExpanded

    // A file is being dragged over the notch.
    property bool dropping

    // -1 (fully on the left page) .. 1 (fully on the right page) while dragging.
    property real swipeProgress: 0
    readonly property bool swiping: swipeHandler.active

    readonly property bool hasPanel: panel !== IslandWindow.State.Normal

    readonly property int islandState: {
        // A file being dragged over the notch outranks everything: the shelf
        // has to be open and wide before the drop lands.
        if (dropping)
            return IslandWindow.State.Shelf;
        // Search outranks the other panels: asking for the launcher while the
        // calendar is open should give you the launcher.
        if (searchOpen)
            return IslandWindow.State.Search;
        if (hasPanel)
            return panel;
        if (notifications.current && IslandConfig.notifications)
            return IslandWindow.State.Notification;
        if (events.showing)
            return IslandWindow.State.Long;
        if (osd.showing && IslandConfig.osd)
            return IslandWindow.State.Split;
        if (hoverExpanded) {
            if (IslandConfig.hoverAction === IslandConfig.HoverAction.Player)
                return IslandWindow.State.Player;
            // Auto: the player when there is something to control, and
            // notification history the rest of the time.
            return Players.active ? IslandWindow.State.Player : IslandWindow.State.NotifCenter;
        }
        return resting;
    }

    readonly property bool isResting: islandState === IslandWindow.State.Normal || islandState === IslandWindow.State.Custom || islandState === IslandWindow.State.Lyrics

    // Whether the switcher pill should be showing: any state it can actually
    // switch between, whether that state was reached by an explicit
    // `openPanel()` or by the Auto hover fallback landing on NotifCenter.
    // Keying this off `hasPanel` alone missed the hover case entirely -- the
    // switcher just never appeared while hovering was what got you there.
    readonly property bool showSwitcher: [IslandWindow.State.Calendar, IslandWindow.State.Performance, IslandWindow.State.NotifCenter, IslandWindow.State.Shelf, IslandWindow.State.Overview].includes(islandState)

    // Swiping is only offered on the resting states: a panel or a transient is
    // not a page you can slide off.
    readonly property bool canSwipe: isResting && !hasPanel

    // The resting pages sit side by side: the date preview, the clock, and
    // whatever is playing. `pageOffset` is how far a page is from the middle,
    // in pages, which is all any of them needs to know to place itself.
    readonly property bool hasDatePage: IslandConfig.datePage
    readonly property bool hasMediaPage: IslandConfig.mediaPage

    function pageIndex(page: int): int {
        if (page === IslandWindow.State.Custom)
            return -1;
        if (page === IslandWindow.State.Lyrics)
            return 1;
        return 0;
    }

    function pageOffset(page: int): real {
        return pageIndex(page) - pageIndex(resting) - swipeProgress;
    }

    readonly property real targetWidth: {
        switch (islandState) {
        case IslandWindow.State.Split:
            return osd.hasLevel ? IslandTokens.splitProgressWidth : IslandTokens.restingWidth;
        case IslandWindow.State.Long:
            return IslandTokens.longWidth;
        case IslandWindow.State.Notification:
            return Math.max(IslandTokens.notifMinWidth, Math.min(root.width - IslandTokens.swipeSideMargin, notifLoader.item?.implicitWidth ?? 0));
        case IslandWindow.State.Player:
            return IslandTokens.playerWidth;
        case IslandWindow.State.Calendar:
            return IslandTokens.panelWidth;
        case IslandWindow.State.Performance:
            // Wider than the other panels: every row here is a label, a
            // reading and a figure, and at panel width they start eliding.
            return IslandTokens.widePanelWidth;
        case IslandWindow.State.Overview:
            return IslandTokens.overviewWidth;
        case IslandWindow.State.NotifCenter:
            return IslandTokens.panelWidth;
        case IslandWindow.State.Shelf:
            return Math.min(root.width - IslandTokens.swipeSideMargin, IslandTokens.shelfWidth);
        case IslandWindow.State.Search:
            return Math.min(root.width - IslandTokens.swipeSideMargin, searchLoader.item?.implicitWidth ?? IslandTokens.searchWidth);
        case IslandWindow.State.Custom:
            return Math.max(IslandTokens.swipeMinWidth, Math.min(root.width - IslandTokens.swipeSideMargin, customLoader.item?.preferredWidth ?? 0));
        case IslandWindow.State.Lyrics:
            return Math.max(IslandTokens.swipeMinWidth, Math.min(root.width - IslandTokens.swipeSideMargin, lyricsLoader.item?.preferredWidth ?? 0));
        default:
            return IslandTokens.restingWidth;
        }
    }

    readonly property real targetHeight: {
        switch (islandState) {
        case IslandWindow.State.Notification:
            return Math.max(IslandTokens.notifMinHeight, notifLoader.item?.implicitHeight ?? 0);
        case IslandWindow.State.Player:
            return IslandTokens.playerHeight;
        case IslandWindow.State.Calendar:
            return calendarLoader.item?.implicitHeight ?? IslandTokens.restingHeight;
        case IslandWindow.State.Performance:
            return performanceLoader.item?.implicitHeight ?? IslandTokens.restingHeight;
        case IslandWindow.State.Overview:
            return overviewLoader.item?.implicitHeight ?? IslandTokens.restingHeight;
        case IslandWindow.State.NotifCenter:
            return notifCenterLoader.item?.implicitHeight ?? IslandTokens.restingHeight;
        case IslandWindow.State.Shelf:
            return IslandTokens.shelfHeight;
        case IslandWindow.State.Search:
            return searchLoader.item?.implicitHeight ?? IslandTokens.searchBarHeight;

        default:
            return IslandTokens.restingHeight;
        }
    }

    readonly property real targetRadius: {
        switch (islandState) {
        case IslandWindow.State.Notification:
            return targetHeight > IslandTokens.notifMinHeight ? IslandTokens.notifRadius : targetHeight / 2;
        case IslandWindow.State.Player:
            return IslandTokens.playerRadius;
        case IslandWindow.State.Calendar:
        case IslandWindow.State.Performance:
        case IslandWindow.State.Overview:
        case IslandWindow.State.NotifCenter:
        case IslandWindow.State.Shelf:
            return IslandTokens.panelRadius;
        case IslandWindow.State.Search:
            // A pill while it is only a field, a panel once results hang off it.
            return Math.min(IslandTokens.panelRadius, targetHeight / 2);
        default:
            return IslandTokens.restingRadius;
        }
    }

    // While a drag is in progress the capsule follows the finger between the
    // resting width and the width of the page being pulled in.
    readonly property real swipePreviewWidth: {
        const p = swipeProgress;
        if (p < 0)
            return IslandTokens.restingWidth + (Math.max(IslandTokens.swipeMinWidth, customLoader.item?.preferredWidth ?? 0) - IslandTokens.restingWidth) * Math.min(1, -p);
        if (p > 0)
            return IslandTokens.restingWidth + (Math.max(IslandTokens.swipeMinWidth, lyricsLoader.item?.preferredWidth ?? 0) - IslandTokens.restingWidth) * Math.min(1, p);
        return IslandTokens.restingWidth;
    }

    function openPanel(which: int): void {
        panel = panel === which ? IslandWindow.State.Normal : which;
        hoverExpanded = false;
    }

    // Search is not one of `panel`'s values: it lives in `screenState.launcher`
    // so that the shortcut, the IPC call and every launcher item that closes
    // itself keep working untouched.
    function toggleSearch(): void {
        if (!screenState)
            return;
        screenState.launcher = !screenState.launcher;
        panel = IslandWindow.State.Normal;
        hoverExpanded = false;
    }

    function close(): void {
        panel = IslandWindow.State.Normal;
        hoverExpanded = false;
        if (screenState)
            screenState.launcher = false;
    }

    // Which resting page the swipe lands on. Tide moves one page at a time and
    // only between neighbours, so the clock is always between the two.
    function settleSwipe(progress: real): void {
        if (progress <= -0.4)
            resting = resting === IslandWindow.State.Lyrics ? IslandWindow.State.Normal : (hasDatePage ? IslandWindow.State.Custom : resting);
        else if (progress >= 0.4)
            resting = resting === IslandWindow.State.Custom ? IslandWindow.State.Normal : (hasMediaPage ? IslandWindow.State.Lyrics : resting);
        swipeProgress = 0;
    }

    // Follow the music: the media page becomes the page the island rests on
    // while something is playing, and hands the clock back when it stops. A
    // swipe still overrides it -- this only moves the page you land on when
    // nothing has been chosen.
    readonly property var activePlayer: Players.active

    onActivePlayerChanged: syncPlaybackPage()

    readonly property Connections playbackConn: Connections {
        target: root.activePlayer

        function onIsPlayingChanged(): void {
            root.syncPlaybackPage();
        }
    }

    function syncPlaybackPage(): void {
        if (!IslandConfig.followPlayback || !hasMediaPage)
            return;
        if (Players.active?.isPlaying)
            resting = IslandWindow.State.Lyrics;
        else if (resting === IslandWindow.State.Lyrics)
            resting = IslandWindow.State.Normal;
    }

    name: "island"

    // The search layer needs the keyboard; nothing else in the island does, and
    // a notch holding a grab it has no use for would swallow every shortcut.
    // OnDemand, not Exclusive, and paired with the focus grab below -- the
    // same arrangement the launcher drawer used. Exclusive takes the keyboard
    // without the compositor considering the surface focused, which makes the
    // grab clear itself the instant it activates.
    WlrLayershell.keyboardFocus: searchOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    anchors.right: true

    // Tokens is screen-scoped via contentItem, so the window object itself must
    // not read it. A plain constant is enough for the slack below the capsule.
    //
    // Fixed, deliberately: this is a layer-shell surface, and binding its height
    // to the capsule resized the Wayland surface on every frame of the morph --
    // a buffer reallocation and a full compositor recomposite sixty times a
    // second, which is what made the island judder. The window is transparent
    // and masked down to the capsule, so being permanently tall costs nothing.
    implicitHeight: Math.min(IslandTokens.windowHeight, screen.height)

    // Reserve only the resting height, so windows do not move every time the
    // island expands.
    exclusiveZone: IslandTokens.restingHeight

    // Everything outside the capsule is click-through: the island spans the full
    // width of the screen but is only actually there in the middle.
    //
    // The region follows the *target* geometry rather than the animating
    // capsule, for the same reason the window height is fixed: a region bound to
    // an animating item commits a new input region every frame. Snapping it also
    // means a panel is clickable the moment it opens rather than 400ms later.
    mask: Region {
        item: maskItem
    }

    Item {
        id: maskItem

        anchors.horizontalCenter: parent.horizontalCenter

        y: 0
        width: root.swiping ? root.swipePreviewWidth : root.targetWidth
        height: root.targetHeight
        visible: false
    }

    Item {
        id: capsule

        // The blob is a rounded rect, so the capsule publishes the radius it
        // should be drawn with rather than painting one itself.
        property real radius: root.targetRadius

        anchors.horizontalCenter: parent.horizontalCenter

        y: 0
        width: root.swiping ? root.swipePreviewWidth : root.targetWidth
        height: root.targetHeight
        clip: true

        // The morph, on all three at once. Suspended during a drag: the capsule
        // is following the finger then, and animating would lag it.
        Behavior on width {
            enabled: !root.swiping

            NumberAnimation {
                duration: IslandTokens.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: IslandTokens.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        Behavior on radius {
            NumberAnimation {
                duration: IslandTokens.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        // Hover, not click. The capsule reacts to the pointer being on it; the
        // only things that respond to a click are the controls inside it.
        HoverHandler {
            id: hover

            onHoveredChanged: {
                if (hovered) {
                    collapseTimer.stop();
                    expandTimer.restart();
                } else {
                    expandTimer.stop();
                    collapseTimer.restart();
                }
            }
        }

        // Drag across the notch to move between the resting pages.
        DragHandler {
            id: swipeHandler

            enabled: root.canSwipe
            target: null
            yAxis.enabled: false
            xAxis.enabled: true

            onActiveTranslationChanged: {
                if (active)
                    root.swipeProgress = Math.max(-1, Math.min(1, -activeTranslation.x / (IslandTokens.restingWidth * 0.6)));
            }

            onActiveChanged: {
                if (!active)
                    root.settleSwipe(root.swipeProgress);
            }
        }

        Timer {
            id: expandTimer

            interval: IslandConfig.hoverExpandDelay
            onTriggered: if (hover.hovered && !root.hasPanel && IslandConfig.hoverAction !== IslandConfig.HoverAction.None)
                root.hoverExpanded = true
        }

        Timer {
            id: collapseTimer

            interval: IslandConfig.hoverCollapseDelay
            onTriggered: if (!hover.hovered)
                root.hoverExpanded = false
        }

        // The resting pages live in a strip of their own rather than filling the
        // capsule, so that expanding to a panel does not stretch the clock out
        // across it on the way. The strip is only ever resting-sized (or as wide
        // as the page being dragged in).
        Item {
            id: restingArea

            anchors.horizontalCenter: parent.horizontalCenter

            y: 0
            width: root.swiping ? root.swipePreviewWidth : (root.isResting ? root.targetWidth : IslandTokens.restingWidth)
            height: IslandTokens.restingHeight

            Behavior on width {
                enabled: !root.swiping

                NumberAnimation {
                    duration: IslandTokens.morphDuration
                    easing.type: Easing.OutQuint
                }
            }

            // Every page fills the strip and slides or fades itself. Tide does
            // it this way so that during a swipe the page arriving and the page
            // leaving are both mounted and both moving.
            ClockLayer {
                offset: root.pageOffset(IslandWindow.State.Normal)
                showCondition: root.isResting
                animated: !root.swiping
            }

            Loader {
                id: customLoader

                anchors.fill: parent
                active: root.hasDatePage && root.canSwipe && (root.islandState === IslandWindow.State.Custom || root.swipeProgress < 0)
                visible: active

                sourceComponent: DatePreviewLayer {
                    offset: root.pageOffset(IslandWindow.State.Custom)
                    animated: !root.swiping
                }
            }

            Loader {
                id: lyricsLoader

                anchors.fill: parent
                active: root.hasMediaPage && root.canSwipe && (root.islandState === IslandWindow.State.Lyrics || root.swipeProgress > 0)
                visible: active

                sourceComponent: LyricsLayer {
                    offset: root.pageOffset(IslandWindow.State.Lyrics)
                    animated: !root.swiping
                    maximumWidth: root.width - IslandTokens.swipeSideMargin
                }
            }
        }

        IslandLayer {
            island: root
            forState: IslandWindow.State.Split

            sourceComponent: OsdLayer {
                kind: osd.kind
                value: osd.value
                muted: osd.muted
                hasLevel: osd.hasLevel
            }
        }

        IslandLayer {
            island: root
            forState: IslandWindow.State.Long

            sourceComponent: EventLayer {
                kind: events.kind
                icon: events.icon
                title: events.title
                detail: events.detail
            }
        }

        IslandLayer {
            id: notifLoader

            island: root
            forState: IslandWindow.State.Notification

            sourceComponent: NotificationLayer {
                notif: notifications.current
                maximumWidth: root.width - IslandTokens.swipeSideMargin
            }
        }

        IslandLayer {
            island: root
            forState: IslandWindow.State.Player

            sourceComponent: PlayerLayer {
                island: root
            }
        }

        IslandLayer {
            id: calendarLoader

            island: root
            forState: IslandWindow.State.Calendar

            sourceComponent: CalendarLayer {
                island: root
            }
        }

        IslandLayer {
            id: performanceLoader

            island: root
            forState: IslandWindow.State.Performance

            sourceComponent: PerformanceLayer {
                island: root
            }
        }

        // Dropping a file on the notch puts it on the shelf. Written to match
        // Tide's own DropArea exactly -- no `keys:` filter, payload checked
        // by hand, accept() called in onEntered as well as onDropped -- after
        // a `keys`-filtered version never fired at all. That still doesn't
        // land on this box: entered/dropped never fire here either, because
        // of a Hyprland bug (fixed on main in hyprwm/Hyprland#15780,
        // 2026-08-08, not yet in a packaged release as of this build,
        // 0.56.2-3 from commit efb5099 dated 2026-08-05) where keyboard
        // exclusivity held by any layer-shell surface blocks the compositor
        // from ever offering a drag to other surfaces, layer-shell or not.
        // Left in for when a build with that fix is packaged; until then the
        // working path is FileShelf.pasteFromClipboard (see ShelfLayer's
        // paste button). Drag-out (ShelfLayer's card Drag.dragType Automatic)
        // is this surface acting as the drag *source*, not a target, so it
        // may not hit the same bug -- untested against a real drag gesture,
        // worth confirming once this is live.
        DropArea {
            anchors.fill: parent

            function carriesFiles(drag): bool {
                if (drag.hasUrls)
                    return true;
                const formats = drag.formats ?? [];
                return formats.includes("text/uri-list") || formats.includes("x-special/gnome-copied-files");
            }

            onEntered: drag => {
                if (!carriesFiles(drag)) {
                    drag.accepted = false;
                    return;
                }
                drag.accept(Qt.CopyAction);
                root.dropping = true;
            }
            onExited: root.dropping = false
            onDropped: drop => {
                root.dropping = false;
                if (!carriesFiles(drop)) {
                    drop.accepted = false;
                    return;
                }
                if (drop.hasUrls) {
                    FileShelf.addAll(drop.urls);
                } else if (drop.formats.includes("text/uri-list")) {
                    FileShelf.addUriList(drop.getDataAsString("text/uri-list"));
                } else if (drop.formats.includes("x-special/gnome-copied-files")) {
                    FileShelf.addUriList(drop.getDataAsString("x-special/gnome-copied-files"));
                }
                root.panel = IslandWindow.State.Shelf;
                drop.accept(Qt.CopyAction);
            }
        }

        IslandLayer {
            id: shelfLoader

            island: root
            forState: IslandWindow.State.Shelf

            sourceComponent: ShelfLayer {
                island: root
            }
        }

        IslandLayer {
            id: notifCenterLoader

            island: root
            forState: IslandWindow.State.NotifCenter

            sourceComponent: NotificationCenterLayer {
                island: root
            }
        }

        IslandLayer {
            id: searchLoader

            island: root
            forState: IslandWindow.State.Search
            anchorTop: true

            sourceComponent: SearchLayer {
                island: root
            }
        }

        IslandLayer {
            id: overviewLoader

            island: root
            forState: IslandWindow.State.Overview

            sourceComponent: OverviewLayer {
                island: root
            }
        }

        // Fixed above every panel's own content, not inside any one panel's
        // layout: see IslandSwitcher.qml and IslandTokens.switcherReserve.
        // No fade here on purpose: this sits on top of whichever other layer
        // is active, and an animated show/hide left a ghost frame of the pill
        // visible over a transient notification toast that pre-empted it
        // mid-fade. It should be there or not, on the same frame the content
        // under it changes.
        IslandSwitcher {
            anchors.horizontalCenter: parent.horizontalCenter

            y: Tokens.padding.small
            island: root
            visible: root.showSwitcher
        }
    }

    // Clicking anywhere else closes the search, the way the launcher drawer's
    // own grab used to. It is here rather than on the drawers window because the
    // notch is a different surface: that grab would count a click on the island
    // itself as a click outside.
    // Also grabbed for an open panel, not just search: focus moving to
    // another window -- clicking it, alt-tabbing to it -- clears the grab and
    // closes whatever the notch had open, the same "click away closes it"
    // behaviour search already had. Interactions within this window itself
    // (the switcher pill included) don't count as losing focus.
    HyprlandFocusGrab {
        active: root.searchOpen || root.hasPanel
        windows: [root]
        onCleared: root.close()
    }

    OsdWatcher {
        id: osd

        monitor: root.monitor
        blocked: root.hasPanel || root.searchOpen
    }

    EventWatcher {
        id: events

        blocked: root.hasPanel || root.searchOpen
    }

    NotificationQueue {
        id: notifications
    }
}
