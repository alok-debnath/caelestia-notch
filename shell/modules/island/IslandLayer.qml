pragma ComponentBehavior: Bound

import QtQuick

// One of the island's non-resting layers, and how it is sized.
//
// The layer is laid out at the size the capsule is *going* to be, not at the
// capsule's current animating size. That is the difference between the island
// reading as one object opening and reading as jitter: content anchored to a
// capsule that is mid-morph re-runs its whole layout -- eliding, wrapping,
// measuring -- on every frame of the animation. Laid out once at the target
// size and clipped by the capsule, it is simply revealed instead.
Loader {
    id: root

    // The IslandWindow this layer belongs to. Untyped to keep the two files
    // from importing each other.
    required property var island

    // The state this layer is the content for.
    required property int forState

    readonly property bool shouldShow: island.islandState === forState

    // Centered by default: right for a short transient (a level, a line of
    // text) that should sit in the middle of whatever size pill it is. Search
    // is the exception -- the field belongs at the capsule's fixed top edge,
    // not at a center that drifts every keystroke as the result count (and so
    // the target height) changes. Centered, the capsule's clip window reveals
    // this layer from the middle outward as it grows, so the field -- pinned
    // to the top of a layer sized to its *final* height -- only scrolls into
    // view once the window has grown enough to reach it: exactly the "field
    // drops then springs back up" typing artifact this fixes. Top-anchored,
    // the reveal grows straight down from the one point (capsule y 0) that
    // never moves, so the field never does either.
    property bool anchorTop: false

    anchors.centerIn: anchorTop ? undefined : parent
    anchors.top: anchorTop ? parent.top : undefined
    anchors.horizontalCenter: anchorTop ? parent.horizontalCenter : undefined

    width: island.targetWidth
    height: island.targetHeight

    // Stays loaded a little past the state change so the fade-out below has
    // something to animate: unloading on the same frame the state flips is
    // what made a switch between two panels read as one vanishing rather than
    // two crossfading.
    active: shouldShow || fadeOutTimer.running
    visible: opacity > 0

    opacity: shouldShow ? 1 : 0
    scale: shouldShow ? 1 : 0.94

    onShouldShowChanged: if (!shouldShow)
        fadeOutTimer.restart()

    Behavior on opacity {
        NumberAnimation {
            duration: root.shouldShow ? IslandTokens.contentFadeDuration : IslandTokens.contentFadeOutDuration
            easing.type: root.shouldShow ? Easing.OutQuad : Easing.InQuad
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.shouldShow ? IslandTokens.contentFadeDuration : IslandTokens.contentFadeOutDuration
            easing.type: Easing.OutQuad
        }
    }

    Timer {
        id: fadeOutTimer

        interval: IslandTokens.contentFadeOutDuration
    }
}
