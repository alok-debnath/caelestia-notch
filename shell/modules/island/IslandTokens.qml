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
    readonly property real notifMaxWidth: 520
    readonly property real notifMinHeight: 56
    // Tide's two notification sizes: one line up to 400 wide, and the expanded
    // one at 520 by up to 240 with the body scrollable inside it.
    readonly property real notifCompactWidth: 400
    readonly property real notifExpandedWidth: 520
    readonly property real notifExpandedHeight: 240

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
    // Tide's shelf card: a big system icon with the name under it, five of
    // them across before the tray starts scrolling.
    readonly property real shelfCardWidth: 176
    readonly property real shelfCardHeight: 176
    readonly property real shelfCellWidth: 196
    readonly property int shelfCapacity: 5
    readonly property real shelfPadding: 18
    readonly property real clipboardHeight: 420

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
    // those. 400 is Tide's own number, restored after a pass comparing the
    // two side by side: the shorter morph won on paper and lost in the hand --
    // the capsule arrived before the content had begun to settle.
    readonly property int morphDuration: 400
    readonly property int swipeDuration: 220
    // Layers crossfade rather than take turns: the outgoing one is gone well
    // before the incoming one has finished arriving, so the two always overlap
    // and a switch between two panels never shows an empty capsule. The
    // incoming layer is the slower of the two on purpose -- it is the one being
    // read, and it settles under the shape morph rather than beating it.
    readonly property int contentFadeDuration: 190
    readonly property int contentFadeOutDuration: 120

    // Panels also travel along the switcher's axis: a tab to the right arrives
    // from the right while the one it replaces leaves to the left. Small --
    // this is a hint about which way you moved, not a page transition.
    readonly property real contentSlideDistance: 16
    readonly property int contentSlideDuration: 300

    // Text swaps: see IslandRollText. Out faster than in, for the same reason
    // the layers are.
    readonly property int textRollInDuration: 240
    readonly property int textRollOutDuration: 140
    readonly property real textRollTravel: 0.9

    // -- Hold times -------------------------------------------------------
    readonly property int splitHideDelay: 1250
    // A face scan's answer is held a beat longer than a volume level: it is
    // information you asked for, not a level you were already watching change.
    readonly property int faceIdHoldDelay: 1500
    // The Face ID mark's own motion: one pass of the beam over the face, and
    // how long the tick or cross takes to draw itself.
    readonly property int faceIdSweepDuration: 900
    readonly property int faceIdDrawDuration: 340
    readonly property real faceIdGlyphSize: 22
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
    // The time on a swipe page, which Tide sets a shade larger and tighter
    // than body text so it still reads as the clock at page scale.
    readonly property int timePixelSize: 17
    readonly property real timeLetterSpacing: -0.25

    // -- Panels -----------------------------------------------------------
    // One padding for every panel, kept minimal: the capsule is already a
    // generous shape and a second inset inside it wastes the only space the
    // island has. `panelTopReserve` is what each panel leaves clear at its top
    // for the tab row, which is pinned there on every surface so it is always
    // in the same place.
    readonly property real panelPadding: 14
    readonly property real dotsMargin: 6
    readonly property real dotsHeight: 18
    // What the row grows to when the pointer opens it into the names. The
    // reserve clears *that*, not the closed height: sized to the dots, the
    // open row lands on the first line of a panel.
    readonly property real dotsOpenHeight: 26
    readonly property real panelTopReserve: dotsMargin + dotsOpenHeight + 6

    // -- Content ----------------------------------------------------------
    readonly property real horizontalPadding: 16
    readonly property real verticalPadding: 8
    readonly property real contentSpacing: 6
    readonly property real hiddenPadding: 16

    // The resting strip. Tide swipes by moving *content* through one box
    // rather than by sliding whole pages past each other: the clock leaves by
    // one edge as the page's own content arrives from the other, and the two
    // are never both centred. These are the paddings that math runs on -- a
    // page's content is hidden one `swipeHiddenPadding` past the edge, so it
    // is fully gone before the capsule has finished narrowing.
    readonly property real pagePadding: 14
    readonly property real swipeHiddenPadding: 18
    // Between the cover, the line and the bars on the media page.
    readonly property real pageVisualSpacing: 35

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
