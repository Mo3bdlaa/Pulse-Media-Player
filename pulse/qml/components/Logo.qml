import QtQuick
import QtQuick.Window
import Pulse

// Pulse lockup: mark + optional wide-tracked wordmark.
Row {
    id: root
    property int markHeight: 24
    property bool wordmark: true
    spacing: 10

    Accessible.role: Accessible.StaticText
    Accessible.name: "Pulse"

    Image {
        anchors.verticalCenter: parent.verticalCenter
        source: "qrc:/qt/qml/Pulse/assets/logo/pulse-mark.svg"
        height: root.markHeight
        width: root.markHeight * 30 / 24
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
        Accessible.ignored: true
    }
    Text {
        visible: root.wordmark
        anchors.verticalCenter: parent.verticalCenter
        text: "PULSE"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.wordmarkSize
        font.weight: Font.Bold
        font.letterSpacing: Theme.wordmarkSize * Theme.wordmarkSpacing
        Accessible.ignored: true
    }
}
