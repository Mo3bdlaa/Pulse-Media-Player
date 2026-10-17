import QtQuick
import QtQuick.Layouts
import Pulse

// Desktop primary navigation. "Now Playing" and "Queue" appear only when media is loaded.
Rectangle {
    id: root
    property string route
    property bool hasMedia: false
    signal navigate(string route)

    implicitWidth: Theme.sidebar
    color: Theme.bg
    Accessible.role: Accessible.PageTabList
    Accessible.name: qsTr("Primary")

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: 16
        spacing: 4

        NavItem { visible: root.hasMedia; Layout.fillWidth: true; text: qsTr("Now Playing"); iconName: "music"; selected: root.route === "player"; onClicked: root.navigate("player") }
        NavItem { visible: root.hasMedia; Layout.fillWidth: true; text: qsTr("Queue"); iconName: "queue"; selected: root.route === "queue"; onClicked: root.navigate("queue") }
        Rectangle { visible: root.hasMedia; Layout.fillWidth: true; Layout.margins: 6; height: 1; color: Theme.border }

        NavItem { Layout.fillWidth: true; text: qsTr("Home"); iconName: "home"; selected: root.route === "home"; onClicked: root.navigate("home") }
        NavItem { Layout.fillWidth: true; text: qsTr("Library"); iconName: "library"; selected: root.route === "library"; onClicked: root.navigate("library") }
        NavItem { Layout.fillWidth: true; text: qsTr("Playlists"); iconName: "playlists"; selected: root.route === "playlists"; onClicked: root.navigate("playlists") }
        NavItem { Layout.fillWidth: true; text: qsTr("Network"); iconName: "network"; selected: root.route === "network"; onClicked: root.navigate("network") }
        NavItem { Layout.fillWidth: true; text: qsTr("Convert"); iconName: "convert"; selected: root.route === "convert"; onClicked: root.navigate("convert") }
        NavItem { Layout.fillWidth: true; text: qsTr("Settings"); iconName: "settings"; selected: root.route === "settings"; onClicked: root.navigate("settings") }
        Item { Layout.fillHeight: true }
    }
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.border }
}
