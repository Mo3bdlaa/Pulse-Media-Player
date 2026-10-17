import QtQuick
import Pulse

// First playable item's picture, or a calm placeholder for empty playlists.
Item {
    id: root
    property url cover
    property string kind
    property real radius: 10
    MediaThumb {
        anchors.fill: parent
        visible: root.cover.toString() !== ""
        radius: root.radius
        source: root.cover
        audio: root.kind === "music"
    }
    Rectangle {
        anchors.fill: parent
        visible: root.cover.toString() === ""
        radius: root.radius
        color: "#2A2E39"
        border.width: 1
        border.color: Theme.glassBorder
        PulseIcon { anchors.centerIn: parent; name: "music"; size: Math.min(36, parent.height * 0.42); color: Theme.textSecondary }
    }
}
