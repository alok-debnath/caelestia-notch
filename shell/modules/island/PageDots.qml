pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Where you are in a strip of pages, and how to get to another one.
//
// At rest it is dots: one per page, the current one lit, and `position` is
// fractional rather than an index so a drag lights the two dots it is between
// in proportion -- the row tracks the finger instead of snapping when the page
// finally commits.
//
// Put the pointer on it and it opens into the names, with a slider behind the
// one you are on. That is the whole affordance: dots are unreadable until you
// need them, so the row stays out of the way and says what it means only while
// you are looking at it. It closes on its own the moment the pointer leaves.
//
// The row is also the handle: drag it sideways to move between pages, or click
// a dot (or a name) to jump. It is deliberately the only draggable part of a
// panel, because the panels themselves own their drags (windows in the
// overview, the wallpaper strip, a scrolling list) and a swipe surface over
// the top of those would take gestures that belong to them.
Item {
    id: root

    property int count: 2

    // 0-based, fractional under a drag.
    property real position: 0

    // One per page. Without them the row never opens -- it is just dots.
    property list<string> labels: []

    // How far the finger travels for one page.
    property real travel: 90

    signal selected(index: int)

    // Open state is held rather than bound straight to the pointer. Two
    // reasons, both of which showed up as the row flickering open and shut:
    // the row itself changes size when it opens, so binding "open" to hover on
    // the row makes the hover target move under the pointer that caused it;
    // and the pointer crosses the gaps between the dots and the names as they
    // cross-fade. So the *target* is a fixed-size box that never moves (see
    // below), and opening and closing are both delayed.
    property bool held: false

    readonly property bool open: labels.length === count && (held || drag.active)
    readonly property int current: Math.max(0, Math.min(count - 1, Math.round(position)))

    // The row's *box* never changes size: it is always as big as the open
    // state needs, and the visuals shrink inside it. Two bugs came out of the
    // box animating instead. It moved the hover target out from under the
    // pointer that opened it, so the row flickered; and the pill behind the
    // active name is positioned against this box, so a box that grew on open
    // swept the pill in from the left edge every time.
    implicitWidth: Math.max(nameArea.implicitWidth, dotRow.implicitWidth) + 40
    implicitHeight: IslandTokens.dotsOpenHeight + 8

    // On the root, not on a child box beside the dots: the dots carry
    // MouseAreas with a `cursorShape`, and setting one makes a MouseArea
    // accept hover events -- which means it swallows them from any *sibling*
    // underneath. An ancestor keeps receiving hover whatever a descendant
    // does with it, so this is the one place the handler can live and still
    // see the pointer when it is directly over a dot.
    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                closeTimer.stop();
                openTimer.restart();
            } else {
                openTimer.stop();
                closeTimer.restart();
            }
        }
    }

    // Long enough that crossing the row on the way somewhere else does not
    // open it.
    Timer {
        id: openTimer

        interval: 130
        onTriggered: root.held = true
    }

    // Short, but not instant: the pointer can slip off an edge and come back.
    Timer {
        id: closeTimer

        interval: 260
        onTriggered: root.held = false
    }

    // The strip's own surface, which only exists while it is open. It is the
    // thing that animates now -- not the box around it.
    StyledRect {
        anchors.centerIn: parent

        implicitWidth: nameArea.implicitWidth + 12
        implicitHeight: IslandTokens.dotsOpenHeight
        radius: height / 2
        color: Colours.tPalette.m3surfaceContainer
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: IslandTokens.contentFadeDuration
                easing.type: Easing.InOutQuad
            }
        }
    }

    Row {
        id: dotRow

        anchors.centerIn: parent

        spacing: 6
        opacity: root.open ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: IslandTokens.contentFadeOutDuration
                easing.type: Easing.InOutQuad
            }
        }

        Repeater {
            id: dots

            model: root.count

            StyledRect {
                required property int index

                implicitWidth: 5
                implicitHeight: 5
                radius: height / 2
                color: Colours.palette.m3onSurface
                opacity: 0.25 + 0.6 * Math.max(0, 1 - Math.abs(root.position - index))

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8

                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(parent.index)
                }
            }
        }
    }

    // The names, and the slider behind them.
    //
    // Both live in one box that is centred as a unit, and the slider is
    // positioned in *that box's* coordinates rather than the row's parent's.
    // That is the difference between the slider sitting still while the row
    // opens and it sweeping in from the left edge every single time: the
    // parent's width animates from the dots' width to the names' width, so
    // anything positioned against the parent moves with it.
    Item {
        id: nameArea

        anchors.centerIn: parent

        implicitWidth: nameRow.implicitWidth
        implicitHeight: IslandTokens.dotsOpenHeight
        opacity: root.open ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: IslandTokens.contentFadeDuration
                easing.type: Easing.InOutQuad
            }
        }

        // The slider: it sits behind the name you are on and slides to the
        // next, so the row reads as one control moving rather than as seven
        // that light up in turn.
        StyledRect {
            readonly property Item item: names.itemAt(root.current)

            x: item?.x ?? 0
            y: 3
            width: item?.width ?? 0
            height: parent.height - 6
            radius: height / 2
            color: Colours.palette.m3primaryContainer

            Behavior on x {
                NumberAnimation {
                    duration: IslandTokens.contentFadeDuration
                    easing.type: Easing.OutQuint
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: IslandTokens.contentFadeDuration
                    easing.type: Easing.OutQuint
                }
            }
        }

        Row {
            id: nameRow

            anchors.verticalCenter: parent.verticalCenter

            spacing: 0

            Repeater {
                id: names

                model: root.labels

                Item {
                    required property string modelData
                    required property int index

                    readonly property bool active: index === root.current

                    implicitWidth: label.implicitWidth + 20
                    implicitHeight: IslandTokens.dotsOpenHeight

                    IslandText {
                        id: label

                        anchors.centerIn: parent

                        text: parent.modelData
                        color: parent.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                        font.pixelSize: 12
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(parent.index)
                    }
                }
            }
        }
    }

    // Scroll over the row to move between pages.
    //
    // Here rather than over the panel, which is where it used to be: a panel
    // that scrolls something of its own -- the shelf's tray, the notification
    // list, the wallpaper strip -- had the wheel taken out from under it, and
    // the tray could not be scrolled sideways at all. The row is the tab
    // control, so the row is where the wheel changes tabs. One notch is one
    // page, with a short cooldown so a flick does not fly through five.
    WheelHandler {
        id: pageWheel

        property bool cooling: false

        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        orientation: Qt.Horizontal | Qt.Vertical

        onWheel: event => {
            if (cooling)
                return;

            const px = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0 ? event.pixelDelta : Qt.point(event.angleDelta.x / 4, event.angleDelta.y / 4);
            const delta = Math.abs(px.x) > Math.abs(px.y) ? px.x : px.y;
            if (Math.abs(delta) < 2)
                return;

            const next = root.current + (delta < 0 ? 1 : -1);
            if (next < 0 || next >= root.count)
                return;

            root.selected(next);
            cooling = true;
            wheelCooldown.restart();
        }
    }

    // Outside the handler: a WheelHandler has no default property, so a Timer
    // declared inside it will not load at all.
    Timer {
        id: wheelCooldown

        interval: 260
        onTriggered: pageWheel.cooling = false
    }

    DragHandler {
        id: drag

        property int from: 0
        // Kept as the drag runs: `activeTranslation` is back to zero by the
        // time the release is handled.
        property real moved: 0

        target: null
        // An explicit press, and a real distance before it counts as a drag:
        // without both, a pointer that merely crosses the row can register as
        // one and step the tab under it.
        acceptedButtons: Qt.LeftButton
        dragThreshold: 12
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveTranslationChanged: if (active)
            moved = activeTranslation.x

        onActiveChanged: {
            if (active) {
                from = root.current;
                moved = 0;
                return;
            }

            // Half a page either way commits, the way a carousel settles.
            const pages = Math.round(moved / root.travel);
            if (pages !== 0)
                root.selected(Math.max(0, Math.min(root.count - 1, from - pages)));
        }
    }
}
