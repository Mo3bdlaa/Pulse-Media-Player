import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import QtQuick.Window
import Pulse
import Pulse.Core

// 02 — Video Player and 03 — Audio Player. Media is the hero; controls
// appear on activity and fade after Prefs.controlsHideMs.
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
                                   || bottomBar.activeFocusInside || !Player.playing
    readonly property bool controlsVisible: !videoMode || pinned || hideTimer.running

    signal back()
    signal toggleFullscreen()
    signal toast(string message)

    color: videoMode ? "black" : Theme.bg

    function wake() { hideTimer.restart() }
    function openTools(tab) { toolsTab = tab || toolsTab; queueOpen = false; toolsOpen = true; wake() }
    function closePanels() {
        if (toolsOpen || queueOpen) { toolsOpen = false; queueOpen = false; return true }
        return false
    }

    Timer { id: hideTimer; interval: Prefs.controlsHideMs; running: true }

    // ---------------------------------------------------------------- video
    Item {
        id: stage
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: drawer.left
        visible: root.videoMode

        VideoOutput {
            id: video
            anchors.fill: parent
            player: Player
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: root.controlsVisible ? Qt.ArrowCursor : Qt.BlankCursor
            onPositionChanged: root.wake()
            onClicked: (mouse) => {
                if (root.compact) { if (hideTimer.running) hideTimer.stop(); else root.wake(); return }
                clickTimer.restart()
            }
            onDoubleClicked: { clickTimer.stop(); root.toggleFullscreen() }
            Timer { id: clickTimer; interval: 250; onTriggered: { if (root.closePanels()) return; Player.togglePause(); root.wake() } }
        }
    }

    // ---------------------------------------------------------------- audio
    Item {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: drawer.left
        visible: !root.videoMode

        RowLayout {
            anchors.fill: parent
            spacing: 0

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: root.compact ? 20 : 40
                Layout.topMargin: root.compact ? 64 : 84
                spacing: root.compact ? 18 : 28

                Item { Layout.fillHeight: true; visible: root.compact }
                GridLayout {
                    Layout.fillWidth: true
                    columns: root.compact ? 1 : 2
                    columnSpacing: 36
                    rowSpacing: 20

                    Rectangle {
                        id: art
                        readonly property int side: root.compact ? Math.min(root.width - 40, 320) : Math.max(160, Math.min(320, root.height - 420))
                        Layout.preferredWidth: side
                        Layout.preferredHeight: side
                        Layout.alignment: root.compact ? Qt.AlignHCenter : Qt.AlignBottom
                        radius: Theme.radiusPanel
                        clip: true
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.accent }
                            GradientStop { position: 0.55; color: "#7A1F12" }
                            GradientStop { position: 1; color: "#14090F" }
                        }
                        Logo { anchors.centerIn: parent; wordmark: false; markHeight: art.side * 0.22; visible: artwork.status !== Image.Ready }
                        Image {
                            id: artwork
                            anchors.fill: parent
                            source: Player.artworkUrl
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(art.side * 2, art.side * 2)
                            Accessible.name: qsTr("Album artwork")
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom
                        spacing: 10
                        Label { Layout.fillWidth: true; role: "display"; font.pixelSize: root.compact ? 28 : 44; text: Player.title; wrapMode: Text.WordWrap; maximumLineCount: 2; Accessible.role: Accessible.Heading }
                        Label { Layout.fillWidth: true; visible: Player.artist !== ""; text: Player.artist; font.pixelSize: 18; font.weight: Font.DemiBold; color: Theme.textEmphasis }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            secondary: true
                            text: [Player.album, Player.date, Player.genre].filter(s => s !== "").join(" · ")
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Timeline { Layout.fillWidth: true; onVideo: false }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { role: "meta"; secondary: true; font.pixelSize: 13; text: MediaInput.formatTime(Player.time) }
                        Item { Layout.fillWidth: true }
                        Label { role: "meta"; secondary: true; font.pixelSize: 13; text: "−" + MediaInput.formatTime(Player.length - Player.time) }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16
                    IconButton { iconName: "shuffle"; label: qsTr("Shuffle"); checkedTint: Queue.shuffle; size: 48; iconSize: 22; onClicked: Queue.shuffle = !Queue.shuffle }
                    IconButton { iconName: "previous"; label: qsTr("Previous"); size: 52; iconSize: 26; onClicked: Player.time > 3000 ? Player.seek(0) : Queue.previous() }
                    IconButton { iconName: Player.playing ? "pause" : "play"; label: Player.playing ? qsTr("Pause") : qsTr("Play"); variant: "accent"; size: 72; iconSize: 30; onClicked: Player.togglePause() }
                    IconButton { iconName: "next"; label: qsTr("Next"); size: 52; iconSize: 26; enabled: Queue.hasNext; onClicked: Queue.next() }
                    IconButton { iconName: Queue.repeat === 2 ? "repeat-one" : "repeat"; label: qsTr("Repeat"); checkedTint: Queue.repeat !== 0; size: 48; iconSize: 22; onClicked: Queue.cycleRepeat() }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.compact ? 3 : 4
                    columnSpacing: 12
                    rowSpacing: 12
                    RowLayout {
                        visible: !root.compact
                        Layout.fillWidth: true
                        IconButton { iconName: Player.muted || Player.volume === 0 ? "mute" : "volume"; label: Player.muted ? qsTr("Unmute") : qsTr("Mute"); size: 40; onClicked: Player.muted = !Player.muted }
                        PulseSlider { Layout.fillWidth: true; from: 0; to: 125; value: Player.volume; Accessible.name: qsTr("Volume"); onMoved: Player.volume = value }
                    }
                    PulseButton { Layout.fillWidth: true; iconName: "headphones"; text: root.compact ? "" : qsTr("Output"); Accessible.name: qsTr("Output device"); onClicked: { Player.refreshAudioDevices(); root.openTools("audio") } }
                    PulseButton { Layout.fillWidth: true; iconName: "gauge"; text: Player.rate.toFixed(2).replace(/0$/, "") + "×"; Accessible.name: qsTr("Playback speed"); onClicked: root.openTools("playback") }
                    PulseButton { Layout.fillWidth: true; iconName: "equalizer"; text: root.compact ? "" : qsTr("Equalizer"); active: Player.equalizerEnabled; Accessible.name: qsTr("Equalizer"); onClicked: root.openTools("audio") }
                }
                Item { Layout.fillHeight: true }
            }

            // Up Next beside the audio player on wide windows.
            Rectangle {
                visible: !root.compact && root.width > 1100 && !root.toolsOpen && !root.queueOpen
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                color: Theme.bg
                Rectangle { width: 1; height: parent.height; color: Theme.border }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    anchors.topMargin: 72
                    Label { role: "section"; font.pixelSize: 18; text: qsTr("Up Next") }
                    QueueList { Layout.fillWidth: true; Layout.fillHeight: true; dense: true }
                }
            }
        }
    }

    // ---------------------------------------------------------------- top bar
    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: drawer.left
        height: 96
        opacity: root.controlsVisible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Prefs.reduceMotion ? 0 : Theme.motionControlsFade } }
        HoverHandler { id: topHover }

        Rectangle {
            visible: root.videoMode
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.016, 0.02, 0.03, 0.78) }
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
            anchors.margins: root.compact ? 8 : 20
            anchors.bottomMargin: 0
            spacing: 12
            IconButton { Layout.alignment: Qt.AlignTop; iconName: "chevron-left"; label: qsTr("Back"); variant: root.videoMode ? "overlay" : "plain"; onClicked: root.back() }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 2
                spacing: 4
                visible: root.videoMode
                Label { Layout.fillWidth: true; role: "section"; font.pixelSize: root.compact ? 16 : 22; text: Player.title }
                Label {
                    Layout.fillWidth: true
                    visible: !root.compact
                    color: Theme.textEmphasis
                    font.pixelSize: 13
                    readonly property var v: Player.videoTracks.length ? Player.videoTracks[0] : null
                    text: [v && v.width ? v.width + " × " + v.height : "", v ? (v.codecName || v.codec) : "",
                           Player.chapters.length && Player.currentChapter >= 0 ? qsTr("Chapter %1 of %2 — %3").arg(Player.currentChapter + 1).arg(Player.chapters.length).arg(Player.chapters[Player.currentChapter].name) : ""]
                          .filter(s => s !== "").join(" · ")
                }
            }
            Item { Layout.fillWidth: true; visible: !root.videoMode }
            IconButton { Layout.alignment: Qt.AlignTop; visible: root.videoMode; iconName: "camera"; label: qsTr("Take screenshot"); variant: "overlay"
                onClicked: { const p = Player.takeSnapshot(MediaInput.picturesFolder()); root.toast(p ? qsTr("Screenshot saved to Pictures") : qsTr("Couldn’t take a screenshot")) } }
            IconButton { Layout.alignment: Qt.AlignTop; iconName: "info"; label: qsTr("Media information"); variant: root.videoMode ? "overlay" : "plain"; onClicked: root.openTools("info") }
            Row {
                Layout.alignment: Qt.AlignTop
                visible: root.window && root.window.customFrame && !root.fullscreen
                spacing: 2
                IconButton { iconName: "minimize"; label: qsTr("Minimize"); variant: root.videoMode ? "overlay" : "plain"; iconSize: 16; onClicked: root.window.showMinimized() }
                IconButton { iconName: "close"; label: qsTr("Close"); variant: root.videoMode ? "overlay" : "plain"; iconSize: 16; onClicked: root.window.close() }
            }
        }
    }

    // ---------------------------------------------------------------- bottom bar (video)
    FocusScope {
        id: bottomBar
        readonly property bool activeFocusInside: activeFocus
        visible: root.videoMode && opacity > 0
        anchors.left: parent.left
        anchors.right: drawer.left
        anchors.bottom: parent.bottom
        height: root.compact ? 150 : 200
        opacity: root.controlsVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Prefs.reduceMotion ? 0 : Theme.motionControlsFade } }
        HoverHandler { id: bottomHover }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: -100
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Theme.scrim }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: root.compact ? 12 : 24
            anchors.rightMargin: root.compact ? 12 : 24
            anchors.bottomMargin: root.compact ? 12 : 22
            spacing: 6
            Item { Layout.fillHeight: true }
            Timeline { Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true
                Label { font.pixelSize: 13; font.weight: Font.DemiBold
                    text: MediaInput.formatTime(Player.time) + (Player.length > 0 ? "  /  " + MediaInput.formatTime(Player.length) : "") }
                Item { Layout.fillWidth: true }
                Label { visible: Player.length > 0; font.pixelSize: 13; color: Theme.textEmphasis; text: "−" + MediaInput.formatTime(Player.length - Player.time) }
            }
            // Transport stays centred regardless of what sits on either side.
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 6
                implicitHeight: 72

                // left: track chips
                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, centre.x - 16)
                    clip: true
                    visible: bottomBar.width > 900
                    spacing: 8
                    PulseButton {
                        iconName: "subtitles"
                        text: Player.subtitleTracks.length === 0 ? qsTr("No subtitles")
                              : (Player.subtitleTracks.find(t => t.selected) || { name: qsTr("Subtitles off") }).name
                        onClicked: root.openTools("subs")
                    }
                    PulseButton {
                        visible: Player.audioTracks.length > 1
                        iconName: "audio"
                        text: (Player.audioTracks.find(t => t.selected) || { name: qsTr("Audio") }).name
                        onClicked: root.openTools("audio")
                    }
                }

                // centre: transport
                RowLayout {
                    id: centre
                    anchors.centerIn: parent
                    spacing: root.compact ? 4 : 10
                    IconButton { iconName: "previous"; label: qsTr("Previous"); size: 48; iconSize: 24; onClicked: Player.time > 3000 ? Player.seek(0) : Queue.previous() }
                    IconButton { iconName: "back10"; label: qsTr("Back %1 seconds").arg(Prefs.seekStepMs / 1000); size: 48; iconSize: 28; enabled: Player.seekable; onClicked: Player.seekBy(-Prefs.seekStepMs) }
                    IconButton { iconName: Player.playing ? "pause" : "play"; label: Player.playing ? qsTr("Pause") : qsTr("Play"); variant: "accent"; size: 68; iconSize: 28; onClicked: Player.togglePause() }
                    IconButton { iconName: "forward10"; label: qsTr("Forward %1 seconds").arg(Prefs.seekStepMs / 1000); size: 48; iconSize: 28; enabled: Player.seekable; onClicked: Player.seekBy(Prefs.seekStepMs) }
                    IconButton { iconName: "next"; label: qsTr("Next"); size: 48; iconSize: 24; enabled: Queue.hasNext; onClicked: Queue.next() }
                }

                // right: speed, volume, tools, queue, fullscreen
                RowLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    PulseButton { visible: bottomBar.width > 760; implicitHeight: 40; text: Player.rate.toFixed(2).replace(/0$/, "") + "×"; Accessible.name: qsTr("Playback speed"); onClicked: root.openTools("playback") }
                    IconButton { visible: bottomBar.width > 640; iconName: Player.muted || Player.volume === 0 ? "mute" : "volume"; label: Player.muted ? qsTr("Unmute") : qsTr("Mute"); size: 40; onClicked: Player.muted = !Player.muted }
                    PulseSlider { visible: bottomBar.width > 1000; Layout.preferredWidth: 96; from: 0; to: 125; value: Player.volume; fillColor: Theme.text; trackColor: Qt.rgba(0.97, 0.96, 0.94, 0.22); Accessible.name: qsTr("Volume"); onMoved: Player.volume = value }
                    IconButton { iconName: "tools"; label: qsTr("Playback tools"); size: 40; checkedTint: root.toolsOpen; onClicked: root.toolsOpen ? root.closePanels() : root.openTools() }
                    IconButton { iconName: "queue"; label: qsTr("Queue"); size: 40; checkedTint: root.queueOpen; onClicked: { root.toolsOpen = false; root.queueOpen = !root.queueOpen } }
                    IconButton { iconName: root.fullscreen ? "fullscreen-exit" : "fullscreen"; label: root.fullscreen ? qsTr("Exit fullscreen") : qsTr("Fullscreen"); size: 40; onClicked: root.toggleFullscreen() }
                }
            }
        }
    }

    // ---------------------------------------------------------------- drawer (tools / queue)
    Item {
        id: drawer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        readonly property bool open: (root.toolsOpen || root.queueOpen) && !root.compact
        width: open ? Math.min(Theme.toolsDrawer, root.width * 0.45) : 0
        clip: true
        Behavior on width { NumberAnimation { duration: Prefs.reduceMotion ? 0 : Theme.motionPanel; easing.type: Easing.OutCubic } }

        ToolsPanel {
            visible: root.toolsOpen
            width: Math.min(Theme.toolsDrawer, root.width * 0.45)
            height: parent.height
            tab: root.toolsTab
            onTabChanged: root.toolsTab = tab
            onCloseRequested: root.toolsOpen = false
            onToast: (m) => root.toast(m)
        }
        Rectangle {
            visible: root.queueOpen
            width: Math.min(Theme.toolsDrawer, root.width * 0.45)
            height: parent.height
            color: Theme.surface
            Rectangle { width: 1; height: parent.height; color: Theme.border }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                RowLayout {
                    Label { Layout.fillWidth: true; role: "section"; font.pixelSize: 18; text: qsTr("Up Next") }
                    IconButton { iconName: "close"; label: qsTr("Close queue"); size: 40; iconSize: 18; variant: "tint"; onClicked: root.queueOpen = false }
                }
                QueueList { Layout.fillWidth: true; Layout.fillHeight: true; dense: true }
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
            color: Theme.surface
            radius: Theme.radiusSheet
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Theme.radiusSheet; color: Theme.surface }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 10; width: 40; height: 5; radius: 3; color: Theme.border }
        }
        ToolsPanel {
            visible: root.toolsOpen
            anchors.fill: parent
            anchors.topMargin: 16
            color: "transparent"
            tab: root.toolsTab
            onTabChanged: root.toolsTab = tab
            onCloseRequested: sheet.close()
            onToast: (m) => root.toast(m)
        }
        QueueList { visible: root.queueOpen; anchors.fill: parent; anchors.margins: 16; anchors.topMargin: 28 }
    }

    // ---------------------------------------------------------------- states
    Rectangle {
        anchors.centerIn: stage
        visible: Player.state === 1 || (Player.state === 2 && Player.buffering < 1 && Player.buffering > 0)
        width: 64
        height: 64
        radius: 32
        color: Qt.rgba(0.07, 0.07, 0.09, 0.7)
        Accessible.role: Accessible.Animation
        Accessible.name: qsTr("Loading")
        Logo {
            anchors.centerIn: parent
            wordmark: false
            markHeight: 22
            SequentialAnimation on opacity {
                running: parent.visible && !Prefs.reduceMotion
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 500 }
                NumberAnimation { to: 1; duration: 500 }
            }
        }
    }

    Card {
        anchors.centerIn: parent
        visible: Player.state === 5
        width: Math.min(460, root.width - 32)
        implicitHeight: errCol.implicitHeight + 48
        radius: Theme.radiusPanel
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
