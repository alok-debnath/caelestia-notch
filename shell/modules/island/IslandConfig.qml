pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// The island's settings.
//
// Caelestia's own Config comes from a C++ module, and this repo has no C++, so
// the island keeps its settings beside it in `~/.config/caelestia/island.json`
// and edits them from the same settings window (Panels -> Island). Written back
// whenever a value changes, which is what makes the settings page work without
// a save button.
Singleton {
    id: root

    // What hovering the notch opens.
    //
    // Auto is the useful one and the default: the player while something is
    // playing, so hovering whatever is on the media page gives you its
    // controls, and notification history the rest of the time.
    enum HoverAction {
        None,
        Player,
        Auto
    }

    // The island's typeface. Tide's own is Inter Display -- see IslandText for
    // why the island does not simply use the shell's.
    property alias fontFamily: adapter.fontFamily

    // What a click on the capsule opens, per button. Tide binds surfaces to
    // clicks rather than to a strip of tabs -- see IslandWindow.runAction for
    // the names.
    property alias clickAction: adapter.clickAction
    property alias rightClickAction: adapter.rightClickAction
    property alias middleClickAction: adapter.middleClickAction

    property alias hoverAction: adapter.hoverAction
    property alias hoverExpandDelay: adapter.hoverExpandDelay
    property alias hoverCollapseDelay: adapter.hoverCollapseDelay

    // What the left resting page shows, in order. Tide's own set of readings:
    // time, date, battery, volume, brightness, workspace, cpu, ram, storage,
    // cava. See StripItem for what each draws.
    property alias leftItems: adapter.leftItems

    // Applications pinned to the front of the launcher strip, in the order
    // they were starred. Desktop entry ids.
    property alias favourites: adapter.favourites

    // The overview's grid. Tide's map is a fixed block of cells -- workspace 4
    // is always in the same place -- and these are its dimensions.
    property alias overviewRows: adapter.overviewRows
    property alias overviewColumns: adapter.overviewColumns

    // Resting pages either side of the clock.
    property alias datePage: adapter.datePage
    property alias mediaPage: adapter.mediaPage

    // Follow the music: while something is playing, the media page becomes the
    // page the island rests on, and it goes back to the clock when it stops.
    property alias followPlayback: adapter.followPlayback
    property alias lyrics: adapter.lyrics
    property alias visualiser: adapter.visualiser

    // Which state changes are announced in the long capsule.
    property alias announceWorkspaces: adapter.announceWorkspaces
    property alias announceLockKeys: adapter.announceLockKeys
    property alias announcePower: adapter.announcePower
    property alias announceBluetooth: adapter.announceBluetooth
    property alias announceRecording: adapter.announceRecording
    property alias announceToggles: adapter.announceToggles
    property alias announceMedia: adapter.announceMedia

    property alias notifications: adapter.notifications
    property alias osd: adapter.osd

    // The Bluetooth announcement panel: a device connecting shows what it is,
    // its battery and the volume, for a couple of seconds.
    property alias bluetooth: adapter.bluetooth

    // The face-scan capsule. Off does not disable face unlock -- it only stops
    // the notch showing it.
    property alias faceId: adapter.faceId

    readonly property FileView storage: FileView {
        path: `${Paths.config}/island.json`

        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property string fontFamily: "Inter Display"

            property string clickAction: "player"
            property string rightClickAction: "overview"
            property string middleClickAction: "notifications"

            property int hoverAction: IslandConfig.HoverAction.Auto
            property int hoverExpandDelay: 350
            property int hoverCollapseDelay: 250

            property list<string> leftItems: ["date", "battery", "cava"]

            property list<string> favourites: []

            property int overviewRows: 2
            property int overviewColumns: 4

            property bool datePage: true
            property bool mediaPage: true
            property bool followPlayback: true
            property bool lyrics: true
            property bool visualiser: true

            property bool announceWorkspaces: true
            property bool announceLockKeys: true
            property bool announcePower: true
            property bool announceBluetooth: true
            property bool announceRecording: true
            property bool announceToggles: true
            property bool announceMedia: true

            property bool notifications: true
            property bool osd: true
            property bool bluetooth: true
            property bool faceId: true
        }
    }
}
