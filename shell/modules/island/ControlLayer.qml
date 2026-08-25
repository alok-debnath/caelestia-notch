pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.island.overview
import qs.services
import qs.utils

// The control centre, at Tide's size: two level cards over a grid of toggles.
//
// Tide's control centre is a shell of its own -- it owns wifi scanning,
// bluetooth pairing, power profiles. This one owns nothing: every row is a
// Caelestia service, so the toggles here and the same toggles in the sidebar
// are the same state.
SlidingLayer {
    id: root

    required property var island
    required property Brightness.Monitor monitor

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.extraLarge

        spacing: Tokens.spacing.large

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.large

            LevelCard {
                icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                label: qsTr("Volume")
                value: Audio.volume
                onMoved: v => Audio.setVolume(v)
                onIconClicked: if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.muted
            }

            LevelCard {
                icon: `brightness_${Math.round((root.monitor?.brightness ?? 0) * 6) + 1}`
                label: qsTr("Screen")
                value: root.monitor?.brightness ?? 0
                onMoved: v => root.monitor?.setBrightness(v)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            columns: 3
            rowSpacing: Tokens.spacing.small
            columnSpacing: Tokens.spacing.small

            Toggle {
                icon: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
                label: Nmcli.active?.ssid ?? qsTr("Wi-Fi")
                active: Nmcli.wifiEnabled
                onToggled: Nmcli.toggleWifi()
            }

            Toggle {
                icon: (Bluetooth.defaultAdapter?.enabled ?? false) ? "bluetooth" : "bluetooth_disabled"
                label: qsTr("Bluetooth")
                active: Bluetooth.defaultAdapter?.enabled ?? false
                onToggled: {
                    const adapter = Bluetooth.defaultAdapter;
                    if (adapter)
                        adapter.enabled = !adapter.enabled;
                }
            }

            Toggle {
                icon: Notifs.dnd ? "notifications_off" : "notifications"
                label: qsTr("Do Not Disturb")
                active: Notifs.dnd
                onToggled: Notifs.dnd = !Notifs.dnd
            }

            Toggle {
                icon: "sports_esports"
                label: qsTr("Game mode")
                active: GameMode.enabled
                onToggled: GameMode.enabled = !GameMode.enabled
            }

            Toggle {
                icon: IdleInhibitor.enabled ? "coffee" : "bedtime"
                label: qsTr("Keep awake")
                active: IdleInhibitor.enabled
                onToggled: IdleInhibitor.enabled = !IdleInhibitor.enabled
            }

            Toggle {
                icon: Recorder.running ? "stop_circle" : "screen_record"
                label: Recorder.running ? qsTr("Stop recording") : qsTr("Record")
                active: Recorder.running
                onToggled: {
                    if (Recorder.running)
                        Recorder.stop();
                    else
                        Recorder.start();
                }
            }
        }

        // The surfaces that are not everyday enough for the action row, plus
        // the settings window, which Caelestia owns and the island opens rather
        // than reimplements.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter

            spacing: 0

            IconButton {
                icon: "shelves"
                type: IconButton.Text
                isToggle: true
                checked: root.island.panel === IslandWindow.State.Shelf
                onClicked: root.island.openPanel(IslandWindow.State.Shelf)
            }

            IconButton {
                icon: "grid_view"
                type: IconButton.Text
                isToggle: true
                checked: OverviewState.visible
                onClicked: {
                    root.island.close();
                    OverviewState.toggle();
                }
            }

            IconButton {
                icon: "apps"
                type: IconButton.Text
                isToggle: true
                checked: root.island.searchOpen
                onClicked: root.island.toggleSearch()
            }

            IconButton {
                icon: "settings"
                type: IconButton.Text
                onClicked: {
                    root.island.close();
                    Quickshell.execDetached(["caelestia", "shell", "nexus", "open"]);
                }
            }

            IconButton {
                icon: "power_settings_new"
                type: IconButton.Text
                onClicked: {
                    root.island.close();
                    Quickshell.execDetached(["caelestia", "shell", "drawers", "toggle", "session"]);
                }
            }
        }

        IslandActions {
            Layout.alignment: Qt.AlignHCenter

            island: root.island
        }
    }

    // A level with its icon: the two things in the island you set rather than
    // read.
    component LevelCard: StyledRect {
        id: card

        property string icon
        property string label
        property real value

        signal moved(v: real)
        signal iconClicked

        Layout.fillWidth: true

        implicitHeight: cardLayout.implicitHeight + Tokens.padding.large * 2
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large

        ColumnLayout {
            id: cardLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.large

            spacing: Tokens.spacing.small

            RowLayout {
                spacing: Tokens.spacing.small

                IconButton {
                    icon: card.icon
                    type: IconButton.Text
                    onClicked: card.iconClicked()
                }

                IslandText {
                    Layout.fillWidth: true

                    dim: true
                    text: card.label
                    elide: Text.ElideRight
                }

                IslandText {
                    text: `${Math.round(card.value * 100)}%`
                }
            }

            StyledSlider {
                Layout.fillWidth: true

                implicitHeight: Tokens.padding.extraLarge
                value: card.value
                onInteraction: v => card.moved(v)
            }
        }
    }

    component Toggle: StyledRect {
        id: toggle

        property string icon
        property string label
        property bool active

        signal toggled

        Layout.fillWidth: true
        Layout.fillHeight: true

        color: active ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large

        Behavior on color {
            CAnim {}
        }

        StateLayer {
            radius: parent.radius
            color: toggle.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface

            onClicked: toggle.toggled()
        }

        ColumnLayout {
            anchors.centerIn: parent

            width: parent.width - Tokens.padding.medium * 2
            spacing: 0

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter

                text: toggle.icon
                color: toggle.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.builders.medium.build()
                fill: toggle.active ? 1 : 0
            }

            IslandText {
                Layout.fillWidth: true

                text: toggle.label
                color: toggle.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                font.pixelSize: IslandTokens.bodyPixelSize - 3
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
