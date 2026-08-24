pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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
        Control       // panel: control centre
    }

    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(root.screen)

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

    // -1 (fully on the left page) .. 1 (fully on the right page) while dragging.
    property real swipeProgress: 0
    readonly property bool swiping: swipeHandler.active

    readonly property bool hasPanel: panel !== IslandWindow.State.Normal

    readonly property int islandState: {
        if (hasPanel)
            return panel;
        if (notifications.current)
            return IslandWindow.State.Notification;
        if (events.showing)
            return IslandWindow.State.Long;
        if (osd.showing)
            return IslandWindow.State.Split;
        if (hoverExpanded)
            return IslandWindow.State.Player;
        return resting;
    }

    readonly property bool isResting: islandState === IslandWindow.State.Normal || islandState === IslandWindow.State.Custom || islandState === IslandWindow.State.Lyrics

    // Swiping is only offered on the resting states: a panel or a transient is
    // not a page you can slide off.
    readonly property bool canSwipe: isResting && !hasPanel

    // The resting pages sit side by side: the date preview, the clock, and
    // whatever is playing. `pageOffset` is how far a page is from the middle,
    // in pages, which is all any of them needs to know to place itself.
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
        case IslandWindow.State.Control:
            return IslandTokens.controlWidth;
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
        case IslandWindow.State.Control:
            return IslandTokens.controlHeight;
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
        case IslandWindow.State.Control:
            return IslandTokens.panelRadius;
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

    function close(): void {
        panel = IslandWindow.State.Normal;
        hoverExpanded = false;
    }

    // Which resting page the swipe lands on. Tide moves one page at a time and
    // only between neighbours, so the clock is always between the two.
    function settleSwipe(progress: real): void {
        if (progress <= -0.4)
            resting = resting === IslandWindow.State.Lyrics ? IslandWindow.State.Normal : IslandWindow.State.Custom;
        else if (progress >= 0.4)
            resting = resting === IslandWindow.State.Custom ? IslandWindow.State.Normal : IslandWindow.State.Lyrics;
        swipeProgress = 0;
    }

    name: "island"

    anchors.top: true
    anchors.left: true
    anchors.right: true

    // Tokens is screen-scoped via contentItem, so the window object itself must
    // not read it. A plain constant is enough for the slack below the capsule.
    implicitHeight: capsule.y + capsule.height + IslandTokens.verticalPadding * 2

    // Reserve only the resting height, so windows do not move every time the
    // island expands.
    exclusiveZone: IslandTokens.restingHeight

    // Everything outside the capsule is click-through: the island spans the full
    // width of the screen but is only actually there in the middle.
    mask: Region {
        item: capsule
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

            interval: IslandTokens.hoverExpandDelay
            onTriggered: if (hover.hovered && !root.hasPanel)
                root.hoverExpanded = true
        }

        Timer {
            id: collapseTimer

            interval: IslandTokens.hoverCollapseDelay
            onTriggered: if (!hover.hovered)
                root.hoverExpanded = false
        }

        // Every layer fills the capsule and slides or fades itself. Tide does it
        // this way so that during a swipe the page arriving and the page leaving
        // are both mounted and both moving.
        ClockLayer {
            offset: root.pageOffset(IslandWindow.State.Normal)
            showCondition: root.isResting
            animated: !root.swiping
        }

        Loader {
            id: customLoader

            anchors.fill: parent
            active: root.canSwipe && (root.islandState === IslandWindow.State.Custom || root.swipeProgress < 0)
            visible: active

            sourceComponent: DatePreviewLayer {
                offset: root.pageOffset(IslandWindow.State.Custom)
                animated: !root.swiping
            }
        }

        Loader {
            id: lyricsLoader

            anchors.fill: parent
            active: root.canSwipe && (root.islandState === IslandWindow.State.Lyrics || root.swipeProgress > 0)
            visible: active

            sourceComponent: LyricsLayer {
                offset: root.pageOffset(IslandWindow.State.Lyrics)
                animated: !root.swiping
                maximumWidth: root.width - IslandTokens.swipeSideMargin
            }
        }

        Loader {
            anchors.fill: parent
            active: root.islandState === IslandWindow.State.Split
            visible: active

            sourceComponent: OsdLayer {
                kind: osd.kind
                value: osd.value
                muted: osd.muted
                hasLevel: osd.hasLevel
            }
        }

        Loader {
            anchors.fill: parent
            active: root.islandState === IslandWindow.State.Long
            visible: active

            sourceComponent: EventLayer {
                kind: events.kind
                icon: events.icon
                title: events.title
                detail: events.detail
            }
        }

        Loader {
            id: notifLoader

            anchors.fill: parent
            active: root.islandState === IslandWindow.State.Notification
            visible: active

            sourceComponent: NotificationLayer {
                notif: notifications.current
                maximumWidth: root.width - IslandTokens.swipeSideMargin
            }
        }

        Loader {
            anchors.fill: parent
            active: root.islandState === IslandWindow.State.Player
            visible: active

            sourceComponent: PlayerLayer {
                island: root
            }
        }

        Loader {
            id: calendarLoader

            anchors.fill: parent
            active: root.islandState === IslandWindow.State.Calendar
            visible: active

            sourceComponent: CalendarLayer {
                island: root
            }
        }

        Loader {
            id: performanceLoader

            anchors.fill: parent
            active: root.islandState === IslandWindow.State.Performance
            visible: active

            sourceComponent: PerformanceLayer {
                island: root
            }
        }

        Loader {
            anchors.fill: parent
            active: root.islandState === IslandWindow.State.Control
            visible: active

            sourceComponent: ControlLayer {
                island: root
                monitor: root.monitor
            }
        }
    }

    OsdWatcher {
        id: osd

        monitor: root.monitor
        blocked: root.hasPanel
    }

    EventWatcher {
        id: events

        blocked: root.hasPanel
    }

    NotificationQueue {
        id: notifications
    }
}
