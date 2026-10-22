import QtQuick
import QtQuick.Layouts
import Pulse
import Pulse.Core

// Docked transport shown outside the player while media is loaded.
Rectangle {
    id: root
    property bool compact: false
    signal expand()

    implicitHeight: compact ? 60 : 64
    color: compact ? Theme.surfaceRaised : Theme.surface
    radius: compact ? 14 : 0
    Rectangle { visible: !root.compact; width: parent.width; height: 1; color: Theme.border }

    TapHandler { onTapped: root.expand() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 10 : 24
        anchors.rightMargin: root.compact ? 8 : 24
        spacing: 14

        MediaThumb {
            Layout.preferredWidth: root.compact ? 40 : 64
            Layout.preferredHeight: root.compact ? 40 : 36
            radius: 6
            source: Player.url
            audio: !Player.hasVideo
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label { Layout.fillWidth: true; text: Player.title; font.weight: Font.DemiBold }
            Label {
                Layout.fillWidth: true
                role: "meta"; secondary: true
                text: Player.artist !== "" ? Player.artist : MediaInput.formatTime(Player.time) + " / " + MediaInput.formatTime(Player.length)
               
            }
        }
        IconButton { visible: !root.compact; iconName: "previous"; label: qsTr("Previous"); size: 40; enabled: Queue.hasPrevious; onClicked: Queue.previous() }
        IconButton { iconName: Player.playing ? "pause" : "play"; label: Player.playing ? qsTr("Pause") : qsTr("Play"); variant: "accent"; size: 44; onClicked: Player.togglePause() }
        IconButton { visible: !root.compact; iconName: "next"; label: qsTr("Next"); size: 40; enabled: Queue.hasNext; onClicked: Queue.next() }
        Rectangle {
            visible: !root.compact && root.width > 900
            Layout.preferredWidth: 240
            height: 4
            radius: 2
            color: Theme.border
            Rectangle { width: parent.width * Player.position; height: parent.height; radius: 2; color: Theme.accent }
        }
        PulseButton { visible: !root.compact; text: Player.hasVideo ? qsTr("Back to video") : qsTr("Open player"); implicitHeight: 40; onClicked: root.expand() }
    }
}
