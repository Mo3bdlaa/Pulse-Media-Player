import QtQuick
import QtQuick.Window
import Pulse

// Desktop title bar (custom frame): lockup, command search, window controls.
Rectangle {
    id: root
    property var window
    property bool showSearch: true
    signal searchRequested()
    signal homeRequested()

    implicitHeight: Theme.titleBar + 8
    color: "transparent"

    DragHandler {
        target: null
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onActiveChanged: if (active && root.window) root.window.startSystemMove()
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onDoubleTapped: if (root.window) root.window.toggleMaximized()
    }

    Logo {
        x: 22
        anchors.verticalCenter: parent.verticalCenter
        markHeight: 26
        wordSize: 18
        TapHandler { onTapped: root.homeRequested() }
    }

    // Opens the command palette (Ctrl+K); not a text field itself.
    PulseButton {
        id: search
        visible: root.showSearch && root.width > 640
        anchors.centerIn: parent
        width: Math.min(520, root.width - 520)
        implicitHeight: 36
        Accessible.name: qsTr("Search or run a command")
        onClicked: root.searchRequested()
        contentItem: Item {
            PulseIcon { id: sIcon; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 18; color: Theme.textSecondary }
            Text {
                anchors.left: sIcon.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Search or type a command")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
            Kbd { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "Ctrl K" }
        }
        leftPadding: 12
        rightPadding: 8
        background: Rectangle {
            radius: 10
            color: Qt.rgba(0.09, 0.09, 0.11, 0.85)
            border.width: 1
            border.color: search.hovered ? Qt.rgba(1, 0.416, 0.157, 0.5) : Theme.glassBorder
            FocusRing { target: search }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        IconButton { iconName: "minimize"; label: qsTr("Minimize"); iconSize: 16; width: 44; height: 36; onClicked: root.window.showMinimized() }
        IconButton {
            iconName: root.window && root.window.visibility === Window.Maximized ? "restore" : "maximize"
            label: root.window && root.window.visibility === Window.Maximized ? qsTr("Restore") : qsTr("Maximize")
            iconSize: 15; width: 44; height: 36
            onClicked: root.window.toggleMaximized()
        }
        IconButton { iconName: "close"; label: qsTr("Close"); iconSize: 16; width: 44; height: 36; onClicked: root.window.close() }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
}
