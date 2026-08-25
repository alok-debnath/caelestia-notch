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

    anchors.centerIn: parent

    width: island.targetWidth
    height: island.targetHeight

    active: island.islandState === forState
    visible: active

    // Fades in as the capsule opens. There is no fade out: the layer is
    // unloaded the moment its state ends, and the capsule closing over it is
    // what hides it.
    opacity: active ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: IslandTokens.contentFadeDuration
            easing.type: Easing.OutQuad
        }
    }
}
