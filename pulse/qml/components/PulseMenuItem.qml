import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

T.MenuItem {
    id: control
    property string iconName
    property bool danger: false
    implicitHeight: 38
    leftPadding: 12
    rightPadding: 14
    font.family: Theme.fontFamily
    font.pixelSize: 14
    contentItem: Row {
        spacing: 10
        PulseIcon {
            visible: control.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: control.iconName
            size: 17
            color: control.danger ? Theme.errorText : Theme.textEmphasis
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            font: control.font
            color: !control.enabled ? Theme.iconMuted : control.danger ? Theme.errorText : Theme.text
        }
    }
    background: Rectangle {
        radius: 8
        color: control.highlighted ? Qt.rgba(1, 0.416, 0.157, 0.16) : "transparent"
    }
}
