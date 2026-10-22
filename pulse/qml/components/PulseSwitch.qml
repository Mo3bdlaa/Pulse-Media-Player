import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

T.Switch {
    id: control
    implicitWidth: 44
    implicitHeight: 26
    padding: 0
    focusPolicy: Qt.StrongFocus
    indicator: Rectangle {
        width: 44
        height: 26
        radius: 13
        color: control.checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.14)
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        Rectangle {
            y: 3
            x: control.checked ? parent.width - width - 3 : 3
            width: 20
            height: 20
            radius: 10
            color: control.checked ? "#FFFFFF" : Theme.textSecondary
            Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutCubic } }
        }
        FocusRing { target: control; radius_: 13 }
    }
    contentItem: Item {}
}
