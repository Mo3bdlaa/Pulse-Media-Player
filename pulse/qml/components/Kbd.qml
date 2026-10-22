import QtQuick
import Pulse

Rectangle {
    property alias text: label.text
    property bool accentBg: false
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22
    radius: 6
    color: accentBg ? "transparent" : Theme.surfaceRaised
    border.width: 1
    border.color: accentBg ? Qt.rgba(0.07, 0.07, 0.09, 0.35) : Theme.border
    Text {
        id: label
        anchors.centerIn: parent
        color: parent.accentBg ? Theme.textOnAccent : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }
}
