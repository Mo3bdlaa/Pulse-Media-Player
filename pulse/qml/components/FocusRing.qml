import QtQuick
import Pulse

// Gold keyboard-focus ring; never shown for mouse or touch focus.
Rectangle {
    property Item target: parent
    property real radius_: target && target.background && target.background.radius !== undefined ? target.background.radius : Theme.radiusControl
    anchors.fill: parent
    anchors.margins: -3
    radius: radius_ + 3
    color: "transparent"
    border.width: 2
    border.color: Theme.highlight
    visible: target && target.visualFocus === true
}
