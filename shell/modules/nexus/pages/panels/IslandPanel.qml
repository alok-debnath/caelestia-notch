import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.modules.island
import qs.modules.nexus.common

// Settings for the notch.
//
// These live in `~/.config/caelestia/island.json` rather than in Caelestia's
// own config: Config comes from a C++ module and this shell has no C++, so the
// island keeps its own file and edits it from here. Everything writes straight
// through -- there is no save button anywhere else in this window either.
PageBase {
    id: root

    // Every surface a click can be bound to, in the order they appear in the
    // menu. `actionIds` is the parallel list of what goes in the config file --
    // see IslandWindow.runAction.
    readonly property list<string> actionIds: ["none", "player", "overview", "notifications", "performance", "wallpapers", "shelf", "clipboard", "timer", "search", "close"]

    readonly property list<MenuItem> actionItems: [
        MenuItem {
            text: qsTr("Nothing")
            icon: "block"
        },
        MenuItem {
            text: qsTr("Now playing")
            icon: "music_note"
        },
        MenuItem {
            text: qsTr("Workspaces")
            icon: "grid_view"
        },
        MenuItem {
            text: qsTr("Notifications")
            icon: "inbox"
        },
        MenuItem {
            text: qsTr("System")
            icon: "monitoring"
        },
        MenuItem {
            text: qsTr("Wallpapers")
            icon: "wallpaper"
        },
        MenuItem {
            text: qsTr("File shelf")
            icon: "attach_file"
        },
        MenuItem {
            text: qsTr("Clipboard")
            icon: "content_paste"
        },
        MenuItem {
            text: qsTr("Timer")
            icon: "timer"
        },
        MenuItem {
            text: qsTr("Search")
            icon: "search"
        },
        MenuItem {
            text: qsTr("Close")
            icon: "close"
        }
    ]

    // The readings the left resting page can carry, and what to call them.
    readonly property list<string> stripIds: ["time", "date", "battery", "volume", "brightness", "workspace", "cpu", "ram", "storage", "cava"]
    readonly property list<string> stripLabels: [qsTr("Time"), qsTr("Date"), qsTr("Battery"), qsTr("Volume"), qsTr("Brightness"), qsTr("Workspace"), qsTr("CPU"), qsTr("Memory"), qsTr("Disk"), qsTr("Visualiser")]

    function itemFor(action: string): MenuItem {
        const index = root.actionIds.indexOf(action);
        return root.actionItems[index < 0 ? 0 : index];
    }

    // Kept in the canonical order above rather than in the order they were
    // ticked, so the strip reads the same whichever way it was built.
    function setStripItem(id: string, on: bool): void {
        const wanted = root.stripIds.filter(candidate => candidate === id ? on : IslandConfig.leftItems.includes(candidate));
        IslandConfig.leftItems = wanted;
    }

    readonly property list<MenuItem> hoverItems: [
        MenuItem {
            text: qsTr("Nothing")
            icon: "block"
        },
        MenuItem {
            text: qsTr("Now playing")
            icon: "music_note"
        },
        MenuItem {
            text: qsTr("Whichever fits")
            icon: "auto_awesome"
        }
    ]

    title: qsTr("Island")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Clicks")
        }

        SelectRow {
            first: true
            label: qsTr("Click opens")
            menuItems: root.actionItems
            active: root.itemFor(IslandConfig.clickAction)
            onSelected: item => IslandConfig.clickAction = root.actionIds[root.actionItems.indexOf(item)]
        }

        SelectRow {
            label: qsTr("Right click opens")
            menuItems: root.actionItems
            active: root.itemFor(IslandConfig.rightClickAction)
            onSelected: item => IslandConfig.rightClickAction = root.actionIds[root.actionItems.indexOf(item)]
        }

        SelectRow {
            last: true
            label: qsTr("Middle click opens")
            subtext: qsTr("The island has no tab strip: a click is how you pick a surface")
            menuItems: root.actionItems
            active: root.itemFor(IslandConfig.middleClickAction)
            onSelected: item => IslandConfig.middleClickAction = root.actionIds[root.actionItems.indexOf(item)]
        }

        SectionHeader {
            text: qsTr("Hover")
        }

        SelectRow {
            first: true
            label: qsTr("Hovering opens")
            subtext: qsTr("\"Whichever fits\" opens now playing while something is playing")
            menuItems: root.hoverItems
            active: root.hoverItems[IslandConfig.hoverAction]
            onSelected: item => IslandConfig.hoverAction = root.hoverItems.indexOf(item)
        }

        StepperRow {
            label: qsTr("Open after")
            subtext: qsTr("Milliseconds the pointer must rest on the notch")
            value: IslandConfig.hoverExpandDelay
            from: 0
            to: 1500
            stepSize: 50
            onMoved: v => IslandConfig.hoverExpandDelay = v
        }

        StepperRow {
            last: true
            label: qsTr("Close after")
            subtext: qsTr("Milliseconds before it closes again when the pointer leaves")
            value: IslandConfig.hoverCollapseDelay
            from: 0
            to: 1500
            stepSize: 50
            onMoved: v => IslandConfig.hoverCollapseDelay = v
        }

        SectionHeader {
            text: qsTr("Left page")
        }

        Repeater {
            model: root.stripIds

            ToggleRow {
                required property string modelData
                required property int index

                first: index === 0
                last: index === root.stripIds.length - 1
                text: root.stripLabels[index]
                checked: IslandConfig.leftItems.includes(modelData)
                onToggled: root.setStripItem(modelData, checked)
            }
        }

        SectionHeader {
            text: qsTr("Overview")
        }

        StepperRow {
            first: true
            label: qsTr("Rows")
            subtext: qsTr("The overview is a fixed map, so a workspace is always in the same place")
            value: IslandConfig.overviewRows
            from: 1
            to: 4
            stepSize: 1
            onMoved: v => IslandConfig.overviewRows = v
        }

        StepperRow {
            last: true
            label: qsTr("Columns")
            value: IslandConfig.overviewColumns
            from: 2
            to: 8
            stepSize: 1
            onMoved: v => IslandConfig.overviewColumns = v
        }

        SectionHeader {
            text: qsTr("Type")
        }

        TextFieldRow {
            first: true
            last: true
            label: qsTr("Typeface")
            subtext: qsTr("The island is set in Tide's own face, not the shell's")
            value: IslandConfig.fontFamily
            placeholderText: "Inter Display"
            onEditingFinished: value => IslandConfig.fontFamily = value.length > 0 ? value : "Inter Display"
        }

        SectionHeader {
            text: qsTr("Resting pages")
        }

        ToggleRow {
            first: true
            text: qsTr("Date page")
            subtext: qsTr("Swipe left from the clock for the date")
            checked: IslandConfig.datePage
            onToggled: IslandConfig.datePage = checked
        }

        ToggleRow {
            text: qsTr("Media page")
            subtext: qsTr("Swipe right for the cover, the line playing and the visualiser")
            checked: IslandConfig.mediaPage
            onToggled: IslandConfig.mediaPage = checked
        }

        ToggleRow {
            text: qsTr("Follow playback")
            subtext: qsTr("Rest on the media page while something is playing")
            checked: IslandConfig.followPlayback
            onToggled: IslandConfig.followPlayback = checked
        }

        ToggleRow {
            text: qsTr("Lyrics")
            subtext: qsTr("Needs lyricsmpris; falls back to the track title")
            checked: IslandConfig.lyrics
            onToggled: IslandConfig.lyrics = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Visualiser")
            subtext: qsTr("Cava bars beside the track")
            checked: IslandConfig.visualiser
            onToggled: IslandConfig.visualiser = checked
        }

        SectionHeader {
            text: qsTr("Interruptions")
        }

        ToggleRow {
            first: true
            text: qsTr("Notifications")
            subtext: qsTr("Show notifications in the notch")
            checked: IslandConfig.notifications
            onToggled: IslandConfig.notifications = checked
        }

        ToggleRow {
            text: qsTr("Volume and brightness")
            subtext: qsTr("Show levels in the notch")
            checked: IslandConfig.osd
            onToggled: IslandConfig.osd = checked
        }

        ToggleRow {
            text: qsTr("Face unlock")
            subtext: qsTr("Show biopass face scans in the notch")
            checked: IslandConfig.faceId
            onToggled: IslandConfig.faceId = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Bluetooth connections")
            subtext: qsTr("Announce a device with its battery and volume")
            checked: IslandConfig.bluetooth
            onToggled: IslandConfig.bluetooth = checked
        }

        SectionHeader {
            text: qsTr("Announcements")
        }

        ToggleRow {
            first: true
            text: qsTr("Workspaces")
            checked: IslandConfig.announceWorkspaces
            onToggled: IslandConfig.announceWorkspaces = checked
        }

        ToggleRow {
            text: qsTr("Lock keys")
            checked: IslandConfig.announceLockKeys
            onToggled: IslandConfig.announceLockKeys = checked
        }

        ToggleRow {
            text: qsTr("Power")
            subtext: qsTr("Charger connected and disconnected")
            checked: IslandConfig.announcePower
            onToggled: IslandConfig.announcePower = checked
        }

        ToggleRow {
            text: qsTr("Bluetooth")
            subtext: qsTr("Devices connecting and disconnecting")
            checked: IslandConfig.announceBluetooth
            onToggled: IslandConfig.announceBluetooth = checked
        }

        ToggleRow {
            text: qsTr("Recording")
            checked: IslandConfig.announceRecording
            onToggled: IslandConfig.announceRecording = checked
        }

        ToggleRow {
            text: qsTr("Toggles")
            subtext: qsTr("Do not disturb, game mode, keep awake")
            checked: IslandConfig.announceToggles
            onToggled: IslandConfig.announceToggles = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Track changes")
            checked: IslandConfig.announceMedia
            onToggled: IslandConfig.announceMedia = checked
        }
    }
}
