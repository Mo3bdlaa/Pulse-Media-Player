import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Thin track, accent fill, light knob. `centered` fills from the middle (picture adjust).
T.Slider {
    id: control
    property bool centered: false
    property color fillColor: Theme.accent
    property color trackColor: Qt.rgba(1, 1, 1, 0.14)
    implicitHeight: 28
    implicitWidth: 160
    focusPolicy: Qt.StrongFocus

    background: Item {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: control.orientation === Qt.Horizontal ? 4 : control.availableHeight
        Rectangle {
            anchors.fill: parent
            radius: 2
            color: control.trackColor
        }
        Rectangle {
            readonly property real mid: control.centered ? 0.5 : 0
            x: Math.min(mid, control.visualPosition) * parent.width
            width: Math.abs(control.visualPosition - mid) * parent.width
            height: parent.height
            radius: 2
            color: control.fillColor
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.pressed ? 18 : 14
        height: width
        radius: width / 2
        color: Theme.text
        border.width: control.pressed ? 0 : 0
        Rectangle { anchors.centerIn: parent; width: parent.width + 8; height: width; radius: width / 2; color: Qt.rgba(1, 0.416, 0.157, control.hovered || control.pressed ? 0.35 : 0.0); z: -1 }
        FocusRing { target: control; radius_: 9 }
    }
}
