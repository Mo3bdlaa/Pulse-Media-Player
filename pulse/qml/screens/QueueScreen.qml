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
        spacing: 16

        PageBanner {
            Layout.fillWidth: true
            compact: root.compact
            title: qsTr("Playback Queue")
            subtitle: (Queue.count === 1 ? qsTr("1 item") : qsTr("%1 items").arg(Queue.count))
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: root.compact ? 16 : 36
            Layout.rightMargin: Layout.leftMargin
            spacing: 16
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
        Glass {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: root.compact ? 8 : 36
            Layout.rightMargin: Layout.leftMargin
            radius: 16
            QueueList { anchors.fill: parent; anchors.margins: 10 }
        }
        Label { Layout.fillWidth: true; Layout.leftMargin: root.compact ? 16 : 36; Layout.bottomMargin: 16; role: "meta"; secondary: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
            text: qsTr("Clearing or removing items never deletes files. Press Alt + ↑/↓ to reorder, Delete to remove.") }
    }
}
