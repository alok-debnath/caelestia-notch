pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// A notification in the notch, at Tide's exact metrics and with Tide's exact
// behaviour.
//
// Tide treats a notification as *one line of text* until you ask for more:
// summary and body run together into a single string, drawn on one line at
// 272-400 wide; a string that would wrap gets two lines in a 68px capsule; and
// only a string that overflows even that is expandable -- click it and the
// capsule goes to 520 wide and up to 240 tall with the whole thing scrollable
// inside, and the auto-hide stops until you dismiss it.
//
// The three probes below are how that decision is made, and they are Tide's:
// a TextMetrics for the unwrapped width, and two off-screen Texts laid out at
// the compact and expanded text-block widths to count the lines each would
// take. Measuring rather than guessing is the whole reason the capsule never
// resizes twice for one notification.
//
// What is *not* Tide's: the image, the app icon, the urgency colour and the
// action buttons. Caelestia is the notification server here, so the island has
// the real NotifData rather than three strings scraped off the bus -- the
// actions appear in the expanded state, where there is room for them.
SlidingLayer {
    id: root

    required property NotifData notif

    property real maximumWidth: IslandTokens.notifMaxWidth
    property bool expanded: false

    signal expansionToggled

    readonly property bool hasImage: (notif?.image.length ?? 0) > 0
    readonly property bool isCritical: notif?.urgency === NotificationUrgency.Critical

    // Tide runs the two together with a double space, so the summary reads as
    // the lead of one sentence rather than as a heading over a paragraph.
    readonly property string contentText: {
        const summary = notif?.summary ?? "";
        const body = notif?.body ?? "";
        if (summary && body && body !== summary)
            return `${summary}  ${body}`;
        if (summary)
            return summary;
        if (body)
            return body;
        return qsTr("New notification");
    }

    readonly property real iconSlotWidth: IslandTokens.smallArtSize
    readonly property real contentSpacing: 13
    readonly property real horizontalPadding: 16
    readonly property real compactVerticalPadding: 7
    readonly property real expandedVerticalPadding: 13

    readonly property real compactMaximumWidth: Math.min(maximumWidth, IslandTokens.notifCompactWidth)
    readonly property real expandedMaximumWidth: Math.min(maximumWidth, IslandTokens.notifExpandedWidth)

    readonly property bool showExpanded: expanded && hasOverflowContent

    readonly property real verticalPadding: showExpanded ? expandedVerticalPadding : compactVerticalPadding
    readonly property real compactMaximumContentHeight: 68 - compactVerticalPadding * 2
    readonly property real expandedMaximumContentHeight: IslandTokens.notifExpandedHeight - expandedVerticalPadding * 2

    readonly property real textBlockWidthAtMaximum: compactMaximumWidth - horizontalPadding * 2 - iconSlotWidth - contentSpacing
    readonly property real expandedTextBlockWidthAtMaximum: expandedMaximumWidth - horizontalPadding * 2 - iconSlotWidth - contentSpacing

    readonly property bool prefersWrappedContent: metrics.advanceWidth > textBlockWidthAtMaximum

    // Expandable when there is genuinely more than the compact capsule can
    // show: more than two lines, more than twice the line width, or a single
    // unbroken line too long for one.
    readonly property bool hasOverflowContent: compactProbe.lineCount > 2 || metrics.advanceWidth > textBlockWidthAtMaximum * 2 || (metrics.advanceWidth > textBlockWidthAtMaximum && compactProbe.lineCount <= 1)

    readonly property real compactPreferredWidth: prefersWrappedContent ? compactMaximumWidth : Math.max(IslandTokens.notifMinWidth, Math.min(compactMaximumWidth, metrics.advanceWidth + iconSlotWidth + contentSpacing + horizontalPadding * 2))
    readonly property real compactPreferredHeight: prefersWrappedContent ? compactMaximumContentHeight + compactVerticalPadding * 2 : IslandTokens.notifMinHeight

    readonly property real expandedPreferredHeight: Math.max(84, Math.min(IslandTokens.notifExpandedHeight, Math.min(expandedMaximumContentHeight, expandedProbe.implicitHeight + (actions.count > 0 ? actionRow.implicitHeight + Tokens.spacing.small : 0)) + expandedVerticalPadding * 2))

    readonly property real preferredWidth: showExpanded ? expandedMaximumWidth : compactPreferredWidth
    readonly property real preferredHeight: showExpanded ? expandedPreferredHeight : compactPreferredHeight

    implicitWidth: preferredWidth
    implicitHeight: preferredHeight

    // -- Tide's three probes ---------------------------------------------
    readonly property TextMetrics metrics: TextMetrics {
        font: compactProbe.font
        text: root.contentText
    }

    Text {
        id: compactProbe

        x: -10000
        y: -10000

        width: root.textBlockWidthAtMaximum
        height: 0
        opacity: 0
        text: root.contentText
        font.family: IslandConfig.fontFamily
        font.pixelSize: IslandTokens.bodyPixelSize
        font.weight: Font.DemiBold
        font.letterSpacing: IslandTokens.bodyLetterSpacing
        wrapMode: Text.WordWrap
        lineHeight: 0.95
    }

    Text {
        id: expandedProbe

        x: -10000
        y: -10000

        width: root.expandedTextBlockWidthAtMaximum
        height: 0
        opacity: 0
        text: root.contentText
        font: compactProbe.font
        wrapMode: Text.WordWrap
        lineHeight: 1.05
    }

    // -- The capsule's content -------------------------------------------
    Item {
        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.topMargin: root.verticalPadding
        anchors.bottomMargin: root.verticalPadding

        Loader {
            id: icon

            anchors.left: parent.left
            anchors.top: root.showExpanded ? parent.top : undefined
            anchors.verticalCenter: root.showExpanded ? undefined : parent.verticalCenter

            width: root.iconSlotWidth

            asynchronous: true
            sourceComponent: root.hasImage ? imageIcon : appIcon
        }

        Item {
            anchors.left: icon.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: root.contentSpacing

            // Compact: one line, or two when the string is long enough to want
            // wrapping. Tide's 0.95 line height, which is what lets two lines
            // sit in a capsule this shallow without looking stacked.
            IslandText {
                anchors.verticalCenter: parent.verticalCenter

                visible: !root.showExpanded
                width: parent.width
                text: root.contentText
                color: root.isCritical ? Colours.palette.m3error : Colours.palette.m3onSurface
                wrapMode: root.prefersWrappedContent ? Text.WordWrap : Text.NoWrap
                maximumLineCount: root.prefersWrappedContent ? 2 : 1
                elide: Text.ElideRight
                lineHeight: 0.95
            }

            // Expanded: the whole thing, scrollable, with the actions under it.
            ColumnLayout {
                anchors.fill: parent

                visible: root.showExpanded
                spacing: Tokens.spacing.small

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: full.implicitHeight
                    interactive: contentHeight > height

                    IslandText {
                        id: full

                        width: parent.width
                        text: root.contentText
                        color: root.isCritical ? Colours.palette.m3error : Colours.palette.m3onSurface
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        lineHeight: 1.05
                    }
                }

                RowLayout {
                    id: actionRow

                    Layout.alignment: Qt.AlignRight

                    spacing: IslandTokens.contentSpacing
                    visible: actions.count > 0

                    Repeater {
                        id: actions

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
    }

    // Click to expand, exactly where Tide has it: only when there is something
    // hidden, and only on the notification itself.
    TapHandler {
        enabled: root.hasOverflowContent
        onTapped: root.expansionToggled()
    }

    Component {
        id: appIcon

        MaterialIcon {
            text: Icons.getNotifIcon(root.notif?.summary ?? "", root.notif?.urgency ?? NotificationUrgency.Normal)
            color: root.isCritical ? Colours.palette.m3error : Colours.palette.m3primary
            fontStyle: Tokens.font.icon.builders.medium.build()
            horizontalAlignment: Text.AlignHCenter
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
