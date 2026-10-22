import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Pulse

// Pulse lockup: mark (with a soft ember bloom) + wide-tracked wordmark.
Row {
    id: root
    property int markHeight: 24
    property bool wordmark: true
    property bool glow: true
    property int wordSize: Theme.wordmarkSize
    spacing: Math.round(markHeight * 0.45)

    Accessible.role: Accessible.StaticText
    Accessible.name: "Pulse"

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: root.markHeight * 30 / 24
        height: root.markHeight
        Glow {
            anchors.fill: mark
            visible: root.glow
            source: mark
            radius: Math.max(6, root.markHeight * 0.35)
            samples: 17
            color: Qt.rgba(1, 0.42, 0.16, 0.55)
            spread: 0.1
        }
        Image {
            id: mark
            anchors.fill: parent
            source: "qrc:/qt/qml/Pulse/assets/logo/pulse-mark.svg"
            sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)
            Accessible.ignored: true
        }
    }
    Text {
        visible: root.wordmark
        anchors.verticalCenter: parent.verticalCenter
        text: "PULSE"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: root.wordSize
        font.weight: Font.Bold
        font.letterSpacing: root.wordSize * 0.42
        Accessible.ignored: true
    }
}
