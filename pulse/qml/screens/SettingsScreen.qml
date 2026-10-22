import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 10 — Settings. Only preferences wired to real behaviour appear.
T.ScrollView {
    id: root
    property bool compact: false
    property string section: "general"
    readonly property int pad: compact ? 16 : 36
    readonly property bool all: section === "general"
    contentWidth: availableWidth

    readonly property var sections: [
        { id: "general", text: qsTr("General") },
        { id: "playback", text: qsTr("Playback") },
        { id: "appearance", text: qsTr("Appearance") },
        { id: "shortcuts", text: qsTr("Shortcuts") },
        { id: "advanced", text: qsTr("Advanced") },
        { id: "about", text: qsTr("About") }
    ]

    ColumnLayout {
        width: root.availableWidth
        spacing: 18

        PageBanner {
            Layout.fillWidth: true
            compact: root.compact
            title: qsTr("Settings")
            subtitle: qsTr("Customize your media experience.")
        }

        // Tabs with ember underline (10).
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            spacing: 6
            Repeater {
                model: root.sections
                delegate: T.AbstractButton {
                    id: tab
                    required property var modelData
                    readonly property bool on: root.section === modelData.id
                    height: 44
                    width: label.implicitWidth + 28
                    focusPolicy: Qt.StrongFocus
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.text
                    Accessible.selected: on
                    onClicked: root.section = modelData.id
                    contentItem: Text {
                        id: label
                        text: tab.modelData.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: tab.on ? Theme.text : tab.hovered ? Theme.text : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.weight: tab.on ? Font.DemiBold : Font.Medium
                    }
                    background: Item {
                        Rectangle { visible: tab.on; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width - 8; height: 3; radius: 1.5; color: Theme.accent
                            AccentGlow { strength: 0.6; glowRadius: 6 } }
                        FocusRing { target: tab }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.bottomMargin: 32
            columns: root.compact || !root.all ? 1 : 2
            columnSpacing: 18
            rowSpacing: 18

            SettingsCard {
                visible: root.all
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                iconName: "settings"
                title: qsTr("App Preferences")
                description: qsTr("General application settings and behavior.")
                SettingRow { label: qsTr("Keep a list of recent files"); hint: qsTr("Shown on Home. Stored only on this device.")
                    PulseSwitch { checked: Prefs.keepRecent; onToggled: { Prefs.keepRecent = checked; Recent.enabled = checked } } }
                SettingRow { label: qsTr("Use system window frame"); hint: qsTr("Instead of the Pulse title bar. Applies after restart.")
                    PulseSwitch { checked: Prefs.useSystemFrame; onToggled: Prefs.useSystemFrame = checked } }
            }

            SettingsCard {
                visible: root.all || root.section === "playback"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                iconName: "play-circle"
                title: qsTr("Playback Settings")
                description: qsTr("Control how media is played.")
                SettingRow { label: qsTr("Hardware Acceleration"); hint: qsTr("Use the GPU for better performance. Applies after restart.")
                    PulseSwitch { checked: Prefs.hardwareDecoding; onToggled: Prefs.hardwareDecoding = checked } }
                SettingRow { label: qsTr("Remember Playback Position"); hint: qsTr("Resume from where you left off.")
                    PulseSwitch { checked: Prefs.resumePlayback; onToggled: Prefs.resumePlayback = checked } }
                SettingRow { label: qsTr("Play Next Automatically"); hint: qsTr("Continue through the queue or folder.")
                    PulseSwitch { checked: Prefs.autoplayNext; onToggled: Prefs.autoplayNext = checked } }
                SettingRow { label: qsTr("Seek Step")
                    Segmented { width: 200; model: [{ text: "5 s", value: 5000 }, { text: "10 s", value: 10000 }, { text: "30 s", value: 30000 }]; value: Prefs.seekStepMs; onActivated: (v) => Prefs.seekStepMs = v } }
                SettingRow { label: qsTr("Hide Controls After")
                    Segmented { width: 200; model: [{ text: "2 s", value: 2000 }, { text: "3 s", value: 3000 }, { text: "5 s", value: 5000 }]; value: Prefs.controlsHideMs; onActivated: (v) => Prefs.controlsHideMs = v } }
            }

            SettingsCard {
                visible: root.all || root.section === "appearance"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                iconName: "palette"
                title: qsTr("Appearance")
                description: qsTr("Customize the look and feel of Pulse.")
                SettingRow {
                    label: qsTr("Theme")
                    hint: qsTr("Light and System arrive once fully designed.")
                    Repeater {
                        model: [{ t: qsTr("Dark"), on: true }, { t: qsTr("Light"), on: false }, { t: qsTr("System"), on: false }]
                        delegate: Rectangle {
                            required property var modelData
                            width: 78; height: 56; radius: 10
                            color: modelData.on ? Qt.rgba(1, 0.416, 0.157, 0.12) : Qt.rgba(1, 1, 1, 0.03)
                            border.width: modelData.on ? 1.5 : 1
                            border.color: modelData.on ? Theme.accent : Theme.glassBorder
                            opacity: modelData.on ? 1 : 0.45
                            Accessible.role: Accessible.RadioButton
                            Accessible.name: modelData.t
                            Accessible.checked: modelData.on
                            Text { anchors.centerIn: parent; text: parent.modelData.t; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                        }
                    }
                }
                SettingRow { label: qsTr("Show Background Art"); hint: qsTr("Media artwork behind the audio player.")
                    PulseSwitch { checked: Prefs.artworkBackground; onToggled: Prefs.artworkBackground = checked } }
                SettingRow { label: qsTr("Reduce Motion"); hint: qsTr("Turns off embers, pulse bars and other animation.")
                    PulseSwitch { checked: Prefs.reduceMotion; onToggled: Prefs.reduceMotion = checked } }
            }

            SettingsCard {
                visible: root.all || root.section === "advanced"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                iconName: "sliders-h"
                title: qsTr("Advanced")
                description: qsTr("Advanced settings for power users.")
                SettingRow { label: qsTr("Clear Thumbnail Cache"); hint: qsTr("Frames are regenerated from your files when needed.")
                    PulseButton { text: qsTr("Clear Now"); implicitHeight: 38; onClicked: MediaInput.clearThumbnailCache() } }
                SettingRow { label: qsTr("Reset Settings"); hint: qsTr("Restore all settings to default. Recent files are kept.")
                    PulseButton { variant: "danger"; text: qsTr("Reset"); implicitHeight: 38; onClicked: Prefs.resetAll() } }
            }

            SettingsCard {
                visible: root.section === "shortcuts" || root.all
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                iconName: "keyboard"
                title: qsTr("Keyboard Shortcuts")
                description: qsTr("Every playback control has a key.")
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 10
                    Repeater {
                        model: [
                            [qsTr("Play / pause"), "Space"], [qsTr("Seek"), "← / →"], [qsTr("Volume"), "↑ / ↓"],
                            [qsTr("Fullscreen"), "F"], [qsTr("Mute"), "M"], [qsTr("Subtitles"), "V"], [qsTr("Audio track"), "B"],
                            [qsTr("Next / previous"), "N / P"], [qsTr("Speed"), "[ / ]"], [qsTr("Subtitle delay"), "G / H"],
                            [qsTr("Screenshot"), "S"], [qsTr("Playback tools"), "T"], [qsTr("Command palette"), "Ctrl K"]]
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Label { Layout.fillWidth: true; color: Theme.textEmphasis; text: modelData[0] }
                            Kbd { text: modelData[1] }
                        }
                    }
                }
            }

            SettingsCard {
                visible: root.section === "about" || root.all
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                iconName: "info"
                title: qsTr("About Pulse")
                description: qsTr("Play anything. Feel more.")
                SettingRow { label: qsTr("Version"); Label { secondary: true; text: "Pulse " + AppInfo.version } }
                SettingRow { label: qsTr("Playback engine"); hint: qsTr("Built from upstream VLC sources, unmodified."); Label { secondary: true; text: "libVLC " + Engine.coreVersion } }
                SettingRow { label: qsTr("License"); hint: qsTr("Free software under the GNU GPL, version 2 or later.")
                    PulseButton { text: qsTr("Source code"); implicitHeight: 38; onClicked: Qt.openUrlExternally("https://github.com/Mo3bdlaa/Pulse-Media-Player") } }
                Label { Layout.fillWidth: true; role: "meta"; secondary: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: qsTr("Pulse is an independent project, not affiliated with or endorsed by VideoLAN. Playback is powered by libVLC, © VideoLAN and contributors.") }
            }
        }
    }
}
