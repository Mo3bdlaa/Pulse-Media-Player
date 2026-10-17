import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Sidebar destination. Selected = raised fill + accent bar + weight (not colour alone).
T.ItemDelegate {
    id: control
    property string iconName
    property bool selected: false

    implicitHeight: Theme.navItem
    implicitWidth: 200
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
            color: control.selected ? Theme.accent : (control.hovered ? Theme.text : Theme.textSecondary)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
            color: control.selected || control.hovered ? Theme.text : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: control.selected ? Font.DemiBold : Font.Medium
        }
    }
    background: Rectangle {
        radius: Theme.radiusControl
        color: control.selected ? Theme.surfaceRaised : control.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        Rectangle {
            visible: control.selected
            width: 3
            height: parent.height
            radius: 1.5
            color: Theme.accent
        }
        FocusRing { target: control }
    }
}
