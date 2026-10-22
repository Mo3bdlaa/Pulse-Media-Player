import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Rounded glass search box (06 / 08).
T.TextField {
    id: control
    implicitHeight: 40
    implicitWidth: 300
    leftPadding: 40
    rightPadding: text !== "" ? 36 : 12
    color: Theme.text
    placeholderTextColor: Theme.textSecondary
    font.family: Theme.fontFamily
    font.pixelSize: 13
    selectByMouse: true
    Accessible.role: Accessible.EditableText
    Accessible.name: placeholderText
    Keys.onEscapePressed: (e) => { if (text !== "") { text = ""; e.accepted = true } else e.accepted = false }
    background: Rectangle {
        radius: 10
        color: Qt.rgba(0.05, 0.05, 0.07, 0.72)
        border.width: 1
        border.color: control.activeFocus ? Qt.rgba(1, 0.416, 0.157, 0.6) : Theme.glassBorder
        PulseIcon { x: 13; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 17; color: Theme.textSecondary }
        IconButton {
            visible: control.text !== ""
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            size: 30; iconSize: 14; iconName: "close"; label: qsTr("Clear search")
            onClicked: control.text = ""
        }
    }
}
