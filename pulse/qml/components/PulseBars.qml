import QtQuick
import Pulse

// Brand visualiser for audio (03): bars breathe while playing and fill with
// ember up to the playback position. Decorative only — not a waveform.
Row {
    id: root
    property int count: 56
    property real progress: 0
    property bool playing: false
    property bool animated: true
    spacing: 3

    Repeater {
        model: root.count
        delegate: Rectangle {
            id: bar
            required property int index
            readonly property real base: 0.25 + 0.55 * Math.abs(Math.sin(index * 0.71) * Math.cos(index * 0.23))
            property real level: base
            width: (root.width - root.spacing * (root.count - 1)) / root.count
            height: root.height * level
            anchors.verticalCenter: parent.verticalCenter
            radius: width / 2
            color: index / root.count <= root.progress ? Theme.accent : Qt.rgba(1, 1, 1, 0.16)
            SequentialAnimation on level {
                running: root.playing && root.animated
                loops: Animation.Infinite
                NumberAnimation { to: Math.min(1, bar.base + 0.25); duration: 300 + (bar.index * 37) % 260; easing.type: Easing.InOutSine }
                NumberAnimation { to: Math.max(0.12, bar.base - 0.2); duration: 280 + (bar.index * 53) % 300; easing.type: Easing.InOutSine }
            }
        }
    }
}
