import QtQuick
import Pulse

// Panel that floats over art, video or the ember scene.
Rectangle {
    property bool lit: false   // warm rim for emphasised panels
    radius: 14
    color: Theme.glass
    border.width: 1
    border.color: lit ? Qt.rgba(1, 0.416, 0.157, 0.45) : Theme.glassBorder
}
