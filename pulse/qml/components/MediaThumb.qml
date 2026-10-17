import QtQuick
import Pulse

// Placeholder thumbnail until frame thumbnails land (P1): a calm gradient
// seeded from the URL plus a kind icon. Never shows invented artwork.
Rectangle {
    id: root
    property url source
    property bool audio: false
    property bool stream: false
    property real progress: 0
    property string badge
    property string corner

    function hue(s) {
        let h = 0
        for (let i = 0; i < s.length; ++i)
            h = (h * 31 + s.charCodeAt(i)) % 360
        return h / 360
    }
    readonly property real h: hue(source.toString())

    radius: Theme.radiusCard
    clip: true
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0; color: root.audio ? Qt.hsla(0.05, 0.75, 0.42, 1) : Qt.hsla(root.h, 0.35, 0.22, 1) }
        GradientStop { position: 1; color: root.audio ? Qt.hsla(0.95, 0.5, 0.08, 1) : Qt.hsla(root.h, 0.3, 0.07, 1) }
    }
    PulseIcon {
        anchors.centerIn: parent
        name: root.stream ? "network" : root.audio ? "music" : "film"
        size: Math.min(40, parent.height * 0.36)
        color: Qt.rgba(1, 1, 1, 0.35)
    }
    Rectangle {
        visible: root.badge !== ""
        x: 8; y: 8
        width: badgeText.implicitWidth + 12
        height: 20
        radius: 6
        color: Qt.rgba(0.07, 0.07, 0.09, 0.85)
        Text { id: badgeText; anchors.centerIn: parent; text: root.badge; color: Theme.highlight; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold }
    }
    Rectangle {
        visible: root.corner !== ""
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        anchors.bottomMargin: root.progress > 0 ? 12 : 8
        width: cornerText.implicitWidth + 12
        height: 20
        radius: 6
        color: Qt.rgba(0.07, 0.07, 0.09, 0.85)
        Text { id: cornerText; anchors.centerIn: parent; text: root.corner; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold }
    }
    Rectangle {
        visible: root.progress > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 4
        color: Qt.rgba(0.97, 0.96, 0.94, 0.18)
        Rectangle { width: parent.width * root.progress; height: parent.height; color: Theme.accent }
    }
}
