import QtQuick
import qs.components

Item {
    id: root

    required property ScreenState screenState
    required property Item sidebarPanel
    property alias osdPanel: content.osdPanel
    property alias sessionPanel: content.sessionPanel
    property alias utilitiesPanel: content.utilitiesPanel

    // The island renders notification popups. This panel stays mounted because
    // Panels, Regions, ContentWindow and the sidebar all anchor against its
    // geometry; only its height is pinned to zero. Notification history in the
    // sidebar is unaffected -- it reads Notifs directly.
    readonly property bool popupsEnabled: false

    visible: popupsEnabled && height > 0
    anchors.topMargin: -5
    implicitWidth: Math.max(sidebarPanel.width, content.implicitWidth)
    implicitHeight: popupsEnabled ? content.implicitHeight : 0

    Content {
        id: content

        anchors.topMargin: -root.anchors.topMargin
        screenState: root.screenState
    }
}
