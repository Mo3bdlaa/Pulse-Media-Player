import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Pulse
import Pulse.Core

// 02 — Video Player (immersive) and 03 — Audio Player (inside the app shell).
Rectangle {
    id: root
    property var window
    property bool compact: false
    property bool fullscreen: false
    property bool toolsOpen: false
    property bool queueOpen: false
    property string toolsTab: "video"
    readonly property bool videoMode: Player.hasVideo
    readonly property bool pinned: toolsOpen || queueOpen || bottomHover.hovered || topHover.hovered
                                   || bottomBar.activeFocus || !Player.playing
    readonly property bool controlsVisible: !videoMode || pinned || hideTimer.running
    readonly property var videoTrack: Player.videoTracks.length ? Player.videoTracks[0] : null

    signal back()
    signal toggleFullscreen()
    signal toast(string message)

    color: videoMode ? "black" : "transparent"

    function wake() { hideTimer.restart() }
    function openTools(tab) { toolsTab = tab || toolsTab; queueOpen = false; toolsOpen = true; wake() }
    function closePanels() {
        if (toolsOpen || queueOpen) { toolsOpen = false; queueOpen = false; return true }
        return false
    }
    function snapshot() {
        const p = Player.takeSnapshot(MediaInput.picturesFolder())
        toast(p ? qsTr("Screenshot saved to Pictures") : qsTr("Couldn’t take a screenshot"))
    }
    // "Midnight Drive" -> "Midnight " + accent "Drive" (03)
    function splitTitle(t) {
        const i = t.lastIndexOf(" ")
        return i > 0 ? [t.slice(0, i + 1), t.slice(i + 1)] : ["", t]
    }

    Timer { id: hideTimer; interval: Prefs.controlsHideMs; running: true }

    // ============================================================ VIDEO
    Item {
        id: stage
        anchors.fill: parent
        visible: root.videoMode

        VideoOutput {
            anchors.fill: parent
            player: Player
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.controlsVisible ? Qt.ArrowCursor : Qt.BlankCursor
            onPositionChanged: root.wake()
            onClicked: {
                if (root.compact) { if (hideTimer.running) hideTimer.stop(); else root.wake(); return }
                clickTimer.restart()
            }
            onDoubleClicked: { clickTimer.stop(); root.toggleFullscreen() }
            Timer { id: clickTimer; interval: 250; onTriggered: { if (root.closePanels()) return; Player.togglePause(); root.wake() } }
        }
    }

    // Top: title + technical line, actions, window controls.
    Item {
        id: topBar
        visible: root.videoMode && opacity > 0
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.compact ? 72 : 110
        opacity: root.controlsVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Prefs.reduceMotion ? 0 : Theme.motionControlsFade } }
        HoverHandler { id: topHover }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.02, 0.02, 0.03, 0.82) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        DragHandler {
            enabled: root.window && !root.fullscreen && !root.compact
            target: null
            onActiveChanged: if (active) root.window.startSystemMove()
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: root.compact ? 10 : 26
            anchors.bottomMargin: 0
            spacing: 14
            IconButton { Layout.alignment: Qt.AlignTop; iconName: "chevron-left"; label: qsTr("Back"); variant: "overlay"; onClicked: root.back() }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 6
                Label { Layout.fillWidth: true; text: Player.title; font.pixelSize: root.compact ? 17 : 27; font.weight: Font.Bold; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.35) }
                Label {
                    Layout.fillWidth: true
                    visible: !root.compact
                    color: Theme.textEmphasis
                    font.pixelSize: 14
                    text: [MediaInput.describe(Player.url).split(" · ")[0],
                           root.videoTrack && root.videoTrack.width ? root.videoTrack.width + " × " + root.videoTrack.height : "",
                           MediaInput.describe(Player.url).split(" · ")[1] || ""].filter(s => s && s !== "Stream").join("  •  ")
                }
            }
            IconButton { Layout.alignment: Qt.AlignTop; iconName: "camera"; label: qsTr("Take screenshot"); variant: "overlay"; onClicked: root.snapshot() }
            IconButton { Layout.alignment: Qt.AlignTop; iconName: "info"; label: qsTr("Media information"); variant: "overlay"; onClicked: root.openTools("info") }
            Row {
                Layout.alignment: Qt.AlignTop
                visible: root.window && root.window.customFrame && !root.fullscreen
                spacing: 4
                IconButton { iconName: "minimize"; label: qsTr("Minimize"); variant: "overlay"; iconSize: 16; onClicked: root.window.showMinimized() }
                IconButton { iconName: "close"; label: qsTr("Close"); variant: "overlay"; iconSize: 16; onClicked: root.window.close() }
            }
        }
    }

    // Bottom: chapters + timeline, times + volume, track chips + transport + tools.
    FocusScope {
        id: bottomBar
        visible: root.videoMode && opacity > 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: (root.compact ? 150 : 210) + timeline.implicitHeight - 28
        opacity: root.controlsVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Prefs.reduceMotion ? 0 : Theme.motionControlsFade } }
        HoverHandler { id: bottomHover }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: -120
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.55; color: Qt.rgba(0.02, 0.02, 0.03, 0.62) }
                GradientStop { position: 1; color: Qt.rgba(0.02, 0.02, 0.03, 0.9) }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: root.compact ? 12 : 26
            anchors.rightMargin: root.compact ? 12 : 26
            anchors.bottomMargin: root.compact ? 12 : 24
            spacing: 4
            Item { Layout.fillHeight: true }
            Timeline { id: timeline; Layout.fillWidth: true; chapterLabels: !root.compact }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Label { font.pixelSize: 15; font.weight: Font.DemiBold
                    text: MediaInput.formatTime(Player.time) + (Player.length > 0 ? "  /  " + MediaInput.formatTime(Player.length) : "") }
                Item { Layout.fillWidth: true }
                IconButton { visible: !root.compact; iconName: Player.muted || Player.volume === 0 ? "mute" : "volume"; label: Player.muted ? qsTr("Unmute") : qsTr("Mute"); size: 36; onClicked: Player.muted = !Player.muted }
                PulseSlider { visible: !root.compact; Layout.preferredWidth: 110; from: 0; to: 125; value: Player.volume; Accessible.name: qsTr("Volume"); onMoved: Player.volume = value }
                Label { visible: Player.length > 0; font.pixelSize: 15; color: Theme.textEmphasis; text: "−" + MediaInput.formatTime(Player.length - Player.time) }
            }
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 8
                implicitHeight: 72

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    visible: bottomBar.width > 980
                    InfoChip {
                        iconName: "subtitles"
                        caption: qsTr("Subtitles")
                        value: Player.subtitleTracks.length === 0 ? qsTr("None") : (Player.subtitleTracks.find(t => t.selected) || { name: qsTr("Off") }).name
                        onClicked: root.openTools("subs")
                    }
                    InfoChip {
                        iconName: "volume"
                        caption: qsTr("Audio")
                        value: (Player.audioTracks.find(t => t.selected) || { name: qsTr("Default") }).name
                        onClicked: root.openTools("audio")
                    }
                }

                Row {
                    id: centre
                    anchors.centerIn: parent
                    spacing: root.compact ? 8 : 22
                    IconButton { anchors.verticalCenter: parent.verticalCenter; visible: root.compact; iconName: "back10"; label: qsTr("Back %1 seconds").arg(Prefs.seekStepMs / 1000); size: 48; iconSize: 28; onClicked: Player.seekBy(-Prefs.seekStepMs) }
                    IconButton { anchors.verticalCenter: parent.verticalCenter; iconName: "previous"; label: qsTr("Previous"); size: 48; iconSize: 26; onClicked: Player.time > 3000 ? Player.seek(0) : Queue.previous() }
                    IconButton { anchors.verticalCenter: parent.verticalCenter; iconName: Player.playing ? "pause" : "play"; label: Player.playing ? qsTr("Pause") : qsTr("Play"); variant: "ring"; size: 64; iconSize: 28; onClicked: Player.togglePause() }
                    IconButton { anchors.verticalCenter: parent.verticalCenter; iconName: "next"; label: qsTr("Next"); size: 48; iconSize: 26; enabled: Queue.hasNext; onClicked: Queue.next() }
                    IconButton { anchors.verticalCenter: parent.verticalCenter; visible: root.compact; iconName: "forward10"; label: qsTr("Forward %1 seconds").arg(Prefs.seekStepMs / 1000); size: 48; iconSize: 28; onClicked: Player.seekBy(Prefs.seekStepMs) }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    visible: !root.compact
                    PulseButton {
                        visible: bottomBar.width > 760
                        implicitHeight: 48
                        iconName: "clock"
                        text: Player.rate.toFixed(2).replace(/0$/, "") + " ×"
                        Accessible.name: qsTr("Playback speed")
                        onClicked: root.openTools("playback")
                    }
                    IconButton { iconName: "queue"; label: qsTr("Queue"); variant: "square"; size: 48; checkedTint: root.queueOpen; onClicked: { root.toolsOpen = false; root.queueOpen = !root.queueOpen } }
                    IconButton { iconName: root.fullscreen ? "fullscreen-exit" : "fullscreen"; label: root.fullscreen ? qsTr("Exit fullscreen") : qsTr("Fullscreen"); variant: "square"; size: 48; onClicked: root.toggleFullscreen() }
                    IconButton { iconName: "settings"; label: qsTr("Playback tools"); variant: "square"; size: 48; checkedTint: root.toolsOpen; onClicked: root.toolsOpen ? root.closePanels() : root.openTools() }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.compact
                    IconButton { iconName: "tools"; label: qsTr("Playback tools"); onClicked: root.openTools() }
                    IconButton { iconName: root.fullscreen ? "fullscreen-exit" : "fullscreen"; label: qsTr("Fullscreen"); onClicked: root.toggleFullscreen() }
                }
            }
        }
    }

    // Floating tools card (02): top-right over the video.
    ToolsPanel {
        id: floatingTools
        visible: !root.compact && root.toolsOpen
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 22
        anchors.topMargin: root.videoMode ? 92 : 76
        width: Math.min(420, root.width - 44)
        height: Math.min(560, root.height - anchors.topMargin - (root.videoMode ? 240 : 24))
        floating: true
        tab: root.toolsTab
        onTabChanged: root.toolsTab = tab
        onCloseRequested: root.toolsOpen = false
        onToast: (m) => root.toast(m)
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
    }

    // Floating queue card.
    Glass {
        visible: !root.compact && root.queueOpen
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 22
        anchors.topMargin: root.videoMode ? 92 : 76
        width: Math.min(380, root.width - 44)
        height: Math.min(560, root.height - anchors.topMargin - (root.videoMode ? 240 : 24))
        lit: true
        radius: 16
        color: Qt.rgba(0.07, 0.075, 0.095, 0.94)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            RowLayout {
                Label { Layout.fillWidth: true; role: "section"; font.pixelSize: 18; text: qsTr("Up Next") }
                IconButton { iconName: "close"; label: qsTr("Close queue"); size: 36; iconSize: 16; variant: "tint"; onClicked: root.queueOpen = false }
            }
            QueueList { Layout.fillWidth: true; Layout.fillHeight: true; dense: true }
        }
    }

    // ============================================================ AUDIO (03)
    Item {
        anchors.fill: parent
        visible: !root.videoMode

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.compact ? 16 : 28
            spacing: 24

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.compact ? 18 : 24

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.compact ? 1 : 2
                    columnSpacing: 30
                    rowSpacing: 20

                    Item {
                        id: art
                        readonly property int side: root.compact ? Math.min(root.width - 32, 320) : Math.max(180, Math.min(310, root.height - 420))
                        Layout.preferredWidth: side
                        Layout.preferredHeight: side
                        Layout.alignment: root.compact ? Qt.AlignHCenter : Qt.AlignTop
                        RectangularGlow {
                            anchors.fill: parent
                            glowRadius: 30
                            spread: 0.05
                            cornerRadius: 46
                            color: Qt.rgba(1, 0.42, 0.16, 0.28)
                        }
                        MediaThumb {
                            anchors.fill: parent
                            radius: 16
                            source: Player.url
                            audio: true
                            stream: !Player.url.toString().startsWith("file:")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 10
                        Row {
                            spacing: 8
                            visible: badge.text !== ""
                            Rectangle {
                                width: badge.implicitWidth + 16; height: 26; radius: 6
                                color: Qt.rgba(1, 0.416, 0.157, 0.12); border.width: 1; border.color: Theme.accent
                                Text { id: badge; anchors.centerIn: parent; text: MediaInput.describe(Player.url).split(" · ")[0]; color: Theme.accentText; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold }
                            }
                            Rectangle {
                                readonly property var t: Player.audioTracks.length ? Player.audioTracks[0] : null
                                visible: !!t && t.sampleRate > 0
                                width: rate.implicitWidth + 16; height: 26; radius: 6
                                color: Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: Theme.glassBorder
                                Text { id: rate; anchors.centerIn: parent; text: parent.t ? (parent.t.sampleRate / 1000) + " kHz" + (parent.t.channels ? " · " + (parent.t.channels === 2 ? qsTr("Stereo") : parent.t.channels + " ch") : "") : ""; color: Theme.textEmphasis; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.StyledText
                            readonly property var parts: root.splitTitle(Player.title)
                            text: parts[0].replace(/&/g, "&amp;").replace(/</g, "&lt;") + "<font color='" + Theme.accentBright + "'>" + parts[1].replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</font>"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: root.compact ? 30 : 46
                            font.weight: Font.ExtraBold
                            font.letterSpacing: -0.8
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Accessible.name: Player.title
                        }
                        Label { Layout.fillWidth: true; visible: Player.artist !== ""; text: Player.artist; font.pixelSize: 19; font.weight: Font.Medium; color: "#C9CCD8" }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            color: Theme.textSecondary
                            font.pixelSize: 14
                            text: [Player.album, Player.date, Player.genre].filter(s => s !== "").join("  •  ")
                        }
                        PulseBars {
                            visible: !root.compact
                            Layout.fillWidth: true
                            Layout.topMargin: 12
                            Layout.preferredHeight: 78
                            progress: Player.position
                            playing: Player.playing
                            animated: !Prefs.reduceMotion
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Timeline { Layout.fillWidth: true; onVideo: false; chapterLabels: false }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { secondary: true; font.pixelSize: 13; text: MediaInput.formatTime(Player.time) }
                        Item { Layout.fillWidth: true }
                        Label { secondary: true; font.pixelSize: 13; text: "−" + MediaInput.formatTime(Player.length - Player.time) }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 76
                    Row {
                        anchors.centerIn: parent
                        spacing: root.compact ? 14 : 30
                        IconButton { anchors.verticalCenter: parent.verticalCenter; iconName: "shuffle"; label: qsTr("Shuffle"); checkedTint: Queue.shuffle; size: 48; iconSize: 22; onClicked: Queue.shuffle = !Queue.shuffle }
                        IconButton { anchors.verticalCenter: parent.verticalCenter; iconName: "previous"; label: qsTr("Previous"); size: 52; iconSize: 26; onClicked: Player.time > 3000 ? Player.seek(0) : Queue.previous() }
                        IconButton { anchors.verticalCenter: parent.verticalCenter; iconName: Player.playing ? "pause" : "play"; label: Player.playing ? qsTr("Pause") : qsTr("Play"); variant: "ring"; size: 68; iconSize: 30; onClicked: Player.togglePause() }
                        IconButton { anchors.verticalCenter: parent.verticalCenter; iconName: "next"; label: qsTr("Next"); size: 52; iconSize: 26; enabled: Queue.hasNext; onClicked: Queue.next() }
                        IconButton { anchors.verticalCenter: parent.verticalCenter; iconName: Queue.repeat === 2 ? "repeat-one" : "repeat"; label: qsTr("Repeat"); checkedTint: Queue.repeat !== 0; size: 48; iconSize: 22; onClicked: Queue.cycleRepeat() }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.compact && parent.width > 760
                        spacing: 8
                        IconButton { anchors.verticalCenter: parent.verticalCenter; iconName: Player.muted || Player.volume === 0 ? "mute" : "volume"; label: Player.muted ? qsTr("Unmute") : qsTr("Mute"); size: 40; onClicked: Player.muted = !Player.muted }
                        PulseSlider { anchors.verticalCenter: parent.verticalCenter; width: 130; from: 0; to: 125; value: Player.volume; Accessible.name: qsTr("Volume"); onMoved: Player.volume = value }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 12
                    InfoChip { Layout.fillWidth: true; iconName: "headphones"; caption: qsTr("Output Device"); value: qsTr("System default"); onClicked: { Player.refreshAudioDevices(); root.openTools("audio") } }
                    InfoChip { Layout.fillWidth: true; iconName: "gauge"; caption: qsTr("Playback Speed"); value: Player.rate.toFixed(2).replace(/0$/, "") + "×"; onClicked: root.openTools("playback") }
                    InfoChip { Layout.fillWidth: true; iconName: "equalizer"; caption: qsTr("Equalizer"); value: Player.equalizerEnabled ? (Player.equalizerPreset >= 0 ? Engine.equalizerPresets[Player.equalizerPreset] : qsTr("Custom")) : qsTr("Off"); onClicked: root.openTools("audio") }
                }
                Item { Layout.fillHeight: true }
            }

            // Up Next (03, right column).
            Glass {
                visible: !root.compact && root.width > 1000
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                radius: 16
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    RowLayout {
                        Label { Layout.fillWidth: true; role: "section"; font.pixelSize: 18; text: qsTr("Up Next") }
                        Label { text: qsTr("Clear"); color: Theme.accentText; font.pixelSize: 13; font.weight: Font.DemiBold; visible: Queue.count > 1
                            TapHandler { onTapped: { const u = Player.url; Queue.setItems([u], 0) } } }
                    }
                    QueueList { Layout.fillWidth: true; Layout.fillHeight: true; dense: true }
                }
            }
        }
    }

    // Phone: tools and queue as bottom sheets.
    T.Drawer {
        id: sheet
        edge: Qt.BottomEdge
        width: root.width
        height: Math.min(root.height * 0.62, 560)
        visible: root.compact && (root.toolsOpen || root.queueOpen)
        onClosed: { root.toolsOpen = false; root.queueOpen = false }
        background: Rectangle {
            color: "#16181F"
            radius: Theme.radiusSheet
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.radiusSheet; color: parent.color }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 10; width: 40; height: 5; radius: 3; color: Theme.border }
        }
        ToolsPanel {
            visible: root.toolsOpen
            anchors.fill: parent
            anchors.topMargin: 16
            color: "transparent"
            border.width: 0
            tab: root.toolsTab
            onTabChanged: root.toolsTab = tab
            onCloseRequested: sheet.close()
            onToast: (m) => root.toast(m)
        }
        QueueList { visible: root.queueOpen; anchors.fill: parent; anchors.margins: 16; anchors.topMargin: 28 }
    }

    // ============================================================ STATES
    Rectangle {
        anchors.centerIn: parent
        visible: Player.state === 1 || (Player.state === 2 && Player.buffering < 1 && Player.buffering > 0)
        width: 72
        height: 72
        radius: 36
        color: Qt.rgba(0.07, 0.07, 0.09, 0.7)
        Accessible.role: Accessible.Animation
        Accessible.name: qsTr("Loading")
        Logo {
            anchors.centerIn: parent
            wordmark: false
            markHeight: 24
            SequentialAnimation on opacity {
                running: parent.visible && !Prefs.reduceMotion
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 500 }
                NumberAnimation { to: 1; duration: 500 }
            }
        }
    }

    Glass {
        anchors.centerIn: parent
        visible: Player.state === 5
        width: Math.min(480, root.width - 32)
        implicitHeight: errCol.implicitHeight + 48
        radius: 16
        border.color: Theme.error
        ColumnLayout {
            id: errCol
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12
            RowLayout {
                spacing: 10
                PulseIcon { name: "alert"; color: Theme.errorText; size: 22 }
                Label { Layout.fillWidth: true; role: "section"; font.pixelSize: 18; text: qsTr("Couldn’t play this media") }
            }
            Label { Layout.fillWidth: true; secondary: true; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone; text: Player.url.toString() }
            Label { Layout.fillWidth: true; secondary: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                text: qsTr("The file may be damaged, use a format this build can’t decode, or the address may be unreachable.") }
            RowLayout {
                spacing: 8
                PulseButton { variant: "primary"; text: qsTr("Retry"); onClicked: Player.open(Player.url) }
                PulseButton { text: qsTr("File information"); onClicked: root.openTools("info") }
                PulseButton { variant: "quiet"; visible: Queue.hasNext; text: qsTr("Skip"); onClicked: Queue.next() }
            }
        }
    }
}
