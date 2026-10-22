import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Phone navigation: at most five destinations; hidden while playing fullscreen.
Rectangle {
    id: root
    property string route
    signal navigate(string route)

    implicitHeight: 64
    color: Theme.bg
    Rectangle { width: parent.width; height: 1; color: Theme.border }
    Accessible.role: Accessible.PageTabList

    Row {
        anchors.fill: parent
        anchors.topMargin: 4
        Repeater {
            model: [
                { route: "home", icon: "home", text: qsTr("Home") },
                { route: "library", icon: "library", text: qsTr("Library") },
                { route: "playlists", icon: "playlists", text: qsTr("Playlists") },
                { route: "network", icon: "network", text: qsTr("Network") },
                { route: "settings", icon: "more", text: qsTr("More") }
            ]
            delegate: T.AbstractButton {
                id: tab
                required property var modelData
                readonly property bool on: root.route === modelData.route
                width: root.width / 5
                height: 56
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.text
                Accessible.selected: on
                onClicked: root.navigate(modelData.route)
                contentItem: Column {
                    spacing: 4
                    PulseIcon { anchors.horizontalCenter: parent.horizontalCenter; name: tab.modelData.icon; size: 24; color: tab.on ? Theme.accent : Theme.textSecondary }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tab.modelData.text
                        color: tab.on ? Theme.accent : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: tab.on ? Font.Bold : Font.Medium
                    }
                }
                background: Item { FocusRing { target: tab } }
            }
        }
    }
}
