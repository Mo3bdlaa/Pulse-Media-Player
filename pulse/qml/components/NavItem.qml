import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Sidebar destination. Selected: ember gradient + bloom + bold (01 Home).
T.ItemDelegate {
    id: control
    property string iconName
    property bool selected: false

    implicitHeight: Theme.navItem
    implicitWidth: 150
    leftPadding: 14
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.selected: selected

    contentItem: Row {
        spacing: 12
        PulseIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: control.iconName
            color: control.selected ? Theme.textOnAccent : (control.hovered ? Theme.text : Theme.textSecondary)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            color: control.selected ? Theme.textOnAccent : control.hovered ? Theme.text : Theme.textEmphasis
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: control.selected ? Font.Bold : Font.Medium
        }
    }
    background: Rectangle {
        radius: 10
        color: control.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        Rectangle {
            id: fill
            anchors.fill: parent
            radius: 10
            visible: control.selected
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.accentBright }
                GradientStop { position: 1.0; color: Theme.accentDeep }
            }
            border.width: 1
            border.color: Qt.rgba(1, 0.8, 0.6, 0.35)
            AccentGlow { strength: 0.7 }
        }
        FocusRing { target: control }
    }
}
