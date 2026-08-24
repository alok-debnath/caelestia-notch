pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Text at the notch's own scale.
//
// The notch is a fixed height, so its type is sized in pixels rather than off
// Caelestia's point-size tokens, which are tuned for the bar. The family and
// the colour still come from the shell: this is Tide's scale in Caelestia's
// typeface and Caelestia's palette.
StyledText {
    id: root

    // Hero is the clock and anything else that carries a whole state on its
    // own; body is everything else.
    property bool hero
    property bool dim

    font.family: hero ? Tokens.font.clock.build().family : Tokens.font.title.medium.family
    font.pixelSize: hero ? IslandTokens.heroPixelSize : IslandTokens.bodyPixelSize
    font.weight: hero ? Font.Bold : Font.DemiBold
    font.letterSpacing: hero ? IslandTokens.heroLetterSpacing : IslandTokens.bodyLetterSpacing
    color: dim ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
}
