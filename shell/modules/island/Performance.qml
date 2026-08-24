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

// System resources as a list of rows.
//
// Same numbers the dashboard's cards showed -- usage, temperature, used of
// total, transfer rates, session totals, charge and time left -- but a row each
// instead of a card each: the notch is a strip, and a strip reads down, not
// across. Nothing was dropped to make it fit; the circular gauges became the
// bar at the bottom of each row, which carries the same value.
//
// Which rows exist is still Config.dashboard.performance.*, provided by
// Caelestia.Config in C++ and outliving the drawer it was named after.
ColumnLayout {
    id: root

    readonly property bool hasGpu: Config.dashboard.performance.showGpu && Gpu.type !== Gpu.None
    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery
    readonly property bool empty: !Config.dashboard.performance.showCpu && !hasGpu && !Config.dashboard.performance.showMemory && !Config.dashboard.performance.showStorage && !Config.dashboard.performance.showNetwork && !hasBattery

    function formatTemp(t: real): string {
        const f = GlobalConfig.services.useFahrenheitPerformance;
        return `${Math.ceil(f ? t * 1.8 + 32 : t)}°${f ? "F" : "C"}`;
    }

    spacing: Tokens.spacing.small

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.small
        Layout.bottomMargin: Tokens.spacing.small

        text: qsTr("No widgets enabled")
        font: Tokens.font.body.medium
        color: Colours.palette.m3onSurfaceVariant
        visible: root.empty
    }

    // CPU
    StatRow {
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
    StatRow {
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
    StatRow {
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
    StatRow {
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

    // Network. The bar is replaced by the sparkline, since a rate has no
    // percentage to fill.
    StatRow {
        id: network

        visible: Config.dashboard.performance.showNetwork
        icon: "swap_vert"
        label: qsTr("Network")
        sub: {
            const down = NetworkUsage.formatBytesTotal(NetworkUsage.downloadTotal ?? 0);
            const up = NetworkUsage.formatBytesTotal(NetworkUsage.uploadTotal ?? 0);
            return (down && up) ? qsTr("↓%1%2 ↑%3%4").arg(down.value.toFixed(1)).arg(down.unit).arg(up.value.toFixed(1)).arg(up.unit) : "";
        }
        accent: Colours.palette.m3primary
        detail: {
            const fmt = NetworkUsage.formatBytes(NetworkUsage.downloadSpeed ?? 0);
            return `↓ ${fmt ? `${fmt.value.toFixed(1)} ${fmt.unit}` : "0.0 B/s"}`;
        }
        extra: {
            const fmt = NetworkUsage.formatBytes(NetworkUsage.uploadSpeed ?? 0);
            return `↑ ${fmt ? `${fmt.value.toFixed(1)} ${fmt.unit}` : "0.0 B/s"}`;
        }
        barComponent: sparkline

        Ref {
            service: NetworkUsage
        }
    }

    // Battery
    StatRow {
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

    Component {
        id: sparkline

        SparklineItem {
            id: spark

            property real smoothMax: 1024

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

    // One reading: what it is, what it says, and how full it is.
    component StatRow: StyledRect {
        id: row

        property string icon
        property string label
        property string sub
        property string detail
        property string extra
        property bool extraAlert
        property color accent
        property real value
        property Component barComponent: null
        property bool interactive

        signal clicked

        Layout.fillWidth: true

        implicitHeight: rowLayout.implicitHeight + bar.implicitHeight + Tokens.padding.small * 2 + Tokens.spacing.extraSmall
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.medium

        MouseArea {
            anchors.fill: parent
            enabled: row.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }

        RowLayout {
            id: rowLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.small
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: row.icon
                color: row.accent
                fontStyle: Tokens.font.icon.small
                fill: 1
            }

            StyledText {
                text: row.label
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                color: Colours.palette.m3onSurface
            }

            StyledText {
                Layout.fillWidth: true

                text: row.sub
                font: Tokens.font.body.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
                visible: text.length > 0
            }

            StyledText {
                text: row.detail
                font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                color: row.accent
                visible: text.length > 0
            }

            StyledText {
                text: row.extra
                font: Tokens.font.body.small
                color: row.extraAlert ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                visible: text.length > 0
            }
        }

        Loader {
            id: bar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.small
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium

            sourceComponent: row.barComponent ?? levelBar
        }

        Component {
            id: levelBar

            StyledRect {
                implicitHeight: Tokens.padding.extraSmall
                color: Colours.palette.m3surfaceContainerHighest
                radius: Tokens.rounding.full

                StyledRect {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    implicitWidth: parent.width * Math.max(0, Math.min(1, isNaN(row.value) ? 0 : row.value))
                    color: row.accent
                    radius: Tokens.rounding.full

                    Behavior on implicitWidth {
                        Anim {}
                    }
                }
            }
        }
    }
}
