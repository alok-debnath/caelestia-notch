pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// One notch per screen.
//
// The windows here draw only the island's *content*. Its shape is drawn by
// ContentWindow.qml, which mirrors the capsule's geometry into the shell's blob
// group so the notch fuses into the screen border. Each window registers itself
// into ShellState so ContentWindow can find the capsule to mirror.
Scope {
    id: root

    function forActiveWindow(callback): void {
        const components = ShellState.componentsForActive();
        if (components?.island)
            callback(components.island);
    }

    IpcHandler {
        function togglePlayer(): void {
            root.forActiveWindow(w => w.openPanel(IslandWindow.State.Player));
        }

        function toggleCalendar(): void {
            root.forActiveWindow(w => w.openPanel(IslandWindow.State.Calendar));
        }

        function togglePerformance(): void {
            root.forActiveWindow(w => w.openPanel(IslandWindow.State.Performance));
        }

        function toggleNotifications(): void {
            root.forActiveWindow(w => w.openPanel(IslandWindow.State.NotifCenter));
        }

        function overview(): void {
            root.forActiveWindow(w => w.openPanel(IslandWindow.State.Overview));
        }

        function toggleShelf(): void {
            root.forActiveWindow(w => w.openPanel(IslandWindow.State.Shelf));
        }

        function toggleClipboard(): void {
            root.forActiveWindow(w => w.openPanel(IslandWindow.State.Clipboard));
        }

        function clearClipboard(): void {
            Clipboard.clear();
        }

        // Wayland drag-and-drop never reaches this window (layer-shell, not a
        // toplevel), so this is the keybind-friendly form of the paste button
        // in ShelfLayer: copy a file, then call this.
        function pasteFile(): void {
            FileShelf.pasteFromClipboard();
            root.forActiveWindow(w => w.openPanel(IslandWindow.State.Shelf));
        }

        function toggleSearch(): void {
            root.forActiveWindow(w => w.toggleSearch());
        }

        // The resting pages, for anyone who would rather bind a key than swipe.
        function nextPage(): void {
            root.forActiveWindow(w => w.settleSwipe(1));
        }

        function previousPage(): void {
            root.forActiveWindow(w => w.settleSwipe(-1));
        }

        function close(): void {
            root.forActiveWindow(w => w.close());
        }

        target: "island"
    }

    // The face-scan capsule, driven from outside the shell.
    //
    // `/usr/local/bin/biopass-gate` is a pam_exec that runs immediately before
    // `libbiopass_pam.so` in the system auth stack; it calls this on its way
    // through, so the notch shows the scan for sudo, polkit and every other
    // re-auth in the session. The result is read back out of the journal by
    // FaceIdWatcher -- PAM has nothing to report it on.
    IpcHandler {
        function start(): void {
            root.forActiveWindow(w => w.beginFaceId());
        }

        target: "faceId"
    }

    Variants {
        model: Screens.screens

        IslandWindow {
            id: window

            required property var modelData

            screen: modelData

            ShellState.ComponentRef {
                screen: window.modelData
                slot: "island"
                component: window
            }
        }
    }
}
