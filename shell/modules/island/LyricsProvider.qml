pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Synced lyrics for whatever is playing, if the helper is installed.
//
// `lyricsmpris --pipe` writes one JSON object per line: `{"type":"line",
// "text":…,"synced":…}` as the track plays, and `{"type":"status",…}` around it.
// It is Tide Island's helper and an optional dependency here -- without it the
// lyrics page falls back to the track title, which is why nothing else in the
// island asks whether it is running.
QtObject {
    id: root

    readonly property string helper: "/usr/share/tide-island/bin/lyricsmpris"

    property string line: ""
    property string status: "idle"
    property bool synced

    readonly property bool available: proc.running
    readonly property bool hasLine: line.length > 0

    // Only run the helper while something is actually playing: it polls MPRIS
    // and talks to a lyrics API, neither of which is worth doing to an idle
    // session.
    readonly property Process proc: Process {
        running: IslandConfig.lyrics && (Players.active?.isPlaying ?? false)
        command: [root.helper, "--pipe"]

        stdout: SplitParser {
            onRead: data => {
                let msg;
                try {
                    msg = JSON.parse(data);
                } catch (e) {
                    return;
                }

                if (msg.type === "status") {
                    root.status = msg.status ?? "";
                    if (["idle", "searching", "missing", "error"].includes(root.status))
                        root.line = "";
                } else if (msg.type === "line") {
                    root.line = msg.text ?? "";
                    root.synced = !!msg.synced && root.line.length > 0;
                }
            }
        }

        onExited: {
            root.line = "";
            root.status = "idle";
        }
    }
}
