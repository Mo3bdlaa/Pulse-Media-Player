import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// Now Playing vs Up Next, reorderable. Removing never deletes files.
ListView {
    id: root
    property bool dense: false
    clip: true
    spacing: 2
    model: Queue
    boundsBehavior: Flickable.StopAtBounds
    Accessible.role: Accessible.List
    Accessible.name: qsTr("Queue")

    delegate: T.ItemDelegate {
        id: row
        required property int index
        required property url url
        required property string title
        required property bool isCurrent
        required property bool isAudio
        required property bool missing
        width: ListView.view.width
        height: root.dense ? 56 : 60
        opacity: missing ? 0.7 : 1
        Accessible.name: (isCurrent ? qsTr("Now playing: ") : "") + title
        onClicked: Queue.playIndex(index)
        Keys.onPressed: (e) => {
            if (e.modifiers & Qt.AltModifier && e.key === Qt.Key_Up) { Queue.move(index, index - 1); e.accepted = true }
            else if (e.modifiers & Qt.AltModifier && e.key === Qt.Key_Down) { Queue.move(index, index + 1); e.accepted = true }
            else if (e.key === Qt.Key_Delete) { Queue.remove(index); e.accepted = true }
        }

        background: Rectangle {
            radius: 10
            color: row.isCurrent ? Theme.surfaceRaised : row.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
            Rectangle { visible: row.isCurrent; width: 3; height: parent.height; radius: 1.5; color: Theme.accent }
            FocusRing { target: row; radius_: 10 }
        }
        contentItem: RowLayout {
            spacing: 12
            Item {
                Layout.preferredWidth: 22
                Layout.fillHeight: true
                PulseIcon { anchors.centerIn: parent; visible: row.isCurrent; name: "meter"; size: 16; color: Theme.accent }
                Label { anchors.centerIn: parent; visible: !row.isCurrent; text: row.index + 1; role: "meta"; secondary: true }
            }
            MediaThumb {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 36
                radius: 6
                source: row.url
                audio: row.isAudio
                stream: !row.url.toString().startsWith("file:")
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: row.title; font.weight: Font.DemiBold; color: row.isCurrent ? Theme.accentText : Theme.text }
                Label {
                    Layout.fillWidth: true
                    role: "meta"
                    color: row.missing ? Theme.errorText : Theme.textSecondary
                    text: row.missing ? qsTr("File not found") : row.isCurrent ? qsTr("Now playing") : (row.isAudio ? qsTr("Audio") : qsTr("Video"))
                }
            }
            IconButton { iconName: "close"; label: qsTr("Remove from queue"); size: 36; iconSize: 16; variant: "tint"; visible: row.hovered || row.activeFocus; onClicked: Queue.remove(row.index) }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: root.count === 0
        secondary: true
        text: qsTr("The queue is empty. Open files or a folder to fill it.")
    }
}
