pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.Internal
import Caelestia.Services
import qs.components
import qs.services
import qs.utils

// One reading on the left resting page.
//
// Tide's left page is a configured list of these rather than a fixed widget --
// `time, date, battery, volume, brightness, workspace, cpu, ram, storage,
// cava` -- so the strip says whatever you actually want to glance at. This is
// that list's delegate: an id in, an icon and a figure out, with the two
// special cases (the battery cell and the level strip) drawing themselves.
//
// The services behind cpu/ram/storage are reference-counted in Caelestia, so
// each of those items holds its own ServiceRef: polling only happens while the
// item is on the strip.
Item {
    id: root

    required property string kind

    readonly property bool isCava: kind === "cava"
    readonly property bool isBattery: kind === "battery"

    readonly property string icon: {
        switch (kind) {
        case "volume":
            return Icons.getVolumeIcon(Audio.volume, Audio.muted);
        case "brightness":
            return "brightness_6";
        case "workspace":
            return "desktop_windows";
        case "cpu":
            return "memory";
        case "ram":
            return "memory_alt";
        case "storage":
            return "hard_drive_2";
        default:
            return "";
        }
    }

    readonly property string value: {
        switch (kind) {
        case "time":
            return Time.amPmStr ? `${Time.hourStr}:${Time.minuteStr} ${Time.amPmStr}` : `${Time.hourStr}:${Time.minuteStr}`;
        case "date":
            return Time.format("ddd, MMM dd");
        case "volume":
            return `${Math.round(Audio.volume * 100)}%`;
        case "brightness":
            return `${Math.round((Brightness.getMonitor("active")?.brightness ?? 0) * 100)}%`;
        case "workspace":
            return `${Hypr.activeWsId}`;
        case "cpu":
            return `${Math.round(Cpu.percentage * 100)}%`;
        case "ram":
            return `${Math.round((Memory.total > 0 ? Memory.used / Memory.total : 0) * 100)}%`;
        case "storage":
            return `${Math.round((Disk.total > 0 ? Disk.used / Disk.total : 0) * 100)}%`;
        default:
            return "";
        }
    }

    implicitWidth: isCava ? cava.implicitWidth : (isBattery ? pill.implicitWidth : row.implicitWidth)
    implicitHeight: IslandTokens.restingHeight

    CavaBars {
        id: cava

        anchors.centerIn: parent

        visible: root.isCava
        barCount: 5
    }

    BatteryPill {
        id: pill

        anchors.centerIn: parent

        visible: root.isBattery
    }

    Row {
        id: row

        anchors.centerIn: parent

        visible: !root.isCava && !root.isBattery
        spacing: IslandTokens.contentSpacing + 2

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter

            visible: root.icon.length > 0
            text: root.icon
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.small
            fill: 1
        }

        IslandRollText {
            anchors.verticalCenter: parent.verticalCenter

            text: root.value
        }
    }

    // Alive only while the item that needs it is on the strip: ServiceRef is
    // a reference, so pointing it at nothing is how an item that needs no
    // polling opts out.
    ServiceRef {
        service: {
            switch (root.kind) {
            case "cpu":
                return Cpu;
            case "ram":
                return Memory;
            case "storage":
                return Disk;
            default:
                return null;
            }
        }
    }
}
