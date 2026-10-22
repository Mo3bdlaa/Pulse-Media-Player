import QtQuick
import Qt5Compat.GraphicalEffects
import Pulse

// Real picture from the media: a video frame, or the embedded cover for audio.
// A calm placeholder shows while it loads, for streams, or when there is none.
Item {
    id: root
    property url source
    property bool audio: false
    property bool stream: false
    property real progress: 0
    property string badge
    property string corner
    property real radius: 10
    property real framePos: 0.3
    readonly property bool loaded: pic.status === Image.Ready

    function hue(s) {
        let h = 0
        for (let i = 0; i < s.length; ++i)
            h = (h * 31 + s.charCodeAt(i)) % 360
        return h / 360
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0; color: root.audio ? "#7A2A12" : Qt.hsla(root.hue(root.source.toString()), 0.3, 0.2, 1) }
            GradientStop { position: 1; color: root.audio ? "#1A0A0C" : "#0B0C10" }
        }
        PulseIcon {
            anchors.centerIn: parent
            visible: !root.loaded
            name: root.stream ? "network" : root.audio ? "music" : "film"
            size: Math.max(16, Math.min(40, root.height * 0.36))
            color: Qt.rgba(1, 1, 1, 0.35)
        }
    }

    Image {
        id: pic
        anchors.fill: parent
        visible: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(64, root.width) * 1.5, Math.max(36, root.height) * 1.5)
        source: root.stream || root.source.toString() === "" ? ""
              : "image://thumb/" + encodeURIComponent(root.source.toString()) + (root.audio ? "?art=1" : "?pos=" + root.framePos)
    }
    OpacityMask {
        anchors.fill: parent
        visible: root.loaded
        source: pic
        maskSource: frame
    }

    Rectangle {
        visible: root.badge !== ""
        x: 8; y: 8
        width: badgeText.implicitWidth + 12
        height: 20
        radius: 6
        color: Qt.rgba(0.05, 0.05, 0.06, 0.82)
        Text { id: badgeText; anchors.centerIn: parent; text: root.badge; color: Theme.highlight; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold }
    }
    Rectangle {
        visible: root.corner !== ""
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        anchors.bottomMargin: root.progress > 0 ? 12 : 8
        width: cornerText.implicitWidth + 12
        height: 22
        radius: 6
        color: Qt.rgba(0.05, 0.05, 0.06, 0.82)
        Text { id: cornerText; anchors.centerIn: parent; text: root.corner; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold }
    }
    Rectangle {
        visible: root.progress > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.radius / 2
        anchors.rightMargin: root.radius / 2
        height: 3
        color: Qt.rgba(0.97, 0.96, 0.94, 0.25)
        Rectangle { width: parent.width * root.progress; height: parent.height; color: Theme.accent }
    }
}
