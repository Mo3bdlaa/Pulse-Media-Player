import QtQuick
import Pulse

// Numbered track line (07 Audio / Subtitles): number, name, codec, detail.
Rectangle {
    id: root
    property int number
    property string name
    property string codec
    property string detail
    property bool current: false
    width: parent ? parent.width : 0
    height: 36
    radius: 8
    color: current ? Qt.rgba(1, 0.416, 0.157, 0.16) : "transparent"
    border.width: current ? 1 : 0
    border.color: Qt.rgba(1, 0.416, 0.157, 0.45)
    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        spacing: 12
        Text { width: 18; text: root.number; color: root.current ? Theme.accent : Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
        Label { width: root.width * 0.46 - 40; text: root.name; font.pixelSize: 13; color: Theme.text }
        Label { width: root.width * 0.22; text: root.codec; role: "meta"; color: Theme.textEmphasis }
        Label { width: root.width * 0.24; text: root.detail; role: "meta"; secondary: true; horizontalAlignment: Text.AlignRight }
    }
}
