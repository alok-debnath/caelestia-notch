pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Volume, microphone and brightness feedback: an icon, a percentage, and a ring
// showing the level.
Item {
    id: root

    required property int kind
    required property real value
    required property bool muted

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

    implicitWidth: layout.implicitWidth + IslandTokens.horizontalPadding * 2
    implicitHeight: layout.implicitHeight + IslandTokens.verticalPadding * 2

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: IslandTokens.contentSpacing

        MaterialIcon {
            text: root.icon
            color: Colours.palette.m3onSurface
            fontStyle: Tokens.font.icon.builders.medium.build()
        }

        StyledText {
            text: `${Math.round(root.value * 100)}%`
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurface
        }

        // A little breathing room before the ring, which reads as a separate
        // element rather than part of the label.
        Item {
            implicitWidth: IslandTokens.contentSpacing
        }

        ProgressRing {
            value: root.value
        }
    }
}
