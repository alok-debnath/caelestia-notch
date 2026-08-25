pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth

// Something just connected over Bluetooth.
//
// Tide announces a connection in the island the way a phone does -- the device,
// its battery, and what the volume is at -- and then puts it away. This watches
// the adapter's device list for a *new* connection rather than for the set
// being non-empty: the headphones that were already on when the shell started
// are not news.
QtObject {
    id: root

    // A panel the user opened is not interrupted by a pairing.
    property bool blocked

    property BluetoothDevice device: null
    property bool showing: false

    // Until the first sweep has run, every connected device looks new.
    property bool baselineReady: false
    property var seen: ({})

    readonly property list<BluetoothDevice> connected: Bluetooth.defaultAdapter ? Bluetooth.devices.values.filter(d => d.connected) : []

    function keyFor(d: BluetoothDevice): string {
        return d?.address || d?.name || "";
    }

    function sweep(): void {
        const now = {};
        let arrived = null;

        for (const d of connected) {
            const key = keyFor(d);
            if (!key)
                continue;
            now[key] = true;
            if (baselineReady && !seen[key])
                arrived = d;
        }

        seen = now;

        if (!baselineReady) {
            baselineReady = true;
            return;
        }

        if (!arrived || blocked)
            return;

        device = arrived;
        showing = true;
        hideTimer.restart();
    }

    onConnectedChanged: sweep()
    onBlockedChanged: if (blocked)
        showing = false

    readonly property Timer hideTimer: Timer {
        interval: IslandTokens.bluetoothHideDelay
        onTriggered: root.showing = false
    }

    // The list can be mid-populate on the first frame, so the baseline is taken
    // a beat after start rather than on it -- otherwise the devices that are
    // already connected all arrive as news.
    readonly property Timer baselineTimer: Timer {
        interval: 1500
        running: true
        onTriggered: root.sweep()
    }
}
