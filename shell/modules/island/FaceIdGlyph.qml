pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// The Face ID mark, drawn and animated rather than set as a font glyph.
//
// It is the iOS one: four corner brackets around a face, a beam sweeping the
// box while the camera is looking, and the face giving way to a tick (or a
// cross) that draws itself when there is an answer. A Material Symbols glyph
// could stand in for the resting shape, but not for any of the motion -- and
// the motion is the whole reason a scan is worth showing at all.
//
// Everything inside `box` is laid out in a 24x24 space and scaled from there,
// so the paths read as coordinates rather than as fractions of a size, and one
// `scale` carries the stroke widths and the dash lengths along with them.
Item {
    id: root

    // What the mark is doing: the face while scanning, then the tick or cross.
    required property bool scanning
    required property bool failed

    property color colour: "white"

    // In box units, so it is the width the stroke has at 24x24.
    property real strokeWidth: 2

    readonly property real unit: Math.min(width, height) / 24

    // The result strokes draw themselves by walking a dash the length of the
    // whole path off the end of it. The lengths are the paths' own, measured
    // once in box units -- a few percent either way is invisible at this size,
    // and cheaper than asking the scene graph for an exact arc length.
    readonly property real tickLength: 15
    readonly property real crossLength: 10

    // How faded the face is. A ShapePath is not an Item, so this rides on the
    // stroke colour rather than on an opacity.
    property real faceFade: scanning ? 1 : 0

    implicitWidth: 24
    implicitHeight: 24

    function alpha(a: real): color {
        return Qt.rgba(colour.r, colour.g, colour.b, colour.a * a);
    }

    // Which answer is being drawn, and when. One handler rather than bindings,
    // so a scan starting again parks both strokes undrawn.
    function syncResult(): void {
        tickAnim.stop();
        crossAnim.stop();

        if (scanning) {
            tick.progress = 0;
            cross.progress = 0;
            return;
        }

        popAnim.restart();

        if (failed) {
            tick.progress = 0;
            crossAnim.restart();
            shakeAnim.restart();
        } else {
            cross.progress = 0;
            tickAnim.restart();
        }
    }

    onScanningChanged: syncResult()
    onFailedChanged: syncResult()
    Component.onCompleted: syncResult()

    Behavior on faceFade {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutQuad
        }
    }

    Item {
        id: box

        anchors.centerIn: parent

        // `pop` and `nudge` are the result animations' handles: animating
        // `scale` or `x` directly would break the bindings that place the box.
        property real pop: 1
        property real nudge: 0

        width: 24
        height: 24
        scale: root.unit * pop
        anchors.horizontalCenterOffset: nudge

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // The four corner brackets. They are the constant: the mark keeps
            // its frame through the scan and through the answer, and only what
            // sits inside the frame changes.
            ShapePath {
                strokeColor: root.colour
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: "M 1 7.5 L 1 6 A 5 5 0 0 1 6 1 L 7.5 1"
                }
                PathSvg {
                    path: "M 16.5 1 L 18 1 A 5 5 0 0 1 23 6 L 23 7.5"
                }
                PathSvg {
                    path: "M 23 16.5 L 23 18 A 5 5 0 0 1 18 23 L 16.5 23"
                }
                PathSvg {
                    path: "M 7.5 23 L 6 23 A 5 5 0 0 1 1 18 L 1 16.5"
                }
            }

            // The face: two eyes, a nose and a mouth. Present only while the
            // camera is looking.
            ShapePath {
                strokeColor: root.alpha(root.faceFade)
                strokeWidth: root.strokeWidth * 0.85
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: "M 8.5 8.5 L 8.5 11"
                }
                PathSvg {
                    path: "M 15.5 8.5 L 15.5 11"
                }
                PathSvg {
                    path: "M 12 8.5 L 12 13 L 10.6 13"
                }
                PathSvg {
                    path: "M 8.6 15.4 C 10 17.6 14 17.6 15.4 15.4"
                }
            }

            // The tick, and the cross. Each is drawn by its dash offset walking
            // to zero, so the stroke appears to be written rather than to fade
            // up. `dashPattern` is in multiples of the stroke width, which is
            // why the lengths are divided by it.
            ShapePath {
                id: tick

                property real progress: 0

                strokeColor: root.colour
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                strokeStyle: ShapePath.DashLine
                dashPattern: [root.tickLength / root.strokeWidth, root.tickLength / root.strokeWidth]
                dashOffset: (1 - progress) * root.tickLength / root.strokeWidth

                PathSvg {
                    path: "M 7 12.6 L 10.6 16 L 17 8.6"
                }
            }

            ShapePath {
                id: cross

                property real progress: 0

                strokeColor: root.colour
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                strokeStyle: ShapePath.DashLine
                dashPattern: [root.crossLength / root.strokeWidth, root.crossLength / root.strokeWidth]
                dashOffset: (1 - progress) * root.crossLength / root.strokeWidth

                PathSvg {
                    path: "M 8.6 8.6 L 15.4 15.4"
                }
                PathSvg {
                    path: "M 15.4 8.6 L 8.6 15.4"
                }
            }
        }

        // The beam: one sweep down and back up while the camera is looking,
        // clipped to the inside of the brackets and dimmest at the turns, so it
        // reads as a scan rather than as a bar bouncing off two edges.
        Item {
            anchors.fill: parent
            clip: true
            opacity: root.faceFade

            Rectangle {
                width: parent.width * 0.62
                height: root.strokeWidth * 0.75
                radius: height / 2
                x: (parent.width - width) / 2
                y: 6

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.5
                        color: root.colour
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }

                SequentialAnimation on y {
                    running: root.scanning
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 17
                        duration: IslandTokens.faceIdSweepDuration
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 6
                        duration: IslandTokens.faceIdSweepDuration
                        easing.type: Easing.InOutSine
                    }
                }

                SequentialAnimation on opacity {
                    running: root.scanning
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 1
                        duration: IslandTokens.faceIdSweepDuration / 2
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 0.2
                        duration: IslandTokens.faceIdSweepDuration / 2
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    // The pop on an answer. OutBack overshoots and settles, which is what makes
    // the tick read as stamped on rather than faded in.
    SequentialAnimation {
        id: popAnim

        NumberAnimation {
            target: box
            property: "pop"
            to: 1.18
            duration: 140
            easing.type: Easing.OutBack
            easing.overshoot: 3
        }
        NumberAnimation {
            target: box
            property: "pop"
            to: 1
            duration: 240
            easing.type: Easing.OutBack
        }
    }

    // A miss also shakes, once, a stroke's width either way.
    SequentialAnimation {
        id: shakeAnim

        NumberAnimation {
            target: box
            property: "nudge"
            to: -root.strokeWidth
            duration: 60
            easing.type: Easing.OutSine
        }
        NumberAnimation {
            target: box
            property: "nudge"
            to: root.strokeWidth
            duration: 90
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: box
            property: "nudge"
            to: 0
            duration: 90
            easing.type: Easing.OutBack
        }
    }

    NumberAnimation {
        id: tickAnim

        target: tick
        property: "progress"
        from: 0
        to: 1
        duration: IslandTokens.faceIdDrawDuration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: crossAnim

        target: cross
        property: "progress"
        from: 0
        to: 1
        duration: IslandTokens.faceIdDrawDuration
        easing.type: Easing.OutCubic
    }
}
