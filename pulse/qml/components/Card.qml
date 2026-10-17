import QtQuick
import Pulse

Glass {
    property bool dashed: false
    radius: Theme.radiusPanel
    color: dashed ? "transparent" : Theme.glass
}
