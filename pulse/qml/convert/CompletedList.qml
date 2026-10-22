import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 11 — finished, failed and cancelled conversions.
Glass {
    id: root
    signal play(url url)
    radius: 16

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; role: "section"; font.pixelSize: 17; text: qsTr("Completed (%1)").arg(Converter.completed.count) }
            PulseButton { visible: Converter.completed.count > 0; variant: "quiet"; text: qsTr("Clear History"); onClicked: Converter.clearCompleted() }
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: Converter.completed
            T.ScrollBar.vertical: T.ScrollBar {}
            footer: Item {
                width: list.width
                height: Converter.completed.count === 0 ? 120 : 8
                Label { visible: Converter.completed.count === 0; anchors.centerIn: parent; secondary: true; text: qsTr("Finished conversions appear here.") }
            }
            delegate: Item {
                id: done
                required property int index
                required property url url
                required property string name
                required property string status
                required property string error
                required property url output
                required property string preset
                required property var finished
                readonly property bool ok: status === "done"
                readonly property bool narrow: list.width < 520
                width: list.width
                height: 84
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.glassBorder }
                MediaThumb {
                    id: th
                    y: 10
                    width: done.narrow ? 64 : 96; height: done.narrow ? 42 : 62; radius: 9
                    source: done.ok ? done.output : done.url
                    audio: MediaInput.isAudio(done.ok ? done.output : done.url)
                }
                Column {
                    anchors.left: th.right
                    anchors.leftMargin: 14
                    anchors.right: actions.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Label { width: parent.width; text: done.ok ? MediaInput.displayName(done.output) : done.name; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Row {
                        spacing: 6
                        PulseIcon { anchors.verticalCenter: parent.verticalCenter; size: 14; name: done.ok ? "check" : "alert"; color: done.ok ? Theme.success : done.status === "cancelled" ? Theme.textSecondary : Theme.errorText }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            role: "meta"
                            color: done.ok ? Theme.textEmphasis : done.status === "cancelled" ? Theme.textSecondary : Theme.errorText
                            text: done.ok ? Converter.presetName(done.preset) + " · " + MediaInput.describe(done.output) + " · " + MediaInput.relativeTime(done.finished)
                                : done.status === "cancelled" ? qsTr("Cancelled") : done.error
                        }
                    }
                }
                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    IconButton { visible: done.ok; variant: "square"; iconName: "play"; label: qsTr("Play %1").arg(MediaInput.displayName(done.output)); onClicked: root.play(done.output) }
                    IconButton { visible: done.ok && !done.narrow; variant: "square"; iconName: "folder"; label: qsTr("Show in Folder"); onClicked: Qt.openUrlExternally(MediaInput.folderOf(done.output)) }
                    IconButton { visible: !done.ok; variant: "square"; iconName: "refresh"; label: qsTr("Try Again"); onClicked: Converter.retry(done.index) }
                    IconButton { iconName: "close"; label: qsTr("Remove from history"); onClicked: Converter.removeCompleted(done.index) }
                }
            }
        }
    }
}
