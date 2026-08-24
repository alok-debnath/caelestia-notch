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
            root.forActiveWindow(w => w.toggle(IslandWindow.Expanded.Player));
        }

        function toggleCalendar(): void {
            root.forActiveWindow(w => w.toggle(IslandWindow.Expanded.Calendar));
        }

        function togglePerformance(): void {
            root.forActiveWindow(w => w.toggle(IslandWindow.Expanded.Performance));
        }

        function close(): void {
            root.forActiveWindow(w => w.close());
        }

        target: "island"
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
