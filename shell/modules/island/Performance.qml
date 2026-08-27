pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Internal
import Caelestia.Services
import Quickshell.Services.UPower
import qs.components
import qs.components.misc
import qs.services

// System resources as a grid of cards.
//
// Same numbers the dashboard's cards showed -- usage, temperature, used of
// total, transfer rates, session totals, charge and time left -- two to a row
// instead of one row each: a full-width row per reading ran the panel down
// most of the notch's height for very little read per pixel. Each reading's
// value now lives in a ring, the same `ProgressRing` canvas the timer and the
// volume/brightness levels already draw with -- one gauge language for the
// whole island instead of a flat bar unique to this panel.
//
// Which cards exist is still Config.dashboard.performance.*, provided by
// Caelestia.Config in C++ and outliving the drawer it was named after.
GridLayout {
    id: root

    columns: 2
    columnSpacing: Tokens.spacing.small
    rowSpacing: Tokens.spacing.small

    readonly property bool hasGpu: Config.dashboard.performance.showGpu && Gpu.type !== Gpu.None
    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery
    readonly property bool empty: !Config.dashboard.performance.showCpu && !hasGpu && !Config.dashboard.performance.showMemory && !Config.dashboard.performance.showStorage && !Config.dashboard.performance.showNetwork && !hasBattery

    function formatTemp(t: real): string {
        const f = GlobalConfig.services.useFahrenheitPerformance;
        return `${Math.ceil(f ? t * 1.8 + 32 : t)}°${f ? "F" : "C"}`;
    }

    StyledText {
        Layout.columnSpan: 2
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.small
        Layout.bottomMargin: Tokens.spacing.small

        text: qsTr("No widgets enabled")
        font: Tokens.font.body.medium
        color: Colours.palette.m3onSurfaceVariant
        visible: root.empty
    }

    // CPU
    StatCard {
        visible: Config.dashboard.performance.showCpu
        icon: "memory"
        label: qsTr("CPU")
        sub: Cpu.name
        accent: Colours.palette.m3primary
        value: Cpu.percentage
        detail: `${Math.round(Cpu.percentage * 100)}%`
        extra: root.formatTemp(Cpu.temperature)
        extraAlert: Cpu.temperature > 90

        ServiceRef {
            service: Cpu
        }
    }

    // GPU
    StatCard {
        visible: root.hasGpu
        icon: "desktop_windows"
        label: qsTr("GPU")
        sub: Gpu.name
        accent: Colours.palette.m3secondary
        value: Gpu.percentage
        detail: `${Math.round(Gpu.percentage * 100)}%`
        extra: root.formatTemp(Gpu.temperature)
        extraAlert: Gpu.temperature > 90

        ServiceRef {
            service: Gpu
        }
    }

    // Memory
    StatCard {
        visible: Config.dashboard.performance.showMemory
        icon: "memory_alt"
        label: qsTr("Memory")
        sub: {
            const fmt = UsageFmt.formatKib(Memory.used, Memory.total);
            return `${+fmt.value.toFixed(1)} / ${+fmt.total.toFixed(1)} ${fmt.unit}`;
        }
        accent: Colours.palette.m3tertiary
        value: Memory.percentage
        detail: `${Math.round(Memory.percentage * 100)}%`

        ServiceRef {
            service: Memory
        }
    }

    // Storage. Clicking the row cycles the primary disk, which is what the
    // dashboard's disk menu did.
    StatCard {
        readonly property var disk: Storage.primaryDisk

        visible: Config.dashboard.performance.showStorage
        icon: "hard_drive"
        label: qsTr("Storage")
        sub: {
            if (!disk)
                return qsTr("No disks detected");
            const fmt = UsageFmt.formatKib(disk.used, disk.total);
            return `${disk.mount}  ·  ${+fmt.value.toFixed(1)} / ${+fmt.total.toFixed(1)} ${fmt.unit}`;
        }
        accent: Colours.palette.m3secondary
        value: disk?.perc ?? 0
        detail: `${Math.round((disk?.perc ?? 0) * 100)}%`
        interactive: Storage.disks.length > 1
        onClicked: {
            const disks = Storage.disks;
            if (disks.length < 2)
                return;
            const next = (disks.indexOf(Storage.primaryDisk) + 1) % disks.length;
            Storage.manualPrimaryDisk = disks[next];
        }

        ServiceRef {
            service: Storage
        }
    }

    // Battery
    StatCard {
        readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state)

        visible: root.hasBattery
        icon: charging ? "bolt" : "battery_full"
        label: qsTr("Battery")
        sub: {
            const dev = UPower.displayDevice;
            if (dev.state === UPowerDeviceState.FullyCharged)
                return qsTr("Full");
            if (charging)
                return qsTr("Charging");

            const s = dev.timeToEmpty;
            if (s === 0)
                return qsTr("Estimating…");

            const hr = Math.floor(s / 3600);
            const min = Math.floor((s % 3600) / 60);
            return hr > 0 ? qsTr("%1h %2m left").arg(hr).arg(min) : qsTr("%1m left").arg(min);
        }
        accent: UPower.displayDevice.percentage <= 0.15 && !charging ? Colours.palette.m3error : Colours.palette.m3primary
        value: UPower.displayDevice.percentage
        detail: `${Math.round(UPower.displayDevice.percentage * 100)}%`
    }

    // Network. Full-width rather than one of the pair: two speeds and a
    // session total don't fit the other cards' single-number shape, and the
    // sparkline reads better wide than squeezed into a half card.
    NetworkCard {
        visible: Config.dashboard.performance.showNetwork

        Ref {
            service: NetworkUsage
        }
    }

    // A metric's identity: an icon, tinted to the metric's accent, sitting in
    // a ring. `ring >= 0` sweeps the same `ProgressRing` canvas the timer and
    // the volume/brightness levels use, so a reading with a share to show
    // (CPU, memory, a disk, the battery) fills it; `ring < 0` -- network has
    // a rate, not a share -- leaves it a plain tinted disc instead.
    component IconBadge: Item {
        id: badge

        property string icon
        property color tint: Colours.palette.m3primary
        property real ring: -1

        implicitWidth: 40
        implicitHeight: 40

        StyledRect {
            anchors.fill: parent
            visible: badge.ring < 0
            radius: width / 2
            color: Qt.alpha(badge.tint, 0.16)
        }

        ProgressRing {
            anchors.fill: parent
            visible: badge.ring >= 0
            value: badge.ring
            trackColour: Qt.alpha(badge.tint, 0.16)
            fillColour: badge.tint
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: badge.icon
            color: badge.tint
            fontStyle: Tokens.font.icon.small
            fill: 1
        }
    }

    // Network: two speeds and a session total, plus the sparkline, given the
    // full row width instead of squeezed into half a card -- neither speed
    // outranks the other, so both read at the same size and weight rather
    // than one being the "big" number.
    component NetworkCard: StyledRect {
        id: card

        Layout.fillWidth: true
        Layout.columnSpan: 2

        implicitHeight: content.implicitHeight + Tokens.padding.medium * 2
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large

        RowLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            IconBadge {
                Layout.alignment: Qt.AlignVCenter
                icon: "swap_vert"
                tint: Colours.palette.m3primary
            }

            ColumnLayout {
                id: info

                spacing: Tokens.spacing.extraSmall / 2

                StyledText {
                    text: qsTr("Network")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                RowLayout {
                    spacing: Tokens.spacing.medium

                    StyledText {
                        text: {
                            const fmt = NetworkUsage.formatBytes(NetworkUsage.downloadSpeed ?? 0);
                            return `↓ ${fmt ? `${fmt.value.toFixed(1)} ${fmt.unit}` : "0.0 B/s"}`;
                        }
                        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: {
                            const fmt = NetworkUsage.formatBytes(NetworkUsage.uploadSpeed ?? 0);
                            return `↑ ${fmt ? `${fmt.value.toFixed(1)} ${fmt.unit}` : "0.0 B/s"}`;
                        }
                        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                        color: Colours.palette.m3onSurface
                    }
                }

                StyledText {
                    Layout.topMargin: Tokens.spacing.extraSmall / 2

                    text: {
                        const down = NetworkUsage.formatBytesTotal(NetworkUsage.downloadTotal ?? 0);
                        const up = NetworkUsage.formatBytesTotal(NetworkUsage.uploadTotal ?? 0);
                        return (down && up) ? qsTr("Session ↓%1%2 ↑%3%4").arg(down.value.toFixed(1)).arg(down.unit).arg(up.value.toFixed(1)).arg(up.unit) : "";
                    }
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }

            SparklineItem {
                id: spark

                property real smoothMax: 1024

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: Tokens.padding.large

                line1: NetworkUsage.uploadBuffer // qmllint disable missing-type
                line1Color: Colours.palette.m3secondary
                line1FillAlpha: 0.15
                line2: NetworkUsage.downloadBuffer // qmllint disable missing-type
                line2Color: Colours.palette.m3primary
                line2FillAlpha: 0.2
                maxValue: smoothMax
                historyLength: NetworkUsage.historyLength

                Connections {
                    function onValuesChanged(): void {
                        spark.smoothMax = Math.max(NetworkUsage.downloadBuffer.maximum, NetworkUsage.uploadBuffer.maximum, 1024);
                    }

                    target: NetworkUsage.downloadBuffer
                }

                Behavior on smoothMax {
                    Anim {}
                }
            }
        }
    }

    // One reading: a ring for the share it holds, the number, and what it's
    // of. Laid out around the ring rather than stacked above a bar, so the
    // value the ring carries is never drawn twice.
    component StatCard: StyledRect {
        id: card

        property string icon
        property string label
        property string sub
        property string detail
        property string extra
        property bool extraAlert
        property color accent
        property real value
        property bool interactive

        signal clicked

        Layout.fillWidth: true
        Layout.preferredWidth: 0

        implicitHeight: content.implicitHeight + Tokens.padding.medium * 2
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large

        MouseArea {
            anchors.fill: parent
            enabled: card.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: card.clicked()
        }

        RowLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.small

            IconBadge {
                Layout.alignment: Qt.AlignTop
                icon: card.icon
                tint: card.accent
                ring: isNaN(card.value) ? 0 : card.value
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true

                        text: card.label
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    StyledRect {
                        Layout.alignment: Qt.AlignVCenter
                        visible: card.extra.length > 0
                        radius: Tokens.rounding.full
                        color: card.extraAlert ? Qt.alpha(Colours.palette.m3error, 0.16) : Colours.palette.m3surfaceContainerHighest
                        implicitWidth: extraText.implicitWidth + Tokens.padding.small * 2
                        implicitHeight: extraText.implicitHeight + Tokens.padding.extraSmall

                        StyledText {
                            id: extraText

                            anchors.centerIn: parent
                            text: card.extra
                            font: Tokens.font.body.small
                            color: card.extraAlert ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true

                    text: card.detail
                    font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                    visible: text.length > 0
                }

                StyledText {
                    Layout.fillWidth: true

                    text: card.sub
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                    visible: text.length > 0
                }
            }
        }
    }
}
