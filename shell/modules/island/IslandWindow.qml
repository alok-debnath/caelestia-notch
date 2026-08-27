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
        FaceId,       // transient: a biopass face scan
        Bluetooth,    // transient: a device just connected
        Player,       // panel: now playing
        Performance,  // panel: system resources
        Overview,     // panel: workspace overview
        NotifCenter,  // panel: notification history
        Shelf,        // panel: the file shelf
        Clipboard,    // panel: clipboard history
        Wallpaper,    // panel: the wallpaper library
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

    // -- The top gesture strip ------------------------------------------
    //
    // Tide's island takes input across the whole reserved strip along the top
    // of the screen, not just the capsule, and that strip is the entire reason
    // its drag-and-drop works. A Wayland drag is only ever offered to the
    // surface under the pointer whose *input region* contains that point: at
    // rest the capsule is 140x38 in the middle of an 1800px screen, so a file
    // dragged at the notch was handed to whatever was behind it unless it
    // landed dead centre. The strip makes the whole top edge a drop target.
    //
    // Bounded by the monitor's reserved edges so the bar keeps its own clicks,
    // and dropped entirely once a panel is open -- the capsule's own region is
    // bigger than the strip by then.
    readonly property var monitorReserved: Hypr.monitorFor(screen)?.lastIpcObject?.reserved ?? [0, 0, 0, 0]
    readonly property bool gestureStripActive: !hasPanel && !searchOpen
    readonly property real gestureStripX: monitorReserved[0]
    readonly property real gestureStripWidth: gestureStripActive ? Math.max(0, width - monitorReserved[0] - monitorReserved[2]) : 0
    readonly property real gestureStripHeight: gestureStripActive ? IslandTokens.restingHeight : 0

    // -1 (fully on the left page) .. 1 (fully on the right page) while dragging.
    property real swipeProgress: 0
    // True while the strip is being moved by hand -- a drag, or a wheel that
    // has not settled yet. The capsule follows directly then rather than
    // animating, which is what keeps it under the finger.
    property bool wheeling: false
    readonly property bool swiping: swipeHandler.active || wheeling

    readonly property bool hasPanel: panel !== IslandWindow.State.Normal

    readonly property int islandState: {
        // A file being dragged over the notch outranks everything: the shelf
        // has to be open and wide before the drop lands.
        if (dropping)
            return IslandWindow.State.Shelf;
        // Search outranks the other panels: asking for the launcher while a
        // panel is open should give you the launcher.
        if (searchOpen)
            return IslandWindow.State.Search;
        if (hasPanel)
            return panel;
        if (notifications.current && IslandConfig.notifications)
            return IslandWindow.State.Notification;
        // A scan outranks the levels and the announcements: it is the answer to
        // something the user is standing in front of the camera waiting for.
        if (faceId.showing)
            return IslandWindow.State.FaceId;
        if (bluetooth.showing && IslandConfig.bluetooth)
            return IslandWindow.State.Bluetooth;
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

    // The switcher's tabs, left to right. It is the switcher's own order, and
    // it is also the axis panels travel along when one replaces another: this
    // is the one list both read, so the highlight and the content can never
    // disagree about which way the switch went.
    // What the tabs are called, for the row that opens on hover. Parallel to
    // `panelOrder`.
    readonly property var panelNames: [qsTr("System"), qsTr("Notifications"), qsTr("Workspaces"), qsTr("Wallpapers")]

    readonly property var panelOrder: [IslandWindow.State.Performance, IslandWindow.State.NotifCenter, IslandWindow.State.Overview, IslandWindow.State.Wallpaper]

    // -1, 0 or 1: which way along `panelOrder` the last state change moved.
    // Zero for anything that is not a switch between two tabs -- opening a
    // panel from resting, or a transient interrupting -- so those still just
    // fade rather than sliding in from a side that means nothing.
    property int switchDirection: 0
    property int previousState: IslandWindow.State.Normal

    // Declared above the layers on purpose: handlers on the same signal run in
    // the order they were connected, so this one has to be in place before the
    // layers react to the state change and read the direction out of it.
    onIslandStateChanged: {
        const from = panelOrder.indexOf(previousState);
        const to = panelOrder.indexOf(islandState);
        switchDirection = from >= 0 && to >= 0 ? Math.sign(to - from) : 0;
        previousState = islandState;
    }


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

    // The transients: a level, a workspace, a face scan. Short-lived states
    // that take the box over and hand it straight back.
    readonly property bool isTransient: islandState === IslandWindow.State.Split || islandState === IslandWindow.State.Long || islandState === IslandWindow.State.FaceId || islandState === IslandWindow.State.Bluetooth

    // A transient that interrupts while the island is resting on a side page
    // arrives from that side, and the page it replaces leaves the way a swipe
    // would take it -- Tide's `splitOriginSide`. Zero on the clock (there is
    // no side to come from) and zero for a notification, which Tide treats as
    // its own thing rather than as part of the strip.
    readonly property int transientSide: {
        if (!isTransient)
            return 0;
        if (resting === IslandWindow.State.Custom)
            return -1;
        if (resting === IslandWindow.State.Lyrics)
            return 1;
        return 0;
    }

    function pageOffset(page: int): real {
        // `- transientSide` is the push: the page goes off the way the
        // transient came in, so the two move as one strip rather than as a
        // fade between two unrelated things.
        return pageIndex(page) - pageIndex(resting) - swipeProgress - transientSide;
    }

    readonly property real targetWidth: {
        switch (islandState) {
        case IslandWindow.State.Split:
            return osd.hasLevel ? IslandTokens.splitProgressWidth : IslandTokens.restingWidth;
        case IslandWindow.State.Long:
            return IslandTokens.longWidth;
        case IslandWindow.State.FaceId:
            return IslandTokens.longWidth;
        case IslandWindow.State.Notification:
            return Math.max(IslandTokens.notifMinWidth, Math.min(root.width - IslandTokens.swipeSideMargin, notifLoader.item?.implicitWidth ?? 0));
        case IslandWindow.State.Bluetooth:
            return Math.max(IslandTokens.longWidth, Math.min(root.width - IslandTokens.swipeSideMargin, bluetoothLoader.item?.preferredWidth ?? 0));
        case IslandWindow.State.Player:
            return IslandTokens.playerWidth;
        case IslandWindow.State.Performance:
            // Wider than the other panels: every row here is a label, a
            // reading and a figure, and at panel width they start eliding.
            return IslandTokens.widePanelWidth;
        case IslandWindow.State.Overview:
            // The slab is as wide as its own grid, not a fixed panel width.
            return Math.min(root.width - IslandTokens.swipeSideMargin, overviewLoader.item?.implicitWidth ?? IslandTokens.overviewWidth);
        case IslandWindow.State.NotifCenter:
            return IslandTokens.panelWidth;
        case IslandWindow.State.Shelf:
            return Math.min(root.width - IslandTokens.swipeSideMargin, IslandTokens.shelfWidth);
        case IslandWindow.State.Clipboard:
            return IslandTokens.panelWidth;
        case IslandWindow.State.Wallpaper:
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
        case IslandWindow.State.Performance:
            return performanceLoader.item?.implicitHeight ?? IslandTokens.restingHeight;
        case IslandWindow.State.Overview:
            return overviewLoader.item?.implicitHeight ?? IslandTokens.restingHeight;
        case IslandWindow.State.NotifCenter:
            return notifCenterLoader.item?.implicitHeight ?? IslandTokens.restingHeight;
        case IslandWindow.State.Shelf:
            return IslandTokens.shelfHeight;
        case IslandWindow.State.Clipboard:
            return IslandTokens.clipboardHeight;
        case IslandWindow.State.Wallpaper:
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
            // A pill until it is opened out, then a panel -- Tide's rule.
            return notifications.expanded ? IslandTokens.notifRadius : targetHeight / 2;
        case IslandWindow.State.Player:
            return IslandTokens.playerRadius;
        case IslandWindow.State.Performance:
        case IslandWindow.State.Overview:
        case IslandWindow.State.NotifCenter:
        case IslandWindow.State.Shelf:
        case IslandWindow.State.Clipboard:
        case IslandWindow.State.Wallpaper:
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

    // Which page the expanded panel is on -- now playing, or the timer. Kept
    // on the window rather than in the layer: the panel is unloaded every time
    // it closes, and coming back to the page you left is the whole point.
    property int playerPage: 0

    function openTimer(): void {
        playerPage = 1;
        if (panel !== IslandWindow.State.Player)
            openPanel(IslandWindow.State.Player);
    }

    // A face scan has started somewhere in the session. Called from the IPC
    // handler in Island.qml, which is what the pam_exec gate pings.
    function beginFaceId(): void {
        faceId.begin();
    }

    // The actions a click can be bound to. Strings rather than an enum so the
    // config file stays readable and a new one does not renumber the old.
    // Where the open panel sits in the tab order, or -1 for a surface that is
    // not one of the tabs (the player, search, a transient).
    readonly property int panelIndex: panelOrder.indexOf(islandState)

    // Move between tabs. Clamped rather than wrapping: the dots say where the
    // ends are, and a carousel that loops makes them a lie.
    function stepPanel(by: int): void {
        if (panelIndex < 0)
            return;
        const next = Math.max(0, Math.min(panelOrder.length - 1, panelIndex + by));
        if (next !== panelIndex)
            panel = panelOrder[next];
    }

    function showPanelAt(index: int): void {
        if (index >= 0 && index < panelOrder.length)
            panel = panelOrder[index];
    }

    function runAction(action: string): void {
        switch (action) {
        case "player":
            openPanel(IslandWindow.State.Player);
            return;
        case "overview":
            openPanel(IslandWindow.State.Overview);
            return;
        case "notifications":
            openPanel(IslandWindow.State.NotifCenter);
            return;
        case "performance":
            openPanel(IslandWindow.State.Performance);
            return;
        case "wallpapers":
            openPanel(IslandWindow.State.Wallpaper);
            return;
        case "shelf":
            openPanel(IslandWindow.State.Shelf);
            return;
        case "clipboard":
            openPanel(IslandWindow.State.Clipboard);
            return;
        case "timer":
            openTimer();
            return;
        case "search":
            toggleSearch();
            return;
        case "close":
            close();
            return;
        default:
            return;
        }
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
    // The shelf takes it too, for Tide's card keys -- arrows to move along the
    // tray, Delete to take one off, Enter to open it.
    WlrLayershell.keyboardFocus: searchOpen || panel === IslandWindow.State.Shelf ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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

        // The bubbles sit outside the capsule, so the capsule's own region
        // does not cover them and a click would fall through to whatever is
        // behind the notch. Bound by hand rather than with `item:` so a bubble
        // that is not up claims nothing.
        Region {
            x: tabs.x
            y: tabs.y
            width: tabs.visible ? tabs.width : 0
            height: tabs.visible ? tabs.height : 0
        }

        Region {
            x: shelfBubble.x
            y: shelfBubble.y
            width: shelfBubble.visible ? shelfBubble.width : 0
            height: shelfBubble.visible ? shelfBubble.height : 0
        }

        Region {
            x: timerBubble.x
            y: timerBubble.y
            width: timerBubble.visible ? timerBubble.width : 0
            height: timerBubble.visible ? timerBubble.height : 0
        }

        // The drop target: see `gestureStripActive` above.
        Region {
            x: root.gestureStripX
            y: 0
            width: root.gestureStripWidth
            height: root.gestureStripHeight
        }
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
        // What a click on the capsule does.
        //
        // Tide has no tab strip: the island is one object, and which surface it
        // opens is a *property of the click*, configured per button (Panels ->
        // Island -> Clicks). A pill of tabs floating over the panel was this
        // island's own invention and the one part of it that never belonged --
        // it turned a shape that morphs into a window with chrome.
        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.ReleaseWithinBounds

            onTapped: root.runAction(IslandConfig.clickAction)
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds

            onTapped: root.runAction(IslandConfig.rightClickAction)
        }

        TapHandler {
            acceptedButtons: Qt.MiddleButton
            gesturePolicy: TapHandler.ReleaseWithinBounds

            onTapped: root.runAction(IslandConfig.middleClickAction)
        }

        // Scroll over the notch to move between the resting pages.
        //
        // Tide's own gesture, and the better one: the wheel scrubs the strip
        // live -- the clock leaving and the page arriving track the notches --
        // and 150 ms after the last notch it settles to whichever page it is
        // nearest. A wheel event carries no press and no release, so the settle
        // timer is what stands in for letting go.
        WheelHandler {
            id: wheel

            property real accumulated: 0

            enabled: root.canSwipe
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            orientation: Qt.Horizontal | Qt.Vertical

            onWheel: event => {
                if (!wheelSettle.running) {
                    wheel.accumulated = root.swipeProgress * IslandTokens.restingWidth * 0.6;
                    root.wheeling = true;
                }

                // Whichever axis moved more: a horizontal trackpad flick and a
                // vertical mouse wheel are the same gesture on a strip that
                // only moves sideways. Tide's 0.8 damping, so a notch is a
                // nudge rather than a page.
                const px = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0 ? event.pixelDelta : Qt.point(event.angleDelta.x / 4, event.angleDelta.y / 4);
                const delta = Math.abs(px.x) > Math.abs(px.y) ? px.x : px.y;

                wheel.accumulated -= delta * 0.8;
                root.swipeProgress = Math.max(-1, Math.min(1, wheel.accumulated / (IslandTokens.restingWidth * 0.6)));
                wheelSettle.restart();
            }
        }

        Timer {
            id: wheelSettle

            interval: 150
            onTriggered: {
                root.wheeling = false;
                root.settleSwipe(root.swipeProgress);
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
            // The box is the capsule while the strip owns it -- including
            // through a transient that came in from a side page, which is
            // still the strip's own motion finishing.
            width: root.swiping ? root.swipePreviewWidth : (root.isResting || root.transientSide !== 0 ? root.targetWidth : IslandTokens.restingWidth)
            height: IslandTokens.restingHeight

            Behavior on width {
                enabled: !root.swiping

                NumberAnimation {
                    duration: IslandTokens.morphDuration
                    easing.type: Easing.OutQuint
                }
            }

            // Tide's strip: one box, and the pages move their own content
            // through it. Which pages are mounted follows Tide exactly -- the
            // media page owns the box from the middle rightward, the status
            // page from the middle leftward, and whichever of the two is up at
            // rest is the one drawing the clock. Both stay mounted through a
            // transient that came in from their side, so the page can leave
            // along the same axis instead of blinking out under it.
            readonly property bool mediaPageMounted: root.hasMediaPage && !root.hasPanel && (root.islandState === IslandWindow.State.Lyrics || (root.islandState === IslandWindow.State.Normal && root.swipeProgress >= 0) || root.transientSide === 1)
            readonly property bool statusPageMounted: root.hasDatePage && !root.hasPanel && (root.islandState === IslandWindow.State.Custom || ((root.islandState === IslandWindow.State.Normal || (root.islandState === IslandWindow.State.Lyrics && !root.hasMediaPage)) && root.swipeProgress < 0) || root.transientSide === -1)

            opacity: root.isResting || root.transientSide !== 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: root.isResting ? 220 : 140
                    easing.type: Easing.InOutQuad
                }
            }

            // The fallback clock, for a notch with both side pages turned off:
            // then no page is mounted to carry the time.
            ClockLayer {
                anchors.fill: parent

                visible: !restingArea.mediaPageMounted && !restingArea.statusPageMounted
            }

            Loader {
                id: lyricsLoader

                anchors.fill: parent
                active: restingArea.mediaPageMounted
                visible: active

                sourceComponent: LyricsLayer {
                    animated: !root.swiping
                    offset: root.pageOffset(IslandWindow.State.Lyrics)
                    maximumWidth: root.width - IslandTokens.swipeSideMargin
                    // The transient that came in from this side is standing
                    // where the clock would be.
                    showClock: root.transientSide !== 1
                }
            }

            Loader {
                id: customLoader

                anchors.fill: parent
                active: restingArea.statusPageMounted
                visible: active

                sourceComponent: DatePreviewLayer {
                    animated: !root.swiping
                    offset: root.pageOffset(IslandWindow.State.Custom)
                    showClock: root.transientSide !== -1
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
            forState: IslandWindow.State.FaceId

            sourceComponent: FaceIdLayer {
                scanning: faceId.scanning
                result: faceId.result
            }
        }

        IslandLayer {
            id: bluetoothLoader

            island: root
            forState: IslandWindow.State.Bluetooth

            sourceComponent: BluetoothLayer {
                device: bluetooth.device
                maximumWidth: root.width - IslandTokens.swipeSideMargin
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
                expanded: notifications.expanded
                onExpansionToggled: notifications.toggleExpanded()
            }
        }

        IslandLayer {
            island: root
            forState: IslandWindow.State.Wallpaper

            sourceComponent: WallpaperLayer {
                island: root
            }
        }

        IslandLayer {
            island: root
            forState: IslandWindow.State.Player

            sourceComponent: PlayerLayer {
                island: root
                Component.onCompleted: settlePage(root.playerPage)
                onCurrentPageChanged: root.playerPage = currentPage
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

        // Dropping a file on the notch puts it on the shelf.
        //
        // Written to match Tide's own DropArea exactly: no `keys:` filter, the
        // payload checked by hand, and accept() called in onEntered as well as
        // onDropped. What was missing was not here at all but in the window's
        // input mask -- see `gestureStripActive` above. A Wayland drag is only
        // ever offered to the surface whose input region contains the pointer,
        // and at rest that region was the 140x38 capsule, so a file dragged at
        // the notch went to whatever was behind it. Tide's island takes input
        // across the whole top strip of the screen, which is what makes its
        // shelf catch anything at all; ours does now too.
        DropArea {
            anchors.fill: parent

            // Over every layer, as Tide has it: the panels are siblings drawn
            // after this, and a drag offered to one of them is a drag the
            // shelf never sees.
            z: 10000

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
            id: clipboardLoader

            island: root
            forState: IslandWindow.State.Clipboard

            sourceComponent: ClipboardLayer {
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

            sourceComponent: LauncherLayer {
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

    }

    // Is the pointer on the island?
    //
    // Declared here rather than on the capsule, which is where it used to be,
    // and the move is the whole fix for a flicker that made the notch open and
    // shut under the pointer: Qt hands a hover event to the *topmost sibling*
    // that accepts it, so the moment the tab row (a sibling drawn over the
    // capsule) took the hover, the capsule's own handler went false, the
    // collapse timer ran, the hover-opened panel closed, the row went with it,
    // the pointer was over the capsule again -- and round it went.
    //
    // A handler declared at window scope attaches to the content item, which
    // is an *ancestor* of the capsule, the tab row and both bubbles, and
    // ancestors keep receiving hover no matter which descendant accepts it.
    // The window's input mask is what makes this mean "on the island" rather
    // than "anywhere on this screen-wide surface": outside the capsule and the
    // bubbles, the surface takes no input at all.
    HoverHandler {
        id: hover
    }

    // ...but the mask is no longer only the island: the top gesture strip put
    // the whole top edge of the screen into it (so a drag has somewhere to
    // land), and without this the notch would unroll whenever the pointer
    // crossed any part of that edge. So "on the island" is decided by hand,
    // and it means the capsule, with a little slack -- not the bubbles.
    //
    // The bubbles are pointedly excluded. They only exist while the island is
    // resting, so counting a hover on one as a hover on the island expanded
    // the notch, which stopped it resting, which took the bubble out from
    // under the pointer that was reaching for it. Aiming at the shelf bubble
    // meant watching it vanish.
    readonly property real hoverSlack: 12
    readonly property bool pointerOnIsland: {
        if (!hover.hovered)
            return false;

        const p = hover.point.position;
        return p.x >= capsule.x - hoverSlack && p.x <= capsule.x + capsule.width + hoverSlack && p.y >= 0 && p.y <= capsule.y + capsule.height + hoverSlack;
    }

    onPointerOnIslandChanged: {
        if (pointerOnIsland) {
            collapseTimer.stop();
            expandTimer.restart();
        } else {
            expandTimer.stop();
            collapseTimer.restart();
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
    // Which tab is open, at the foot of the panel. The same row the player
    // uses for its two pages, so one dot row means the same thing everywhere
    // in the island -- and it is the drag handle, since the panels themselves
    // own their drags.
    PageDots {
        id: tabs

        anchors.horizontalCenter: capsule.horizontalCenter
        anchors.top: capsule.top
        anchors.topMargin: IslandTokens.dotsMargin

        count: root.panelOrder.length
        position: Math.max(0, root.panelIndex)
        labels: root.panelNames
        opacity: root.panelIndex >= 0 ? 1 : 0
        visible: opacity > 0

        onSelected: index => root.showPanelAt(index)

        Behavior on opacity {
            NumberAnimation {
                duration: IslandTokens.contentFadeDuration
                easing.type: Easing.InOutQuad
            }
        }
    }

    // The bubbles: what the island is holding for you while it rests.
    //
    // Both slide out from behind the capsule's own edge rather than fading in
    // beside it -- they start overlapped, small and low, and rise into place,
    // so they read as something the island pushed out. Only while it is
    // resting: a panel or a notification is already the thing being looked at.
    ShelfBubble {
        id: shelfBubble

        readonly property real hiddenX: capsule.x - width * 0.38
        readonly property real shownX: capsule.x - width - 8

        x: hiddenX + (shownX - hiddenX) * reveal
        y: capsule.y + (capsule.height - height) / 2 + (1 - reveal) * 10
        z: 6

        opacity: root.isResting ? 1 : 0

        onTriggered: root.openPanel(IslandWindow.State.Shelf)

        Behavior on opacity {
            NumberAnimation {
                duration: IslandTokens.contentFadeDuration
                easing.type: Easing.InOutQuad
            }
        }
    }

    TimerBubble {
        id: timerBubble

        readonly property real hiddenX: capsule.x + capsule.width - width * 0.62
        readonly property real shownX: capsule.x + capsule.width + 8

        x: hiddenX + (shownX - hiddenX) * reveal
        y: capsule.y + (capsule.height - height) / 2 + (1 - reveal) * 10
        z: 6

        opacity: root.isResting ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: IslandTokens.contentFadeDuration
                easing.type: Easing.InOutQuad
            }
        }

        MouseArea {
            anchors.fill: parent

            cursorShape: Qt.PointingHandCursor

            onClicked: root.openTimer()
        }
    }

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

    BluetoothWatcher {
        id: bluetooth

        blocked: root.hasPanel || root.searchOpen
    }

    FaceIdWatcher {
        id: faceId

        blocked: root.hasPanel || root.searchOpen
    }

    NotificationQueue {
        id: notifications
    }
}
