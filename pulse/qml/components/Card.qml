import QtQuick
import Pulse

Rectangle {
    property bool dashed: false
    radius: Theme.radiusPanel
    color: dashed ? "transparent" : Theme.surface
    border.width: 1
    border.color: Theme.border
}
