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
    anchors.horizontalCenterOffset: slideOffset

    width: island.targetWidth
    height: island.targetHeight

    // Stays loaded a little past the state change so the fade-out below has
    // something to animate: unloading on the same frame the state flips is
    // what made a switch between two panels read as one vanishing rather than
    // two crossfading.
    active: shouldShow || fadeOutTimer.running
    visible: opacity > 0

    opacity: shouldShow ? 1 : 0
    // A side transient is already moving a whole box width; scaling it as well
    // reads as two effects on one object.
    scale: shouldShow || entrySide !== 0 ? 1 : 0.97

    // How far off centre this layer is sitting, along whichever axis this
    // transition travels. Driven by hand rather than by a binding on
    // `shouldShow`, because the arriving layer and the leaving one need
    // different signs of the same direction and a binding cannot tell which of
    // the two it is on.
    property real slideOffset: 0

    // Which side of the strip this layer came in from, kept for its exit: by
    // the time it leaves, the island is resting again and the window's own
    // `transientSide` has already gone back to zero.
    property int entrySide: 0

    onShouldShowChanged: {
        if (shouldShow)
            entrySide = island.transientSide;

        // A transient that came in off a side page travels the strip's own
        // axis, a whole box width, and goes back out the way it came -- Tide
        // slides it against the page it replaced. Everything else is a tab
        // switch: a short shift along the switcher's order, and the leaver
        // exits opposite the arriver.
        const side = entrySide !== 0;
        const distance = side ? entrySide * (width + IslandTokens.hiddenPadding) : island.switchDirection * IslandTokens.contentSlideDistance;

        slide.duration = side ? IslandTokens.swipeDuration : IslandTokens.contentSlideDuration;
        slide.easing.type = side ? Easing.OutCubic : Easing.OutQuint;

        slide.stop();
        if (shouldShow) {
            slideOffset = distance;
            slide.to = 0;
        } else {
            fadeOutTimer.restart();
            slide.to = side ? distance : -distance;
        }
        slide.restart();
    }

    NumberAnimation {
        id: slide

        target: root
        property: "slideOffset"
        duration: IslandTokens.contentSlideDuration
        easing.type: Easing.OutQuint
    }

    // A side transient fades on the strip's own clock and curve, so the fade
    // and the slide finish together; everything else keeps the crossfade the
    // panels are tuned for.
    Behavior on opacity {
        NumberAnimation {
            duration: root.entrySide !== 0 ? (root.shouldShow ? 280 : 200) : (root.shouldShow ? IslandTokens.contentFadeDuration : IslandTokens.contentFadeOutDuration)
            easing.type: root.entrySide !== 0 ? Easing.InOutQuad : (root.shouldShow ? Easing.OutCubic : Easing.InCubic)
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.shouldShow ? IslandTokens.contentSlideDuration : IslandTokens.contentFadeOutDuration
            easing.type: root.shouldShow ? Easing.OutQuint : Easing.InQuad
        }
    }

    Timer {
        id: fadeOutTimer

        // Outlives the fade itself, so the leaving layer is still mounted for
        // the whole of its slide rather than blinking out halfway through it.
        interval: IslandTokens.contentSlideDuration
    }
}
