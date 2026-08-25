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
            last: true
            text: qsTr("Face unlock")
            subtext: qsTr("Show biopass face scans in the notch")
            checked: IslandConfig.faceId
            onToggled: IslandConfig.faceId = checked
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
