pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls

// The island's only buttons.
//
// The capsule itself is not clickable: hovering opens the player, and the other
// views are opened from here. That way passing over the notch never toggles
// anything, and a view that is open stays open until the same button closes it.
RowLayout {
    id: root

    required property var island

    spacing: 0

    IconButton {
        icon: "calendar_month"
        type: IconButton.Text
        isToggle: true
        checked: root.island.panel === IslandWindow.State.Calendar
        onClicked: root.island.openPanel(IslandWindow.State.Calendar)
    }

    IconButton {
        icon: "monitoring"
        type: IconButton.Text
        isToggle: true
        checked: root.island.panel === IslandWindow.State.Performance
        onClicked: root.island.openPanel(IslandWindow.State.Performance)
    }

    IconButton {
        icon: "inbox"
        type: IconButton.Text
        isToggle: true
        checked: root.island.panel === IslandWindow.State.NotifCenter
        onClicked: root.island.openPanel(IslandWindow.State.NotifCenter)
    }

    IconButton {
        icon: "tune"
        type: IconButton.Text
        isToggle: true
        checked: root.island.panel === IslandWindow.State.Control
        onClicked: root.island.openPanel(IslandWindow.State.Control)
    }
}
