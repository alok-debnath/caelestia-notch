pragma ComponentBehavior: Bound

import QtQuick
import qs.services

// Feeds the island one notification at a time from Caelestia's notification
// service.
//
// Reading Notifs rather than snooping the session bus is what gives the island
// the app icon, urgency, actions and Do Not Disturb for free: Notifs is the
// actual notification server, so its popup list already honours DND and carries
// the full NotifData.
QtObject {
    id: root

    // The notification the island is currently showing, or null.
    property NotifData current: null

    function dismiss(): void {
        if (current)
            current.popup = false;
        current = null;
    }

    // Show the newest popup. A newer notification replaces whatever is on
    // screen, which matches how the rest of the shell prioritises them.
    readonly property Connections conn: Connections {
        target: Notifs

        function onPopupsChanged(): void {
            const popups = Notifs.popups;
            if (popups.length === 0) {
                root.current = null;
                holdTimer.stop();
                return;
            }

            const newest = popups[popups.length - 1];
            if (newest === root.current)
                return;

            root.current = newest;
            holdTimer.interval = newest.expireTimeout > 0 ? newest.expireTimeout : IslandTokens.notifHideDelay;
            holdTimer.restart();
        }
    }

    readonly property Timer holdTimer: Timer {
        onTriggered: root.dismiss()
    }
}
