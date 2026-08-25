pragma ComponentBehavior: Bound

import QtQuick

// The time, one rolling glyph per character.
//
// One character per IslandRollText, so the minute tick only rolls the digit
// that actually changed. A single label bound to the whole string re-rolls
// end to end every tick, which is the "the clock refreshes" judder Tide never
// had -- and which is the whole reason the roll exists.
Row {
    id: root

    property string text
    property bool dim

    spacing: 0

    Repeater {
        model: root.text.length

        IslandRollText {
            required property int index

            hero: true
            dim: root.dim
            text: root.text[index] ?? ""
        }
    }
}
