pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// A device just connected, in one line.
//
// Tide gives this a whole 410x165 panel with the volume drawn as a slider you
// cannot touch. That is a lot of island for a fact you read in half a second,
// so it is a capsule here instead: what connected, and how much charge it has.
// The volume is not in it -- changing sinks fires the OSD anyway, which is the
// island's own way of saying that, and saying it twice in two shapes is worse
// than saying it once.
SlidingLayer {
    id: root

    required property BluetoothDevice device

    property real maximumWidth: IslandTokens.longWidth

    readonly property bool hasBattery: device?.batteryAvailable ?? false
    readonly property int batteryPercent: hasBattery ? Math.round(device.battery <= 1 ? device.battery * 100 : device.battery) : -1

    readonly property color batteryColour: {
        if (batteryPercent <= 10)
            return Colours.palette.m3error;
        if (batteryPercent <= 20)
            return Colours.palette.m3tertiary;
        return Colours.palette.m3onSurfaceVariant;
    }

    // The capsule is exactly as wide as the line, between the long capsule's
    // width and whatever the screen allows.
    readonly property real preferredWidth: Math.max(IslandTokens.longWidth, Math.min(maximumWidth, row.implicitWidth + IslandTokens.horizontalPadding * 2.5))

    RowLayout {
        id: row

        anchors.centerIn: parent

        width: parent.width - IslandTokens.horizontalPadding * 1.75
        spacing: IslandTokens.contentSpacing * 2

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter

            text: Icons.getBluetoothIcon(root.device?.icon ?? "")
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.builders.medium.build()
            fill: 1
        }

        IslandText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: root.device?.name || root.device?.address || qsTr("Bluetooth device")
            elide: Text.ElideRight
        }

        // The charge, when the device reports one. Tide draws a cell here; at
        // one line the figure is the whole story and the cell is decoration.
        IslandText {
            Layout.alignment: Qt.AlignVCenter

            visible: root.hasBattery
            text: `${root.batteryPercent}%`
            color: root.batteryColour
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter

            visible: root.hasBattery
            text: Icons.getBatteryIcon(root.batteryPercent / 100)
            color: root.batteryColour
            fontStyle: Tokens.font.icon.small
            fill: 1
        }
    }
}
