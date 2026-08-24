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
// to the capsule. What this file owns is *which layer is showing and how big the
// capsule therefore is* -- the shape follows the content, which is what makes the
// island read as one object that morphs rather than a set of popups.
StyledWindow {
    id: root

    // What the user has opened. Stays open until closed again.
    enum Expanded {
        None,
        Player,
        Calendar,
        Performance
    }

    // What is actually on screen. Transient states outrank the expanded one: a
    // notification or a volume change interrupts the calendar, then gives it
    // back.
    enum Layer {
        Clock,
        Player,
        Calendar,
        Performance,
        Osd,
        Notification
    }

    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(root.screen)

    // Mirrored by ContentWindow into the blob group.
    readonly property Item capsule: capsule

    property int expanded: IslandWindow.Expanded.None

    readonly property int layer: {
        if (notifications.current)
            return IslandWindow.Layer.Notification;
        if (osd.showing)
            return IslandWindow.Layer.Osd;

        switch (expanded) {
        case IslandWindow.Expanded.Player:
            return Players.active ? IslandWindow.Layer.Player : IslandWindow.Layer.Clock;
        case IslandWindow.Expanded.Calendar:
            return IslandWindow.Layer.Calendar;
        case IslandWindow.Expanded.Performance:
            return IslandWindow.Layer.Performance;
        default:
            return IslandWindow.Layer.Clock;
        }
    }

    readonly property bool isExpanded: layer !== IslandWindow.Layer.Clock

    function toggle(which: int): void {
        expanded = expanded === which ? IslandWindow.Expanded.None : which;
    }

    function close(): void {
        expanded = IslandWindow.Expanded.None;
    }

    name: "island"

    anchors.top: true
    anchors.left: true
    anchors.right: true

    // Tokens is screen-scoped via contentItem, so the window object itself must
    // not read it. A plain constant is enough for the slack below the capsule.
    implicitHeight: capsule.y + capsule.implicitHeight + IslandTokens.verticalPadding * 2

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
        // should be drawn with rather than painting one itself. At rest it is a
        // pill; expanded it takes the shell's panel rounding.
        readonly property real radius: root.isExpanded ? Tokens.rounding.large : height / 2

        anchors.horizontalCenter: parent.horizontalCenter

        y: 0
        implicitWidth: Math.max(IslandTokens.restingWidth, content.implicitWidth)
        implicitHeight: Math.max(IslandTokens.restingHeight, content.implicitHeight)
        width: implicitWidth
        height: implicitHeight
        clip: true

        // The morph. OutQuint over IslandTokens.morphDuration: quick to start,
        // with a long settle, which is what keeps the notch from reading as a
        // popup appearing.
        Behavior on implicitWidth {
            NumberAnimation {
                duration: IslandTokens.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        Behavior on implicitHeight {
            NumberAnimation {
                duration: IslandTokens.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        MouseArea {
            anchors.fill: parent

            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => {
                if (event.button === Qt.RightButton)
                    root.toggle(IslandWindow.Expanded.Performance);
                else
                    root.toggle(IslandWindow.Expanded.Calendar);
            }
        }

        Loader {
            id: content

            anchors.centerIn: parent

            sourceComponent: {
                switch (root.layer) {
                case IslandWindow.Layer.Notification:
                    return notificationLayer;
                case IslandWindow.Layer.Osd:
                    return osdLayer;
                case IslandWindow.Layer.Player:
                    return playerLayer;
                case IslandWindow.Layer.Calendar:
                    return calendarLayer;
                case IslandWindow.Layer.Performance:
                    return performanceLayer;
                default:
                    return clockLayer;
                }
            }

            // Cross-fade rather than cut: the capsule is still resizing
            // underneath, and a hard swap makes the morph read as a glitch.
            opacity: 0

            Component.onCompleted: opacity = 1

            onSourceComponentChanged: {
                opacity = 0;
                fadeIn.restart();
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: IslandTokens.contentFadeDuration
                    easing.type: Easing.OutQuad
                }
            }

            Timer {
                id: fadeIn

                interval: IslandTokens.contentFadeDuration
                onTriggered: content.opacity = 1
            }
        }
    }

    Component {
        id: clockLayer

        ClockLayer {}
    }

    Component {
        id: playerLayer

        PlayerLayer {}
    }

    Component {
        id: calendarLayer

        CalendarLayer {}
    }

    Component {
        id: performanceLayer

        PerformanceLayer {}
    }

    Component {
        id: osdLayer

        OsdLayer {
            kind: osd.kind
            value: osd.value
            muted: osd.muted
        }
    }

    Component {
        id: notificationLayer

        NotificationLayer {
            notif: notifications.current
        }
    }

    OsdWatcher {
        id: osd

        monitor: root.monitor
    }

    NotificationQueue {
        id: notifications
    }
}
