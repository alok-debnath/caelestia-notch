pragma Singleton

import QtQuick

// Tide Island's geometry, timing and type scale.
//
// The numbers are Tide's own, because the way the notch *feels* is mostly this
// table: every state has a fixed size the capsule morphs to, and the content
// lays out inside it. Sizing the capsule to its content instead -- the obvious
// way -- is what made an earlier version of this island read as a popup rather
// than one object changing shape.
//
// Caelestia's Tokens and Config are attached properties scoped to a screen, and
// a singleton has no screen, so nothing here may read them. Colour comes from
// Colours inside the layers; only measurements live here.
QtObject {
    // -- Capsule sizes per state ------------------------------------------
    // Resting.
    readonly property real restingWidth: 140
    readonly property real restingHeight: 38

    // A transient icon (split), and the same with a level or a word beside it.
    readonly property real splitProgressWidth: 248
    readonly property real splitTextWidth: 220

    // The long capsule: workspace switches and anything else that is a line of
    // text rather than a panel.
    readonly property real longWidth: 220

    // Swipe pages are as wide as they need, between these.
    readonly property real swipeMinWidth: 220
    readonly property real swipeSideMargin: 48

    // Notifications size to their content between these. `notifMaxWidth` is
    // a real cap, not just "whatever fits the screen" -- the width the
    // layer asks for is passed `root.width - swipeSideMargin` as its own
    // ceiling (see IslandWindow.qml), which on a wide screen is most of the
    // screen, so a long summary/body with no natural break stretched the
    // notch out to match instead of wrapping.
    readonly property real notifMinWidth: 272
    readonly property real notifMaxWidth: 420
    readonly property real notifMinHeight: 56

    // Panels.
    readonly property real playerWidth: 410
    readonly property real playerHeight: 190
    readonly property real overviewWidth: 760
    readonly property real panelWidth: 410
    readonly property real notifCenterMaxHeight: 420
    readonly property real notifCenterListHeight: 300
    readonly property real widePanelWidth: 470
    readonly property real shelfWidth: 1100
    readonly property real shelfHeight: 260
    readonly property real shelfCardWidth: 130
    readonly property real clipboardHeight: 420

    // The panel switcher pill: fixed size so it lands at the same spot
    // regardless of which panel is open. Deliberately tiny -- it is a tab
    // strip, not a control, and shouldn't compete with the panel under it
    // for attention. `switcherReserve` is what every panel leaves empty at
    // its own top so the pill (which floats above the panel content, not
    // inside its layout) never overlaps it.
    readonly property real switcherHeight: 24
    readonly property real switcherReserve: 4

    // Search. The notch becomes the field and Caelestia's launcher hangs below
    // it, so the list's own sizes apply -- these are only the fallback width
    // before it has measured itself, and the height of the field above it.
    readonly property real searchWidth: 520
    readonly property real searchBarHeight: 52

    // The layer-shell surface the island draws into. Fixed and generous rather
    // than sized to the capsule -- see IslandWindow.qml for why -- so it has to
    // clear the tallest panel with room to spare.
    readonly property real windowHeight: 900

    // -- Corner radii -----------------------------------------------------
    readonly property real restingRadius: restingHeight / 2
    readonly property real notifRadius: 28
    readonly property real playerRadius: 40
    readonly property real panelRadius: 34

    // -- Motion -----------------------------------------------------------
    // OutQuint on width, height and radius: quick to start with a long
    // settle. Everything else in the island is faster than the morph, so the
    // shape leads and the content follows. 320ms rather than Material's
    // ~400+ "expressive" scale on purpose -- this is a small fixed-size
    // shape morphing a few hundred pixels at most, not a full-screen
    // transition, and reads as sluggish at the larger durations that suit
    // those.
    readonly property int morphDuration: 320
    readonly property int swipeDuration: 220
    readonly property int contentFadeDuration: 150
    readonly property int contentFadeOutDuration: 140

    // -- Hold times -------------------------------------------------------
    readonly property int splitHideDelay: 1250
    readonly property int notifHideDelay: 4200
    readonly property int bluetoothHideDelay: 2500

    // Hover, as Tide had it: a delay before expanding so crossing the notch on
    // the way somewhere else does not open it, and a shorter one before
    // collapsing so the pointer can slip off an edge and come back.
    readonly property int hoverExpandDelay: 350
    readonly property int hoverCollapseDelay: 250

    // -- Type -------------------------------------------------------------
    // Pixel sizes, not point sizes: Tide's scale, and the notch is a fixed
    // height so the type in it has to be too.
    readonly property int heroPixelSize: 20
    readonly property int bodyPixelSize: 16
    readonly property int iconPixelSize: 18
    readonly property real heroLetterSpacing: -0.35
    readonly property real bodyLetterSpacing: -0.15

    // -- Content ----------------------------------------------------------
    readonly property real horizontalPadding: 16
    readonly property real verticalPadding: 8
    readonly property real contentSpacing: 6
    readonly property real hiddenPadding: 16

    readonly property real artSize: 44
    readonly property real smallArtSize: 26
    readonly property real progressSize: 30
    readonly property real progressThickness: 3.5

    // The media resting page. Tide keeps it a compact capsule -- cover, title,
    // a short strip of bars -- rather than letting it grow to the width of
    // whatever is playing, which is what makes it read as a page of the notch
    // and not as a panel that opened on its own.
    readonly property real mediaMaxWidth: 340

    // How many bars the strip draws, regardless of how many cava reports.
    readonly property int mediaBarCount: 10

    readonly property int marqueePause: 1600
    readonly property real marqueeMsPerPixel: 22

    // The cava strip: Tide's bar metrics.
    readonly property real barWidth: 4
    readonly property real barSpacing: 3
    readonly property real barMinHeight: 4
    readonly property real barAreaHeight: 18
}
