pragma Singleton

import QtQuick

// Island-specific measurements.
//
// Caelestia's Tokens and Config are attached properties scoped to a screen, and
// a singleton has no screen, so nothing here may read them -- these are plain
// constants. Anything that needs to scale with Caelestia's own tokens reads them
// directly from inside the island's window, where the screen scope exists.
QtObject {
    // Size of the notch when nothing is happening.
    readonly property real restingWidth: 148
    readonly property real restingHeight: 32

    // Expanded layers are capped so a long notification body wraps instead of
    // stretching the notch across the whole screen.
    readonly property real maxWidth: 520

    readonly property real horizontalPadding: 16
    readonly property real verticalPadding: 8
    readonly property real contentSpacing: 6

    // How long a transient layer holds the notch before falling back to the
    // clock. Notifications use their own expire timeout instead.
    readonly property int osdHideDelay: 2000

    readonly property real iconSize: 18
    readonly property real progressSize: 20
    readonly property real progressThickness: 3
    readonly property real artSize: 44
}
