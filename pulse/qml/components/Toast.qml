import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Non-blocking status message with one optional action.
Rectangle {
    id: root
    property string message
    property string actionText
    property bool error: false
    signal action()

    function show(msg, act, isError) {
        message = msg
        actionText = act || ""
        error = !!isError
        opacity = 1
        hideTimer.restart()
    }

    implicitWidth: row.implicitWidth + 26
    implicitHeight: 52
    radius: Theme.radiusCard
    color: error ? Qt.rgba(1, 0.353, 0.388, 0.14) : Theme.surface
    border.width: 1
    border.color: error ? Theme.error : Theme.border
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
    Accessible.role: Accessible.AlertMessage
    Accessible.name: message

    Timer { id: hideTimer; interval: 5000; onTriggered: root.opacity = 0 }
    HoverHandler { onHoveredChanged: hovered ? hideTimer.stop() : hideTimer.restart() }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: 16
        spacing: 12
        PulseIcon {
            visible: root.error
            anchors.verticalCenter: parent.verticalCenter
            name: "alert"
            color: Theme.errorText
            size: 18
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.message
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
        }
        PulseButton {
            visible: root.actionText !== ""
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 34
            text: root.actionText
            onClicked: { root.opacity = 0; root.action() }
        }
    }
}
