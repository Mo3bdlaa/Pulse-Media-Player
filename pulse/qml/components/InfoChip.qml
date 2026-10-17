import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Two-line glass chip: icon · caption / value · chevron (02 Subtitles, 03 Output Device).
T.AbstractButton {
    id: control
    property string iconName
    property string caption
    property string value
    property bool chevron: true
    implicitHeight: 52
    implicitWidth: row.implicitWidth + 28
    focusPolicy: Qt.StrongFocus
    Accessible.name: caption + ": " + value

    background: Glass {
        radius: 12
        color: control.hovered ? Qt.rgba(0.14, 0.15, 0.19, 0.92) : Theme.glass
        border.color: control.hovered ? Qt.rgba(1, 0.416, 0.157, 0.5) : Theme.glassBorder
        FocusRing { target: control; radius_: 12 }
    }
    contentItem: Item {
        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            spacing: 12
            PulseIcon { anchors.verticalCenter: parent.verticalCenter; name: control.iconName; size: 22 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text { text: control.caption; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 11 }
                Text { text: control.value; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; width: Math.min(implicitWidth, 200) }
            }
            PulseIcon { visible: control.chevron; anchors.verticalCenter: parent.verticalCenter; name: "chevron-right"; size: 16; color: Theme.textSecondary }
        }
    }
}
