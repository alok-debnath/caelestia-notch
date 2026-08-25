pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Volume, microphone and brightness: Tide's split layout -- the icon and the
// figure held left, the ring held right, with the capsule stretched between
// them. Anything without a level (a mute, a lock key) is the icon alone in a
// resting-width capsule.
SlidingLayer {
    id: root

    required property int kind
    required property real value
    required property bool muted
    required property bool hasLevel

    readonly property string icon: {
        switch (kind) {
        case OsdWatcher.Kind.Microphone:
            return Icons.getMicVolumeIcon(value, muted);
        case OsdWatcher.Kind.Brightness:
            return `brightness_${Math.round(value * 6) + 1}`;
        default:
            return Icons.getVolumeIcon(value, muted);
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: IslandTokens.horizontalPadding * 1.125
        anchors.verticalCenter: parent.verticalCenter
        spacing: IslandTokens.contentSpacing * 2
        visible: root.hasLevel

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter

            text: root.icon
            color: Colours.palette.m3onSurface
            fontStyle: Tokens.font.icon.builders.medium.build()
        }

        // The figure rolls rather than snapping: holding a volume key steps it
        // several times a second, and a number that cuts is the one part of the
        // OSD that reads as a redraw instead of as a level moving.
        IslandRollText {
            anchors.verticalCenter: parent.verticalCenter

            hero: true
            text: `${Math.round(root.value * 100)}%`
        }
    }

    ProgressRing {
        anchors.right: parent.right
        anchors.rightMargin: IslandTokens.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter

        value: root.value
        visible: root.hasLevel
    }

    MaterialIcon {
        anchors.centerIn: parent

        text: root.icon
        color: Colours.palette.m3onSurface
        fontStyle: Tokens.font.icon.builders.medium.build()
        visible: !root.hasLevel
    }
}
