pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// A face scan, in the long capsule: the glyph on the left, a word on the right.
//
// The scanning state is the whole point of this layer, so the mark itself is
// drawn rather than set in a font: FaceIdGlyph sweeps a beam over a face while
// the camera is looking, then draws a tick or a cross over it. Everything else
// here is a colour and a word, held for a beat by the watcher -- the capsule
// morphing back is the exit.
SlidingLayer {
    id: root

    required property bool scanning
    required property int result

    readonly property bool failed: !scanning && result === FaceIdWatcher.Result.Failure

    readonly property string label: {
        if (scanning)
            return qsTr("Face ID");
        return result === FaceIdWatcher.Result.Success ? qsTr("Approved") : qsTr("Not recognised");
    }

    readonly property color accent: root.failed ? Colours.palette.m3error : Colours.palette.m3primary

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: IslandTokens.horizontalPadding * 0.875
        anchors.rightMargin: IslandTokens.horizontalPadding * 0.875
        anchors.verticalCenter: parent.verticalCenter

        spacing: IslandTokens.contentSpacing * 2

        FaceIdGlyph {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: IslandTokens.faceIdGlyphSize
            Layout.preferredHeight: IslandTokens.faceIdGlyphSize

            scanning: root.scanning
            failed: root.failed
            colour: root.accent
        }

        IslandRollText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            text: root.label
            color: root.scanning ? Colours.palette.m3onSurface : root.accent
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
