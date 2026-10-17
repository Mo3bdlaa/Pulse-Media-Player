import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Dialogs
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 11 — Convert & Export. Makes a copy in another format; the original is
// never changed (unless the user opts to move it to the trash afterwards).
T.ScrollView {
    id: root
    property bool compact: false
    property string tab: "convert"
    readonly property int pad: compact ? 16 : 32
    readonly property bool twoColumns: !compact && availableWidth >= 980
    signal play(url url)
    signal toast(string message)
    contentWidth: availableWidth
    T.ScrollBar.horizontal.policy: T.ScrollBar.AlwaysOff

    function addFiles(urls) {
        const n = Converter.addUrls(urls)
        root.toast(n === 0 ? qsTr("Nothing to convert there") : n === 1 ? qsTr("Added 1 file") : qsTr("Added %1 files").arg(n))
    }

    FileDialog {
        id: browse
        title: qsTr("Choose files to convert")
        fileMode: FileDialog.OpenFiles
        onAccepted: root.addFiles(selectedFiles)
    }

    ColumnLayout {
        width: root.availableWidth
        spacing: 18

        PageBanner {
            Layout.fillWidth: true
            compact: root.compact
            title: qsTr("Convert")
            subtitle: qsTr("Convert your media to different formats for any device.")
            PulseButton { visible: !root.compact; variant: "primary"; iconName: "plus"; text: qsTr("Add Files"); onClicked: browse.open() }
        }

        UnderlineTabs {
            Layout.leftMargin: root.pad
            boxed: !root.compact
            value: root.tab
            model: [
                { value: "convert", text: qsTr("Convert") },
                { value: "queue", text: qsTr("Queue (%1)").arg(Converter.active.count) },
                { value: "completed", text: qsTr("Completed (%1)").arg(Converter.completed.count) }
            ]
            onActivated: (v) => root.tab = v
        }

        // ------------------------------------------------------- Convert tab
        GridLayout {
            visible: root.tab === "convert"
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            columns: root.twoColumns ? 2 : 1
            columnSpacing: 18
            rowSpacing: 18

            // Drop zone (the window-wide drop target adds files while this page is open).
            Item {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: root.twoColumns
                implicitHeight: dropCol.implicitHeight + 56
                DashedFrame { anchors.fill: parent; radius: 16 }
                Column {
                    id: dropCol
                    anchors.centerIn: parent
                    width: parent.width - 32
                    spacing: 10
                    PulseIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "cloud-upload"; size: 46; color: Theme.text }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.compact ? qsTr("Tap to select files") : qsTr("Drag & drop media files here"); font.pixelSize: 16; font.weight: Font.Bold }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; role: "meta"; secondary: true; text: root.compact ? qsTr("or choose from this device") : qsTr("or click to browse files") }
                    Item { width: 1; height: 4 }
                    PulseButton { anchors.horizontalCenter: parent.horizontalCenter; variant: "primary"; iconName: "folder"; text: qsTr("Browse Files"); onClicked: browse.open() }
                    Item { width: 1; height: 4 }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(implicitWidth, parent.width); role: "meta"; secondary: true
                        text: qsTr("Supports: MP4, MKV, AVI, MOV, FLV, WMV, and more…") }
                }
            }

            // Presets.
            Glass {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                radius: 16
                implicitHeight: presetCol.implicitHeight + 36
                ColumnLayout {
                    id: presetCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 4
                    Label { role: "section"; font.pixelSize: 17; text: qsTr("Conversion Presets") }
                    Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; role: "meta"; secondary: true; font.pixelSize: 13; text: qsTr("New files use the selected preset; change any file below.") }
                    Grid {
                        id: presetGrid
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        columns: width < 500 ? 2 : 3
                        spacing: 10
                        Repeater {
                            model: Converter.presets
                            delegate: PresetTile {
                                required property var modelData
                                width: (presetGrid.width - (presetGrid.columns - 1) * presetGrid.spacing) / presetGrid.columns
                                text: modelData.name
                                detail: modelData.detail
                                iconName: modelData.icon
                                selected: Converter.preset === modelData.id
                                onClicked: Converter.preset = modelData.id
                            }
                        }
                    }
                }
            }
        }

        QueueCard {
            visible: root.tab === "convert"
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
        }

        // Settings (11, bottom card).
        Glass {
            visible: root.tab === "convert"
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.bottomMargin: 28
            radius: 16
            implicitHeight: settingsGrid.implicitHeight + 40
            GridLayout {
                id: settingsGrid
                anchors.fill: parent
                anchors.margins: 20
                columns: root.twoColumns ? 2 : 1
                columnSpacing: 32
                rowSpacing: 16
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    RowLayout {
                        spacing: 12
                        PulseIcon { name: "settings"; size: 24; color: Theme.text }
                        Label { role: "section"; font.pixelSize: 17; text: qsTr("Conversion Settings") }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.compact ? 1 : 3
                        columnSpacing: 14
                        rowSpacing: 10
                        component Field: ColumnLayout {
                            property alias label: l.text
                            default property alias control: slot.data
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 6
                            Label { id: l; role: "meta"; secondary: true }
                            Item { id: slot; Layout.fillWidth: true; implicitHeight: 38 }
                        }
                        Field {
                            label: qsTr("Video Codec (Custom)")
                            Dropdown { width: parent.width; model: [{ text: qsTr("H.264 (AVC)"), value: "h264" }, { text: qsTr("H.265 (HEVC)"), value: "hevc" }]
                                value: Converter.videoCodec; onPicked: (v) => Converter.videoCodec = v; Accessible.name: qsTr("Video codec") }
                        }
                        Field {
                            label: qsTr("Audio Codec (Custom)")
                            Dropdown { width: parent.width; model: [{ text: "AAC", value: "aac" }, { text: "MP3", value: "mp3" }]
                                value: Converter.audioCodec; onPicked: (v) => Converter.audioCodec = v; Accessible.name: qsTr("Audio codec") }
                        }
                        Field {
                            label: qsTr("Quality")
                            Dropdown { width: parent.width
                                model: [{ text: qsTr("High (Recommended)"), value: "high" }, { text: qsTr("Medium"), value: "medium" }, { text: qsTr("Low (smaller files)"), value: "low" }]
                                value: Converter.quality; onPicked: (v) => Converter.quality = v; Accessible.name: qsTr("Quality") }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: !root.twoColumns
                    Layout.preferredWidth: root.twoColumns ? 340 : -1
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 10
                    SettingRow { label: qsTr("Keep Original Audio"); hint: qsTr("Copies the audio track as it is")
                        PulseSwitch { checked: Converter.keepOriginalAudio; onToggled: Converter.keepOriginalAudio = checked; Accessible.name: qsTr("Keep original audio") } }
                    SettingRow { label: qsTr("Enable Hardware Decoding")
                        PulseSwitch { checked: Converter.hardwareDecoding; onToggled: Converter.hardwareDecoding = checked; Accessible.name: qsTr("Hardware decoding") } }
                    SettingRow { label: qsTr("Move Source to Trash After Conversion"); hint: qsTr("Only after the new file is written")
                        PulseSwitch { checked: Converter.trashSource; onToggled: Converter.trashSource = checked; Accessible.name: qsTr("Move source to trash after conversion") } }
                }
            }
        }

        // ------------------------------------------------------- Queue tab
        QueueCard {
            visible: root.tab === "queue"
            scrolls: true
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.bottomMargin: 28
            Layout.preferredHeight: Math.max(320, root.availableHeight - 290)
        }

        // ------------------------------------------------------- Completed tab
        CompletedList {
            visible: root.tab === "completed"
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.bottomMargin: 28
            Layout.preferredHeight: Math.max(320, root.availableHeight - 290)
            onPlay: (url) => root.play(url)
        }
    }
}
