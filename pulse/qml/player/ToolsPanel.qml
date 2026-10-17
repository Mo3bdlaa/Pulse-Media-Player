import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import QtQuick.Dialogs
import Pulse
import Pulse.Core

// 05 — Playback Tools. Every control maps to a real engine call.
Rectangle {
    id: root
    property string tab: "video"
    property bool floating: false
    signal closeRequested()
    signal toast(string message)

    readonly property var tabs: [
        { value: "video", text: qsTr("Video"), icon: "monitor" },
        { value: "audio", text: qsTr("Audio"), icon: "volume" },
        { value: "subs", text: qsTr("Subtitles"), icon: "subtitles" },
        { value: "playback", text: qsTr("Playback"), icon: "gauge" },
        { value: "info", text: qsTr("Advanced"), icon: "settings" }
    ]

    color: floating ? Qt.rgba(0.07, 0.075, 0.095, 0.95) : "transparent"
    radius: floating ? 16 : 0
    border.width: floating ? 1 : 0
    border.color: Qt.rgba(1, 0.416, 0.157, 0.35)
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Playback tools")

    component Section: Label { role: "section"; font.pixelSize: 14; Layout.topMargin: 6 }
    component SliderRow: RowLayout {
        id: sr
        property string text
        property real from: -100
        property real to: 100
        property real value
        property bool centered: true
        property string suffix
        signal moved(real value)
        Layout.fillWidth: true
        spacing: 12
        Label { Layout.preferredWidth: 92; text: sr.text; color: Theme.textEmphasis; font.pixelSize: 13 }
        PulseSlider {
            Layout.fillWidth: true
            from: sr.from; to: sr.to; value: sr.value; stepSize: 1; centered: sr.centered
            Accessible.name: sr.text
            onMoved: sr.moved(value)
        }
        Label { Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight; text: Math.round(sr.value) + sr.suffix; font.weight: Font.DemiBold }
    }
    component Stepper: RowLayout {
        id: st
        property string text
        property real value
        property real step: 50
        signal changed(real value)
        Layout.fillWidth: true
        spacing: 8
        Label { Layout.preferredWidth: 92; text: st.text; color: Theme.textEmphasis; font.pixelSize: 13 }
        PulseButton { text: "−"; implicitWidth: 40; implicitHeight: 40; leftPadding: 0; rightPadding: 0; Accessible.name: qsTr("Decrease %1").arg(st.text); onClicked: st.changed(st.value - st.step) }
        Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; font.weight: Font.DemiBold
            text: (st.value > 0 ? "+" : "") + (st.value / 1000).toFixed(3) + " s" }
        PulseButton { text: "+"; implicitWidth: 40; implicitHeight: 40; leftPadding: 0; rightPadding: 0; Accessible.name: qsTr("Increase %1").arg(st.text); onClicked: st.changed(st.value + st.step) }
    }
    component TrackChoice: Column {
        id: tc
        property var tracks: []
        property string current
        property bool allowOff: false
        signal pick(string id)
        signal off()
        Layout.fillWidth: true
        spacing: 4
        T.RadioButton {
            visible: tc.allowOff
            width: tc.width
            checked: tc.current === ""
            text: qsTr("Off")
            onClicked: tc.off()
            indicator: Item {}
            contentItem: Label { text: parent.text; leftPadding: 4 }
            background: Rectangle { implicitHeight: 48; radius: 10; color: parent.checked ? Qt.rgba(1, 0.416, 0.157, 0.1) : "transparent"; border.width: 1; border.color: parent.checked ? Theme.accent : Theme.border; FocusRing { target: parent.parent; radius_: 10 } }
            leftPadding: 14
        }
        Repeater {
            model: tc.tracks
            delegate: T.RadioButton {
                id: rb
                required property var modelData
                width: tc.width
                checked: modelData.selected
                leftPadding: 14
                rightPadding: 14
                onClicked: tc.pick(modelData.id)
                Accessible.name: modelData.name
                indicator: Item {}
                contentItem: RowLayout {
                    Label { Layout.fillWidth: true; text: rb.modelData.name; font.weight: rb.checked ? Font.DemiBold : Font.Medium }
                    Label { role: "meta"; secondary: true; text: rb.modelData.codecName || rb.modelData.codec }
                }
                background: Rectangle { implicitHeight: 48; radius: 10; color: rb.checked ? Qt.rgba(1, 0.416, 0.157, 0.1) : "transparent"; border.width: 1; border.color: rb.checked ? Theme.accent : Theme.border; FocusRing { target: rb; radius_: 10 } }
            }
        }
        Label { visible: tc.tracks.length === 0; secondary: true; text: qsTr("None in this media") }
    }

    FileDialog {
        id: subDialog
        title: qsTr("Load subtitle file")
        nameFilters: [qsTr("Subtitles (*.srt *.ass *.ssa *.vtt *.sub *.idx *.ttml)"), qsTr("All files (*)")]
        onAccepted: root.toast(Player.addSubtitleFile(selectedFile) ? qsTr("Subtitle added") : qsTr("Couldn’t load that subtitle file"))
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Vertical tab rail (floating card).
        Rectangle {
            visible: root.floating
            Layout.fillHeight: true
            Layout.preferredWidth: 92
            color: Qt.rgba(1, 1, 1, 0.025)
            radius: root.radius
            Column {
                anchors.fill: parent
                anchors.topMargin: 14
                spacing: 6
                Repeater {
                    model: root.tabs
                    delegate: T.AbstractButton {
                        id: railTab
                        required property var modelData
                        readonly property bool on: root.tab === modelData.value
                        x: 10
                        width: 72
                        height: 64
                        focusPolicy: Qt.StrongFocus
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.text
                        Accessible.selected: on
                        onClicked: root.tab = modelData.value
                        background: Rectangle {
                            radius: 10
                            color: railTab.hovered && !railTab.on ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                visible: railTab.on
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Theme.accentBright }
                                    GradientStop { position: 1; color: Theme.accentDeep }
                                }
                                AccentGlow { strength: 0.6; glowRadius: 10 }
                            }
                            FocusRing { target: railTab; radius_: 10 }
                        }
                        contentItem: Column {
                            spacing: 5
                            topPadding: 10
                            PulseIcon { anchors.horizontalCenter: parent.horizontalCenter; name: railTab.modelData.icon; size: 22; color: railTab.on ? Theme.textOnAccent : Theme.textEmphasis }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: railTab.modelData.text; color: railTab.on ? Theme.textOnAccent : Theme.textEmphasis; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: railTab.on ? Font.Bold : Font.Medium }
                        }
                    }
                }
            }
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.06) }
        }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            Layout.bottomMargin: 12
            spacing: 12
            PulseIcon { visible: !root.floating; name: "tools"; color: Theme.accent; size: 22 }
            Label { Layout.fillWidth: true; role: "section"; font.pixelSize: 18; text: qsTr("Playback Tools") }
            IconButton { iconName: "close"; label: qsTr("Close playback tools"); size: 40; iconSize: 18; variant: "tint"; onClicked: root.closeRequested() }
        }
        Segmented {
            visible: !root.floating
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            model: root.tabs
            value: root.tab
            onActivated: (v) => root.tab = v
        }
        Rectangle { visible: !root.floating; Layout.fillWidth: true; Layout.topMargin: 12; height: 1; color: Theme.border }

        T.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            ColumnLayout {
                width: parent.width - 40
                x: 20
                spacing: 14

                Item { Layout.preferredHeight: 4 }

                // --- Video ---
                ColumnLayout {
                    visible: root.tab === "video"
                    Layout.fillWidth: true
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        Section { Layout.fillWidth: true; text: qsTr("Video Adjustments") }
                        Label { text: qsTr("Reset"); color: Theme.accentText; font.pixelSize: 13; font.weight: Font.DemiBold
                            TapHandler { onTapped: Player.resetPicture() } }
                    }
                    SliderRow { text: qsTr("Brightness"); value: Player.brightness; onMoved: (v) => Player.brightness = v }
                    SliderRow { text: qsTr("Contrast"); value: Player.contrast; onMoved: (v) => Player.contrast = v }
                    SliderRow { text: qsTr("Saturation"); value: Player.saturation; onMoved: (v) => Player.saturation = v }
                    SliderRow { text: qsTr("Hue"); from: -180; to: 180; suffix: "°"; value: Player.hue; onMoved: (v) => Player.hue = v }
                    SliderRow { text: qsTr("Gamma"); value: Player.gamma; onMoved: (v) => Player.gamma = v }
                    Section { text: qsTr("Aspect ratio") }
                    Segmented {
                        Layout.fillWidth: true
                        model: [{ text: qsTr("Original"), value: "" }, { text: "16:9", value: "16:9" }, { text: "4:3", value: "4:3" }, { text: "21:9", value: "21:9" }, { text: "1:1", value: "1:1" }]
                        value: Player.aspectRatio
                        onActivated: (v) => Player.aspectRatio = v
                    }
                    Section { text: qsTr("Crop") }
                    Segmented {
                        Layout.fillWidth: true
                        model: [{ text: qsTr("None"), value: "" }, { text: "16:9", value: "16:9" }, { text: "2.39:1", value: "239:100" }, { text: "4:3", value: "4:3" }]
                        value: Player.cropRatio
                        onActivated: (v) => Player.cropRatio = v
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Section { Layout.fillWidth: true; text: qsTr("Deinterlace") }
                        Label { secondary: true; font.pixelSize: 12; text: Player.deinterlace === -1 ? qsTr("Auto") : "" }
                        PulseSwitch { checked: Player.deinterlace === 1; onToggled: Player.deinterlace = checked ? 1 : -1; Accessible.name: qsTr("Deinterlace") }
                    }
                }

                // --- Audio ---
                ColumnLayout {
                    visible: root.tab === "audio"
                    Layout.fillWidth: true
                    spacing: 14
                    Section { text: qsTr("Audio track") }
                    TrackChoice { tracks: Player.audioTracks; current: Player.currentAudioTrack; allowOff: true
                        onPick: (id) => Player.selectTrack(1, id); onOff: Player.disableTrack(1) }
                    Stepper { text: qsTr("Audio delay"); value: Player.audioDelay; onChanged: (v) => Player.audioDelay = v }
                    RowLayout {
                        Layout.fillWidth: true
                        Section { Layout.fillWidth: true; text: qsTr("Equalizer") }
                        PulseSwitch { checked: Player.equalizerEnabled; onToggled: Player.equalizerEnabled = checked; Accessible.name: qsTr("Equalizer") }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: Engine.equalizerPresets
                            delegate: PulseButton {
                                required property string modelData
                                required property int index
                                implicitHeight: 32
                                font.pixelSize: 12
                                text: modelData
                                active: Player.equalizerPreset === index
                                onClicked: Player.equalizerPreset = index
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 160
                        radius: 10
                        color: Theme.sunken
                        opacity: Player.equalizerEnabled ? 1 : 0.5
                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            Repeater {
                                model: Engine.equalizerBands
                                delegate: Column {
                                    required property real modelData
                                    required property int index
                                    width: parent.width / Engine.equalizerBands.length
                                    height: parent.height
                                    PulseSlider {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        orientation: Qt.Vertical
                                        height: parent.height - 20
                                        width: 24
                                        from: -20; to: 20; stepSize: 0.5; centered: true
                                        value: Player.equalizerAmps[index] || 0
                                        Accessible.name: qsTr("%1 Hz").arg(Math.round(modelData))
                                        onMoved: Player.setEqualizerAmp(index, value)
                                    }
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        role: "meta"; secondary: true; font.pixelSize: 10
                                        text: modelData >= 1000 ? Math.round(modelData / 1000) + "k" : Math.round(modelData)
                                    }
                                }
                            }
                        }
                    }
                    Section { text: qsTr("Output device") }
                    Column {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                        model: Player.audioDevices
                        delegate: PulseButton {
                            required property var modelData
                            width: parent.width
                            text: modelData.name || modelData.id
                            onClicked: Player.setAudioDevice(modelData.id)
                        }
                        }
                    }
                    Label { visible: Player.audioDevices.length === 0; secondary: true; text: qsTr("System default") }
                }

                // --- Subtitles ---
                ColumnLayout {
                    visible: root.tab === "subs"
                    Layout.fillWidth: true
                    spacing: 14
                    Section { text: qsTr("Subtitle track") }
                    TrackChoice { tracks: Player.subtitleTracks; current: Player.currentSubtitleTrack; allowOff: true
                        onPick: (id) => Player.selectTrack(2, id); onOff: Player.disableTrack(2) }
                    PulseButton { Layout.fillWidth: true; iconName: "plus"; text: qsTr("Load subtitle file…"); onClicked: subDialog.open() }
                    Stepper { text: qsTr("Sync"); step: 100; value: Player.subtitleDelay; onChanged: (v) => Player.subtitleDelay = v }
                    Label { Layout.fillWidth: true; role: "meta"; secondary: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                        text: qsTr("While watching, G and H shift subtitles by 100 ms.") }
                }

                // --- Playback ---
                ColumnLayout {
                    visible: root.tab === "playback"
                    Layout.fillWidth: true
                    spacing: 14
                    Section { text: qsTr("Speed") }
                    Segmented {
                        Layout.fillWidth: true
                        accentSelection: true
                        enabled: Player.rateChangeable
                        model: [{ text: "0.5", value: 0.5 }, { text: "0.75", value: 0.75 }, { text: "1×", value: 1 }, { text: "1.25", value: 1.25 }, { text: "1.5", value: 1.5 }, { text: "2", value: 2 }]
                        value: Math.round(Player.rate * 100) / 100
                        onActivated: (v) => Player.rate = v
                    }
                    Section { text: qsTr("A–B loop") }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        PulseButton { Layout.fillWidth: true; active: Player.loopA >= 0; text: Player.loopA >= 0 ? "A · " + MediaInput.formatTime(Player.loopA) : qsTr("Set A"); onClicked: Player.setLoopA() }
                        PulseButton { Layout.fillWidth: true; active: Player.loopB >= 0; enabled: Player.loopA >= 0; text: Player.loopB >= 0 ? "B · " + MediaInput.formatTime(Player.loopB) : qsTr("Set B"); onClicked: Player.setLoopB() }
                        PulseButton { variant: "quiet"; text: qsTr("Clear"); enabled: Player.loopA >= 0; onClicked: Player.clearLoop() }
                    }
                    Section { text: qsTr("Chapters"); visible: Player.chapters.length > 0 }
                    Column {
                        Layout.fillWidth: true
                        Repeater {
                        model: Player.chapters
                        delegate: T.ItemDelegate {
                            id: ch
                            required property var modelData
                            required property int index
                            width: parent.width
                            implicitHeight: 44
                            onClicked: Player.setChapter(index)
                            contentItem: RowLayout {
                                spacing: 12
                                Label { Layout.preferredWidth: 20; text: ch.index + 1; secondary: true; role: "meta" }
                                Label { Layout.fillWidth: true; text: ch.modelData.name }
                                Label { role: "meta"; secondary: true; text: MediaInput.formatTime(ch.modelData.time) }
                            }
                            background: Rectangle { radius: 10; color: Player.currentChapter === ch.index ? Qt.rgba(1, 0.416, 0.157, 0.1) : ch.hovered ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                                border.width: Player.currentChapter === ch.index ? 1 : 0; border.color: Theme.accent; FocusRing { target: ch; radius_: 10 } }
                        }
                        }
                    }
                    PulseButton {
                        Layout.fillWidth: true
                        iconName: "camera"
                        text: qsTr("Take screenshot")
                        shortcutHint: "S"
                        enabled: Player.hasVideo
                        onClicked: {
                            const path = Player.takeSnapshot(MediaInput.picturesFolder())
                            root.toast(path ? qsTr("Screenshot saved to Pictures") : qsTr("Couldn’t take a screenshot"))
                        }
                    }
                }

                // --- Info ---
                ColumnLayout {
                    visible: root.tab === "info"
                    Layout.fillWidth: true
                    spacing: 10
                    Section { text: qsTr("Stream information") }
                    Column {
                        Layout.fillWidth: true
                        spacing: 8
                        Label { width: parent.width; secondary: true; text: qsTr("Location") }
                        Label { width: parent.width; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone; text: Player.url.toString() }
                        Repeater {
                            model: Player.videoTracks
                            delegate: Label {
                                required property var modelData
                                width: parent.width
                                wrapMode: Text.WordWrap
                                elide: Text.ElideNone
                                text: qsTr("Video") + " · " + (modelData.codecName || modelData.codec) + (modelData.width ? " · " + modelData.width + " × " + modelData.height : "")
                                      + (modelData.frameRate ? " · " + modelData.frameRate.toFixed(3) + " fps" : "")
                            }
                        }
                        Repeater {
                            model: Player.audioTracks
                            delegate: Label {
                                required property var modelData
                                width: parent.width
                                wrapMode: Text.WordWrap
                                elide: Text.ElideNone
                                text: qsTr("Audio") + " · " + modelData.name + " · " + (modelData.codecName || modelData.codec)
                                      + (modelData.sampleRate ? " · " + (modelData.sampleRate / 1000) + " kHz" : "") + (modelData.channels ? " · " + modelData.channels + " ch" : "")
                            }
                        }
                    }
                    Label { Layout.fillWidth: true; role: "meta"; secondary: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                        text: qsTr("Everything here is read from the media itself.") }
                }
                Item { Layout.preferredHeight: 20 }
            }
        }
    }
    }
}
