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

    // Notifications size to their content between these.
    readonly property real notifMinWidth: 272
    readonly property real notifMinHeight: 56

    // Panels.
    readonly property real playerWidth: 410
    readonly property real playerHeight: 165
    readonly property real controlWidth: 420
    readonly property real controlHeight: 352
    readonly property real panelWidth: 410
    readonly property real widePanelWidth: 470
    readonly property real shelfWidth: 1100
    readonly property real shelfHeight: 260

    // -- Corner radii -----------------------------------------------------
    readonly property real restingRadius: restingHeight / 2
    readonly property real notifRadius: 28
    readonly property real playerRadius: 40
    readonly property real panelRadius: 34

    // -- Motion -----------------------------------------------------------
    // 400ms OutQuint on width, height and radius: quick to start with a long
    // settle. Everything else in the island is faster than the morph, so the
    // shape leads and the content follows.
    readonly property int morphDuration: 400
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

    // The cava strip: Tide's bar metrics.
    readonly property real barWidth: 4
    readonly property real barSpacing: 3
    readonly property real barMinHeight: 4
    readonly property real barAreaHeight: 18
}
