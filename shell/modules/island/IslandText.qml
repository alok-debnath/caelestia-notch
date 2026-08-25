pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Text at the notch's own scale.
//
// The notch is a fixed height, so its type is sized in pixels rather than off
// Caelestia's point-size tokens, which are tuned for the bar -- and it is set
// in Tide's own face, not the shell's. That is deliberate: the island is a
// fixed-height strip of small, tight, negative-tracked type, which is what
// Inter Display at these sizes was picked for upstream, and mixing the bar's
// display face into it is exactly what made this island read as a Caelestia
// panel wearing a notch costume. Colour still comes from the shell.
//
// The family is configurable (Panels -> Island), so a system without Inter
// falls back rather than breaking.
StyledText {
    id: root

    // Hero is the clock and anything else that carries a whole state on its
    // own; body is everything else.
    property bool hero
    property bool dim

    font.family: IslandConfig.fontFamily
    font.pixelSize: hero ? IslandTokens.heroPixelSize : IslandTokens.bodyPixelSize
    font.weight: hero ? Font.Bold : Font.DemiBold
    font.letterSpacing: hero ? IslandTokens.heroLetterSpacing : IslandTokens.bodyLetterSpacing
    color: dim ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
}
