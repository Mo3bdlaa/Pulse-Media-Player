import QtQuick
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 04 — Playback Queue.
Item {
    id: root
    property bool compact: false
    signal saveRequested()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 16 : 40
        anchors.topMargin: root.compact ? 16 : 32
        spacing: 20

        Flow {
            Layout.fillWidth: true
            spacing: 16
            ColumnLayout {
                width: Math.min(implicitWidth, root.width)
                Label { role: "title"; text: qsTr("Playback Queue"); Accessible.role: Accessible.Heading }
                Label { role: "body"; secondary: true; text: qsTr("%n item(s)", "", Queue.count) }
            }
            Row {
                spacing: 8
                PulseButton {
                    text: qsTr("Shuffle"); iconName: "shuffle"; implicitHeight: 40
                    active: Queue.shuffle; onClicked: Queue.shuffle = !Queue.shuffle
                    Accessible.checkable: true; Accessible.checked: Queue.shuffle
                }
                PulseButton {
                    implicitHeight: 40
                    iconName: Queue.repeat === 2 ? "repeat-one" : "repeat"
                    active: Queue.repeat !== 0
                    text: Queue.repeat === 0 ? qsTr("Repeat off") : Queue.repeat === 1 ? qsTr("Repeat all") : qsTr("Repeat one")
                    onClicked: Queue.cycleRepeat()
                }
                PulseButton { text: qsTr("Clear queue"); variant: "quiet"; implicitHeight: 40; enabled: Queue.count > 0; onClicked: Queue.clear() }
            }
        }
        QueueList { Layout.fillWidth: true; Layout.fillHeight: true }
        Label { Layout.fillWidth: true; role: "meta"; secondary: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: qsTr("Clearing or removing items never deletes files. Press Alt + ↑/↓ to reorder, Delete to remove.") }
    }
}
