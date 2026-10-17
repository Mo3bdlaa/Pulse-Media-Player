import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 10 — Settings. Only preferences that are wired to real behaviour appear.
Item {
    id: root
    property bool compact: false
    property string section: "general"

    readonly property var sections: [
        { id: "general", text: qsTr("General") },
        { id: "playback", text: qsTr("Playback") },
        { id: "av", text: qsTr("Audio & Video") },
        { id: "appearance", text: qsTr("Appearance") },
        { id: "shortcuts", text: qsTr("Shortcuts") },
        { id: "advanced", text: qsTr("Advanced") },
        { id: "about", text: qsTr("About") }
    ]

    component Row_: Item {
        id: r
        property string label
        property string description
        default property alias control: slot.data
        property bool first: false
        Layout.fillWidth: true
        implicitHeight: Math.max(64, textCol.implicitHeight + 32)
        Rectangle { visible: !r.first; width: parent.width; height: 1; color: Theme.border }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 24
            ColumnLayout {
                id: textCol
                Layout.fillWidth: true
                spacing: 2
                Label { Layout.fillWidth: true; text: r.label; font.weight: Font.DemiBold }
                Label { Layout.fillWidth: true; visible: r.description !== ""; role: "meta"; secondary: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; text: r.description }
            }
            Row { id: slot }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 16 : 40
        anchors.topMargin: root.compact ? 16 : 32
        spacing: 28

        ColumnLayout {
            visible: !root.compact
            Layout.fillWidth: false
            Layout.preferredWidth: 200
            Layout.maximumWidth: 200
            Layout.alignment: Qt.AlignTop
            spacing: 2
            Label { role: "title"; text: qsTr("Settings"); Layout.bottomMargin: 20; Accessible.role: Accessible.Heading }
            Repeater {
                model: root.sections
                delegate: NavItem {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 40
                    text: modelData.text
                    selected: root.section === modelData.id
                    onClicked: root.section = modelData.id
                }
            }
        }

        T.ScrollView {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.fillHeight: true
            contentWidth: availableWidth
            ColumnLayout {
                width: parent.width
                spacing: 16
                Segmented {
                    visible: root.compact
                    Layout.fillWidth: true
                    model: root.sections.map(s => ({ text: s.text, value: s.id }))
                    value: root.section
                    onActivated: (v) => root.section = v
                }
                Label { role: "section"; text: root.sections.find(s => s.id === root.section).text; Layout.topMargin: root.compact ? 0 : 66 }
                Card {
                    Layout.fillWidth: true
                    radius: Theme.radiusCard
                    implicitHeight: rows.implicitHeight
                    ColumnLayout {
                        id: rows
                        width: parent.width
                        spacing: 0

                        // General
                        Row_ { visible: root.section === "general"; first: true; label: qsTr("Keep a list of recent files"); description: qsTr("Shown on Home. Stored only on this device.")
                            PulseSwitch { checked: Prefs.keepRecent; onToggled: { Prefs.keepRecent = checked; Recent.enabled = checked } } }
                        Row_ { visible: root.section === "general"; label: qsTr("Use system window frame"); description: qsTr("Instead of the Pulse title bar. Applies after restart.")
                            PulseSwitch { checked: Prefs.useSystemFrame; onToggled: Prefs.useSystemFrame = checked } }

                        // Playback
                        Row_ { visible: root.section === "playback"; first: true; label: qsTr("Resume where I left off"); description: qsTr("For files longer than 5 minutes. A Start over action is always offered.")
                            PulseSwitch { checked: Prefs.resumePlayback; onToggled: Prefs.resumePlayback = checked } }
                        Row_ { visible: root.section === "playback"; label: qsTr("Play the next item automatically"); description: qsTr("Continue through the queue or folder.")
                            PulseSwitch { checked: Prefs.autoplayNext; onToggled: Prefs.autoplayNext = checked } }
                        Row_ { visible: root.section === "playback"; label: qsTr("Seek step"); description: qsTr("Arrow keys and the skip buttons.")
                            Segmented { width: 220; model: [{ text: "5 s", value: 5000 }, { text: "10 s", value: 10000 }, { text: "30 s", value: 30000 }]; value: Prefs.seekStepMs; onActivated: (v) => Prefs.seekStepMs = v } }
                        Row_ { visible: root.section === "playback"; label: qsTr("Hide controls after"); description: qsTr("Controls stay while a menu or keyboard focus is active.")
                            Segmented { width: 220; model: [{ text: "2 s", value: 2000 }, { text: "3 s", value: 3000 }, { text: "5 s", value: 5000 }]; value: Prefs.controlsHideMs; onActivated: (v) => Prefs.controlsHideMs = v } }

                        // Audio & Video
                        Row_ { visible: root.section === "av"; first: true; label: qsTr("Hardware decoding"); description: qsTr("Uses the GPU when the format allows. Applies after restart.")
                            PulseSwitch { checked: Prefs.hardwareDecoding; onToggled: Prefs.hardwareDecoding = checked } }

                        // Appearance
                        Row_ { visible: root.section === "appearance"; first: true; label: qsTr("Theme"); description: qsTr("Signal Ember dark. Light and system themes will follow once fully designed.")
                            Label { secondary: true; text: qsTr("Dark") } }
                        Row_ { visible: root.section === "appearance"; label: qsTr("Reduce motion"); description: qsTr("Turns off decorative animation.")
                            PulseSwitch { checked: Prefs.reduceMotion; onToggled: Prefs.reduceMotion = checked } }

                        // Shortcuts (read-only list for now)
                        Repeater {
                            model: root.section === "shortcuts" ? [
                                [qsTr("Play / pause"), "Space"], [qsTr("Seek back / forward"), "← / →"], [qsTr("Volume"), "↑ / ↓"],
                                [qsTr("Fullscreen"), "F"], [qsTr("Mute"), "M"], [qsTr("Cycle subtitles"), "V"], [qsTr("Cycle audio track"), "B"],
                                [qsTr("Next / previous"), "N / P"], [qsTr("Speed down / up"), "[ / ]"], [qsTr("Subtitle delay"), "G / H"],
                                [qsTr("Screenshot"), "S"], [qsTr("Playback tools"), "T"], [qsTr("Command palette"), "Ctrl K"]] : []
                            delegate: Row_ {
                                required property var modelData
                                required property int index
                                first: index === 0
                                label: modelData[0]
                                Kbd { text: modelData[1] }
                            }
                        }

                        // Advanced
                        Row_ { visible: root.section === "advanced"; first: true; label: qsTr("Reset all settings"); description: qsTr("Recent files are kept.")
                            PulseButton { variant: "danger"; text: qsTr("Reset"); implicitHeight: 36; onClicked: Prefs.resetAll() } }

                        // About
                        Row_ { visible: root.section === "about"; first: true; label: qsTr("Version"); Label { secondary: true; text: "Pulse " + AppInfo.version } }
                        Row_ { visible: root.section === "about"; label: qsTr("Playback engine"); description: qsTr("Built from upstream VLC sources, unmodified.")
                            Label { secondary: true; text: "libVLC " + Engine.coreVersion } }
                        Row_ { visible: root.section === "about"; label: qsTr("License"); description: qsTr("Pulse is free software under the GNU GPL, version 2 or later.")
                            PulseButton { text: qsTr("Source code"); implicitHeight: 36; onClicked: Qt.openUrlExternally("https://github.com/Mo3bdlaa/Pulse-Media-Player") } }
                        Row_ { visible: root.section === "about"; label: qsTr("Credits"); description: qsTr("Pulse is an independent project. It is not affiliated with or endorsed by VideoLAN. Playback is powered by libVLC, © VideoLAN and contributors.") }
                    }
                }
            }
        }
    }
}
