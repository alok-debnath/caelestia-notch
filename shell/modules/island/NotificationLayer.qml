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
Item {
    id: root

    required property NotifData notif

    readonly property bool hasImage: (notif?.image.length ?? 0) > 0
    readonly property bool isCritical: notif?.urgency === NotificationUrgency.Critical

    implicitWidth: Math.min(IslandTokens.maxWidth, layout.implicitWidth + IslandTokens.horizontalPadding * 2)
    implicitHeight: layout.implicitHeight + IslandTokens.verticalPadding * 2

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: IslandTokens.contentSpacing * 2

        Loader {
            Layout.alignment: Qt.AlignVCenter

            asynchronous: true
            sourceComponent: root.hasImage ? imageIcon : appIcon
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true

                text: root.notif?.summary ?? ""
                font: Tokens.font.body.small
                color: root.isCritical ? Colours.palette.m3error : Colours.palette.m3onSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true

                text: root.notif?.body ?? ""
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
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
            implicitWidth: IslandTokens.iconSize * 2
            implicitHeight: IslandTokens.iconSize * 2
            radius: Tokens.rounding.full
            color: root.isCritical ? Colours.palette.m3error : Colours.palette.m3secondaryContainer

            Image {
                anchors.fill: parent

                source: Qt.resolvedUrl(root.notif?.image ?? "")
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: IslandTokens.iconSize * 2
                sourceSize.height: IslandTokens.iconSize * 2
                cache: false
                asynchronous: true
            }
        }
    }
}
