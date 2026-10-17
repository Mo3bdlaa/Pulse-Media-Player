import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 11 — one job in the conversion queue.
Item {
    id: row
    required property int index
    required property url url
    required property string name
    required property string detail
    required property string preset
    required property int resolution
    required property string status
    required property real progress
    required property string eta
    readonly property bool converting: status === "converting"
    readonly property bool compact: width < 720
    readonly property var presetModel: Converter.presets.map(p => ({ text: p.name, value: p.id }))
    readonly property var resolutionModel: Converter.resolutions.map(r => ({ text: r.name, value: r.height }))
    implicitHeight: compact ? 150 : 104

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.glassBorder; visible: row.index < Converter.active.count - 1 }

    MediaThumb {
        id: thumb
        x: 0
        y: 12
        width: row.compact ? 88 : 112
        height: row.compact ? 66 : 80
        radius: 10
        source: row.url
        audio: MediaInput.isAudio(row.url)
    }
    ColumnLayout {
        anchors.left: thumb.right
        anchors.leftMargin: 16
        anchors.right: row.compact ? parent.right : controls.left
        anchors.rightMargin: row.compact ? 0 : 20
        y: 12
        spacing: 6
        Label { Layout.fillWidth: true; text: row.name; font.pixelSize: 15; font.weight: Font.Bold }
        Label { Layout.fillWidth: true; role: "meta"; color: Theme.textEmphasis; text: row.detail }
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            height: 4; radius: 2
            color: Qt.rgba(1, 1, 1, 0.1)
            Rectangle {
                width: parent.width * row.progress
                height: parent.height
                radius: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.accentDeep }
                    GradientStop { position: 1; color: Theme.accentBright }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                role: "meta"
                color: row.converting ? Theme.accentText : Theme.textSecondary
                text: row.converting ? qsTr("Converting… %1%").arg(Math.round(row.progress * 100)) : qsTr("Queued")
            }
            Label {
                role: "meta"
                secondary: true
                text: row.converting ? (row.eta !== "" ? qsTr("ETA: %1").arg(row.eta) : qsTr("Estimating…")) : qsTr("Waiting…")
            }
        }
        // Phone: format pickers under the progress.
        RowLayout {
            visible: row.compact
            Layout.fillWidth: true
            spacing: 8
            Dropdown { Layout.fillWidth: true; enabled: !row.converting; model: row.presetModel; value: row.preset; onPicked: (v) => Converter.setJobPreset(row.index, v) }
            Dropdown { implicitWidth: 104; enabled: !row.converting && row.preset !== "mp3"; model: row.resolutionModel; value: row.resolution; onPicked: (v) => Converter.setJobResolution(row.index, v) }
            IconButton { size: 36; iconSize: 16; iconName: "close"; label: qsTr("Remove %1").arg(row.name); onClicked: Converter.removeJob(row.index) }
        }
    }
    Row {
        id: controls
        visible: !row.compact
        anchors.right: parent.right
        y: 12
        spacing: 14
        Column {
            spacing: 6
            Label { role: "meta"; secondary: true; text: qsTr("Output Format") }
            Dropdown { width: 168; enabled: !row.converting; model: row.presetModel; value: row.preset; onPicked: (v) => Converter.setJobPreset(row.index, v)
                Accessible.name: qsTr("Output format for %1").arg(row.name) }
        }
        Column {
            spacing: 6
            Label { role: "meta"; secondary: true; text: qsTr("Resolution") }
            Dropdown { width: 128; enabled: !row.converting && row.preset !== "mp3"; model: row.resolutionModel; value: row.resolution; onPicked: (v) => Converter.setJobResolution(row.index, v)
                Accessible.name: qsTr("Resolution for %1").arg(row.name) }
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 10
            iconName: "close"
            label: row.converting ? qsTr("Cancel %1").arg(row.name) : qsTr("Remove %1").arg(row.name)
            onClicked: Converter.removeJob(row.index)
        }
    }
}
