pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// biopass face authentication, as a transient island layer.
//
// Nothing in the shell knows a scan is happening: the scan belongs to whatever
// process is authenticating (sudo, polkit, a re-auth prompt), and PAM has no bus
// to listen on. So the start comes in from outside -- `/usr/local/bin/biopass-gate`
// is a pam_exec that already runs immediately before `libbiopass_pam.so`, and it
// pings `qs ipc call faceId start` on its way through -- and the *result* is read
// back out of the journal, where the audit record for a granted authentication
// names its grantor:
//
//   op=PAM:authentication grantors=pam_exec,libbiopass_pam acct="alok" ... res=success
//
// Only a success is logged that way (a face that simply did not match falls
// through to the password prompt and logs nothing of its own), so a scan that
// ends without one is treated as a failure: the helper process going away is
// what ends it, plus a grace window for the journal line to arrive.
//
// The lock screen never comes through here. It authenticates against Caelestia's
// own `assets/pam.d/howdy`, not the system `password-auth` stack the gate sits
// in, and its surfaces cover every layer-shell window anyway.
QtObject {
    id: root

    enum Result {
        Scanning,
        Success,
        Failure
    }

    // A panel the user opened is not interrupted by a scan.
    property bool blocked

    readonly property bool showing: (scanning || holdTimer.running) && !blocked

    // A scan is in progress.
    property bool scanning
    property int result: FaceIdWatcher.Result.Scanning

    // Whether the helper has been seen running at all this scan. Until it has,
    // its absence means "not started yet", not "finished".
    property bool helperSeen

    function begin(): void {
        if (!IslandConfig.faceId)
            return;

        result = FaceIdWatcher.Result.Scanning;
        helperSeen = false;
        scanning = true;
        holdTimer.stop();
        graceTimer.stop();
        giveUpTimer.restart();
        pollTimer.restart();
        journal.running = true;
    }

    // Ends a scan, and also upgrades a failure that has already been shown: the
    // journal line for a success can land after the helper has exited, and a
    // capsule that has just said "not recognised" about an authentication that
    // in fact succeeded is worse than one that says nothing.
    function finish(res: int): void {
        if (!scanning && !(holdTimer.running && res === FaceIdWatcher.Result.Success && result === FaceIdWatcher.Result.Failure))
            return;

        scanning = false;
        result = res;
        giveUpTimer.stop();
        pollTimer.stop();
        graceTimer.stop();
        journal.running = false;
        holdTimer.restart();
    }

    // The journal follow, alive only while a scan is. `-n 0` so it starts at the
    // present rather than replaying every past authentication on the first line.
    readonly property Process journal: Process {
        // stdbuf: journalctl block-buffers when its stdout is a pipe, which
        // holds a success line back past the moment it is needed.
        command: ["stdbuf", "-oL", "journalctl", "-f", "-n", "0", "-o", "cat"]

        stdout: SplitParser {
            onRead: line => {
                if (!root.scanning && !root.graceTimer.running && !root.holdTimer.running)
                    return;
                // The grantor list names every module that granted, so the
                // gate's own pam_exec is in front of biopass on the sudo stack:
                // match the module anywhere in the line, not at the head of it.
                if (!line.includes("op=PAM:authentication") || !line.includes("libbiopass_pam"))
                    return;
                if (line.includes("res=success"))
                    root.finish(FaceIdWatcher.Result.Success);
            }
        }
    }

    // The helper is what actually holds the camera. It is spawned by the PAM
    // module a moment after the gate fires, so the poll waits to see it before
    // treating its absence as the end of the scan.
    readonly property Process helperProbe: Process {
        command: ["pgrep", "-f", "biopass-helper"]

        onExited: code => { // qmllint disable signal-handler-parameters
            if (!root.scanning)
                return;

            if (code === 0)
                root.helperSeen = true;
            else if (root.helperSeen && !root.graceTimer.running)
                root.graceTimer.restart();
        }
    }

    readonly property Timer pollTimer: Timer {
        interval: 350
        repeat: true
        onTriggered: {
            if (!root.helperProbe.running)
                root.helperProbe.running = true;
        }
    }

    // The helper has exited; the journal line for a success may still be a
    // moment behind it. Nothing by the end of this window was a failure.
    readonly property Timer graceTimer: Timer {
        interval: 1200
        onTriggered: root.finish(FaceIdWatcher.Result.Failure)
    }

    // A scan that never resolves -- the auth prompt was cancelled, the camera
    // never opened -- takes the capsule back rather than holding it forever.
    readonly property Timer giveUpTimer: Timer {
        interval: 15000
        onTriggered: root.finish(FaceIdWatcher.Result.Failure)
    }

    readonly property Timer holdTimer: Timer {
        interval: IslandTokens.faceIdHoldDelay
    }
}
