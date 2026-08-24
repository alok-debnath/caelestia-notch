pragma Singleton

import Quickshell

// Whether the workspace overview is open.
//
// A singleton rather than per-screen state: the overview covers every screen at
// once, the way Tide's does, so there is one answer to whether it is showing.
Singleton {
    id: root

    property bool visible

    function toggle(): void {
        visible = !visible;
    }

    function close(): void {
        visible = false;
    }
}
