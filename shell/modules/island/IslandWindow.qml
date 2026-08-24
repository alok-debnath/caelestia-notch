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

    // Highest priority wins. Everything except Player is transient and returns
    // to Clock on its own.
    enum Layer {
        Clock,
        Player,
        Osd,
        Notification
    }

    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(root.screen)

    // Mirrored by ContentWindow into the blob group.
    readonly property Item capsule: capsule

    // Player is the only layer the user opens and closes explicitly.
    property bool playerOpen

    readonly property int layer: {
        if (notifications.current)
            return IslandWindow.Layer.Notification;
        if (osd.showing)
            return IslandWindow.Layer.Osd;
        if (playerOpen && Players.active)
            return IslandWindow.Layer.Player;
        return IslandWindow.Layer.Clock;
    }

    function togglePlayer(): void {
        playerOpen = !playerOpen && !!Players.active;
    }

    name: "island"

    anchors.top: true
    anchors.left: true
    anchors.right: true

    // Tokens is screen-scoped via contentItem, so the window object itself must
    // not read it. A plain constant is enough for the slack below the capsule.
    implicitHeight: capsule.y + capsule.implicitHeight + IslandTokens.verticalPadding * 2

    // Reserve only the resting height, so windows do not jump every time the
    // island expands for a notification.
    exclusiveZone: IslandTokens.restingHeight

    // Everything outside the capsule is click-through: the island covers the
    // full width of the screen but is only actually there in the middle.
    mask: Region {
        item: capsule
    }

    Item {
        id: capsule

        // The blob is a rounded rect, so the capsule exposes the radius it
        // should be drawn with rather than painting one itself.
        readonly property real radius: root.layer === IslandWindow.Layer.Clock ? height / 2 : Tokens.rounding.large

        anchors.horizontalCenter: parent.horizontalCenter

        y: 0
        implicitWidth: Math.max(IslandTokens.restingWidth, content.implicitWidth)
        implicitHeight: Math.max(IslandTokens.restingHeight, content.implicitHeight)
        width: implicitWidth
        height: implicitHeight
        clip: true

        Behavior on implicitWidth {
            Anim {
                type: Anim.EmphasizedLarge
            }
        }

        Behavior on implicitHeight {
            Anim {
                type: Anim.EmphasizedLarge
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
                Anim {
                    type: Anim.FastEffects
                }
            }

            Timer {
                id: fadeIn

                interval: Tokens.anim.durations.small
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
