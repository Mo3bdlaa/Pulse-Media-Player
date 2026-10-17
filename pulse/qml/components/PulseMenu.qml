import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Dark context menu; items are PulseMenuItem.
T.Menu {
    id: root
    padding: 6
    implicitWidth: Math.max(200, contentItem.implicitWidth + leftPadding + rightPadding)
    background: Rectangle {
        implicitWidth: 200
        radius: 12
        color: "#F2181A21"
        border.width: 1
        border.color: Theme.glassBorder
    }
    delegate: PulseMenuItem {}
}
