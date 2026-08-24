pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// A notification in the notch: the real app image or icon, urgency colouring,
// and the notification's own actions as buttons.
//
// All of that comes from NotifData, because Caelestia is the notification
// server and hands over the whole notification rather than a summary scraped
// off the session bus.
//
// The size is published rather than taken: the capsule asks this layer how wide
// and tall it wants to be and morphs to that, so the content lays out at its
// preferred width and never at whatever the capsule happens to be mid-morph.
SlidingLayer {
    id: root

    required property NotifData notif

    property real maximumWidth: IslandTokens.notifMinWidth

    readonly property bool hasImage: (notif?.image.length ?? 0) > 0
    readonly property bool isCritical: notif?.urgency === NotificationUrgency.Critical

    readonly property real preferredWidth: Math.max(IslandTokens.notifMinWidth, Math.min(maximumWidth, metrics.advanceWidth + IslandTokens.artSize + IslandTokens.horizontalPadding * 4))

    implicitWidth: preferredWidth
    implicitHeight: Math.max(IslandTokens.notifMinHeight, layout.implicitHeight + IslandTokens.verticalPadding * 2)

    readonly property TextMetrics metrics: TextMetrics {
        font: summary.font
        text: (root.notif?.summary ?? "") + " " + (root.notif?.body ?? "")
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent

        width: root.preferredWidth - IslandTokens.horizontalPadding * 2
        spacing: IslandTokens.contentSpacing * 2

        Loader {
            Layout.alignment: Qt.AlignVCenter

            asynchronous: true
            sourceComponent: root.hasImage ? imageIcon : appIcon
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            IslandText {
                id: summary

                Layout.fillWidth: true

                text: root.notif?.summary ?? ""
                color: root.isCritical ? Colours.palette.m3error : Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            IslandText {
                Layout.fillWidth: true

                dim: true
                text: root.notif?.body ?? ""
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                visible: text.length > 0
            }

            RowLayout {
                Layout.topMargin: repeater.count > 0 ? Tokens.spacing.extraSmall : 0
                spacing: IslandTokens.contentSpacing
                visible: repeater.count > 0

                Repeater {
                    id: repeater

                    model: root.notif?.actions ?? []

                    TextButton {
                        required property var modelData

                        isRound: true
                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }

    Component {
        id: appIcon

        MaterialIcon {
            text: Icons.getNotifIcon(root.notif?.summary ?? "", root.notif?.urgency ?? NotificationUrgency.Normal)
            color: root.isCritical ? Colours.palette.m3error : Colours.palette.m3primary
            fontStyle: Tokens.font.icon.builders.medium.build()
        }
    }

    Component {
        id: imageIcon

        StyledClippingRect {
            implicitWidth: IslandTokens.smallArtSize
            implicitHeight: IslandTokens.smallArtSize
            radius: Tokens.rounding.full
            color: root.isCritical ? Colours.palette.m3error : Colours.palette.m3secondaryContainer

            Image {
                anchors.fill: parent

                source: Qt.resolvedUrl(root.notif?.image ?? "")
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: IslandTokens.artSize
                sourceSize.height: IslandTokens.artSize
                cache: false
                asynchronous: true
            }
        }
    }
}
