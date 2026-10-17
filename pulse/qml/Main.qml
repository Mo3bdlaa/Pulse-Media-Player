import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window
import Pulse
import Pulse.Core

// App shell. Entry rules (design.md §5.2):
//   launched with media -> straight into the player
//   launched empty      -> Welcome / Home
T.ApplicationWindow {
    id: win

    readonly property bool compact: width < Theme.compactBreakpoint
    readonly property bool customFrame: !(Prefs.useSystemFrame || AppInfo.mobile)
    readonly property bool fullscreen: visibility === Window.FullScreen
    property string route: "home"
    // Video plays edge to edge; audio keeps the app shell (03).
    readonly property bool immersive: route === "player" && Player.hasVideo
    property string lastRoute: "home"
    property int resumeFrom: 0

    width: 1280
    height: 800
    minimumWidth: 360
    minimumHeight: 480
    visible: true
    readonly property bool framed: customFrame && !fullscreen && visibility !== Window.Maximized
    color: framed ? "transparent" : Theme.bg
    title: Player.hasMedia ? Player.title + " — Pulse" : "Pulse"
    flags: customFrame ? (Qt.Window | Qt.FramelessWindowHint) : Qt.Window
    font.family: Theme.fontFamily

    function toggleMaximized() { visibility === Window.Maximized ? showNormal() : showMaximized() }
    function toggleFullscreen() { fullscreen ? showNormal() : showFullScreen() }

    function navigate(r) {
        if (r === "player" && !Player.hasMedia) r = "home"
        if (route !== "player") lastRoute = route
        route = r
    }

    // Opens media: folders expand into a queue; subtitles attach to the current video.
    function openUrls(input, enqueue) {
        const urls = Array.from(input)
        const subs = urls.filter(u => MediaInput.isSubtitle(u))
        if (subs.length && Player.hasVideo) {
            for (const s of subs) Player.addSubtitleFile(s)
            toast.show(qsTr("Subtitle added"))
        }
        const media = MediaInput.expand(urls)
        if (media.length === 0) {
            if (!subs.length) toast.show(qsTr("Nothing playable was found there"), "", true)
            return
        }
        if (enqueue && Queue.count > 0) {
            Queue.append(media)
            toast.show((media.length === 1 ? qsTr("Added 1 item to the queue") : qsTr("Added %1 items to the queue").arg(media.length)))
        } else {
            Queue.setItems(media, 0)
            navigate("player")
        }
    }

    Connections {
        target: Queue
        function onPlayRequested(address) {
            const resume = Prefs.resumePlayback ? Recent.resumePosition(address) : 0
            win.resumeFrom = resume
            Player.open(address, resume)
            if (Prefs.keepRecent) Recent.touch(address)
            if (resume > 0)
                toast.show(qsTr("Resumed at %1").arg(MediaInput.formatTime(resume)), qsTr("Start over"))
        }
    }
    Connections {
        target: Player
        function onEndReached() {
            Recent.savePosition(Player.url, 0, Player.length)
            if (!Prefs.autoplayNext || !Queue.advance()) {
                if (win.fullscreen) win.showNormal()
            }
        }
        function onErrorOccurred(message) { if (win.route !== "player") toast.show(message, "", true) }
        function onTimeChanged() {
            // Persist the resume point every ~5 s of playback.
            if (Prefs.keepRecent && Player.length > 0 && Math.abs(Player.time - saveTimer.last) > 5000) {
                saveTimer.last = Player.time
                Recent.savePosition(Player.url, Player.time, Player.length)
            }
        }
    }
    QtObject { id: saveTimer; property double last: 0 }
    onClosing: if (Player.hasMedia && Player.length > 0) Recent.savePosition(Player.url, Player.time, Player.length)

    Component.onCompleted: {
        Player.volume = Prefs.volume
        Recent.enabled = Prefs.keepRecent
        if (AppInfo.initialMedia.length > 0)
            openUrls(AppInfo.initialMedia, false)
    }
    Connections { target: Player; function onVolumeChanged() { Prefs.volume = Player.volume } }

    // ------------------------------------------------------------ dialogs
    FileDialog {
        id: fileDialog
        title: qsTr("Open media")
        fileMode: FileDialog.OpenFiles
        onAccepted: win.openUrls(selectedFiles, false)
    }
    FolderDialog {
        id: folderDialog
        title: qsTr("Open folder")
        onAccepted: win.openUrls([selectedFolder], false)
    }
    OpenUrlDialog { id: urlDialog; onAccepted: (address, enqueue) => win.openUrls([address], enqueue) }
    CommandPalette {
        id: palette
        commands: [
            { text: qsTr("Open file…"), hint: "Ctrl O", icon: "file", run: () => fileDialog.open() },
            { text: qsTr("Open folder…"), hint: "Ctrl F", icon: "folder", run: () => folderDialog.open() },
            { text: qsTr("Open network address…"), hint: "Ctrl N", icon: "link", run: () => urlDialog.open() },
            { text: qsTr("Go to Home"), icon: "home", run: () => win.navigate("home") },
            { text: qsTr("Go to Now Playing"), icon: "music", run: () => win.navigate("player") },
            { text: qsTr("Show queue"), icon: "queue", run: () => win.navigate("queue") },
            { text: qsTr("Network and streams"), icon: "network", run: () => win.navigate("network") },
            { text: qsTr("Settings"), icon: "settings", run: () => win.navigate("settings") },
            { text: qsTr("Toggle fullscreen"), hint: "F", icon: "fullscreen", run: () => win.toggleFullscreen() },
            { text: qsTr("Playback tools"), hint: "T", icon: "tools", run: () => { win.navigate("player"); playerScreen.openTools() } },
            { text: qsTr("Clear recent files"), icon: "trash", run: () => Recent.clear() }
        ]
    }

    // ------------------------------------------------------------ layout
    // Rounded body with an ember rim (custom frame only).
    Rectangle {
        anchors.fill: parent
        radius: win.framed ? 14 : 0
        color: Theme.bg
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#121318" }
            GradientStop { position: 1.0; color: Theme.bg }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: win.framed ? 1 : 0
        spacing: 0

        TitleBar {
            Layout.fillWidth: true
            visible: win.customFrame && !win.compact && !win.immersive
            window: win
            onSearchRequested: palette.open()
            onHomeRequested: win.navigate("home")
        }

        // Phone header (M1): lockup + search.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 12
            Layout.topMargin: 8
            visible: win.compact && !win.immersive
            Logo { Layout.fillWidth: true }
            IconButton { iconName: "search"; label: qsTr("Search or run a command"); variant: "overlay"; onClicked: palette.open() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Sidebar {
                Layout.fillHeight: true
                visible: !win.compact && !win.immersive
                route: win.route
                hasMedia: Player.hasMedia
                onNavigate: (r) => win.navigate(r)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                HomeScreen {
                    anchors.fill: parent
                    visible: win.route === "home"
                    compact: win.compact
                    onOpenFile: fileDialog.open()
                    onOpenFolder: folderDialog.open()
                    onOpenUrl: urlDialog.open()
                    onPlayRecent: (address) => win.openUrls([address], false)
                    onNavigate: (r) => win.navigate(r)
                }
                QueueScreen { anchors.fill: parent; visible: win.route === "queue"; compact: win.compact }
                NetworkScreen { anchors.fill: parent; visible: win.route === "network"; compact: win.compact; onPlay: (address, enqueue) => win.openUrls([address], enqueue) }
                SettingsScreen { anchors.fill: parent; visible: win.route === "settings"; compact: win.compact }
                PlannedScreen {
                    anchors.fill: parent
                    visible: win.route === "library"
                    compact: win.compact
                    title: qsTr("Library")
                    phase: "P2"
                    summary: qsTr("An optional index of folders you choose. Playing files never needs it.")
                    points: [qsTr("Add folders explicitly; nothing is scanned without your say-so"), qsTr("Movies, TV, Music and Other, with search and sort"), qsTr("Continue watching from saved positions"), qsTr("Offline folders keep their items and can be located again")]
                }
                PlannedScreen {
                    anchors.fill: parent
                    visible: win.route === "playlists"
                    compact: win.compact
                    title: qsTr("Playlists")
                    phase: "P2"
                    summary: qsTr("Mixed audio and video playlists that point to files and addresses — never copies.")
                    points: [qsTr("Save the current queue as a playlist"), qsTr("Import and export M3U / M3U8"), qsTr("Missing files stay listed and can be located")]
                }
                PlannedScreen {
                    anchors.fill: parent
                    visible: win.route === "convert"
                    compact: win.compact
                    title: qsTr("Convert & Export")
                    phase: "P3"
                    summary: qsTr("Make a copy in another format. Originals are never changed or deleted.")
                    points: [qsTr("Presets validated against this build’s encoders"), qsTr("A job queue with progress, errors and cancel"), qsTr("Safe file names — never overwrites without asking")]
                }

                PlayerScreen {
                    id: playerScreen
                    anchors.fill: parent
                    visible: win.route === "player"
                    window: win
                    compact: win.compact
                    fullscreen: win.fullscreen
                    onBack: { if (win.fullscreen) win.showNormal(); win.navigate(win.lastRoute === "player" ? "home" : win.lastRoute) }
                    onToggleFullscreen: win.toggleFullscreen()
                    onToast: (m) => toast.show(m)
                }
            }
        }

        MiniPlayer {
            Layout.fillWidth: true
            Layout.margins: win.compact ? 10 : 0
            Layout.bottomMargin: win.compact ? 6 : 0
            visible: Player.hasMedia && win.route !== "player"
            compact: win.compact
            onExpand: win.navigate("player")
        }
        BottomNav {
            Layout.fillWidth: true
            visible: win.compact && win.route !== "player"
            route: win.route
            onNavigate: (r) => win.navigate(r)
        }
    }

    Rectangle {
        visible: win.framed
        anchors.fill: parent
        radius: 14
        color: "transparent"
        border.width: 1
        border.color: Theme.frameGlow
    }

    ResizeHandles { visible: win.customFrame && !win.fullscreen && win.visibility !== Window.Maximized; window: win }

    Toast {
        id: toast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: win.route === "player" ? 220 : 96
        onAction: if (actionText === qsTr("Start over")) Player.seek(0)
    }

    // Drop anywhere: media starts a queue, subtitles attach to the current video.
    DropArea {
        anchors.fill: parent
        onDropped: (drop) => { if (drop.hasUrls) { win.openUrls(drop.urls, Player.hasMedia && (drop.modifiers & Qt.ShiftModifier)); drop.accept() } }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 12
            visible: parent.containsDrag
            radius: Theme.radiusPanel
            color: Qt.rgba(1, 0.416, 0.157, 0.08)
            border.width: 2
            border.color: Theme.accent
            Label { anchors.centerIn: parent; role: "section"; text: qsTr("Drop to play — hold Shift to add to the queue") }
        }
    }

    // ------------------------------------------------------------ shortcuts
    readonly property bool playerKeys: Player.hasMedia && !palette.opened && !urlDialog.opened
    Shortcut { sequence: "Ctrl+K"; onActivated: palette.open() }
    Shortcut { sequence: StandardKey.Open; onActivated: fileDialog.open() }
    Shortcut { sequence: "Ctrl+F"; onActivated: folderDialog.open() }
    Shortcut { sequence: "Ctrl+N"; onActivated: urlDialog.open() }
    Shortcut { sequence: "Space"; enabled: win.playerKeys; onActivated: { Player.togglePause(); playerScreen.wake() } }
    Shortcut { sequence: "Left"; enabled: win.playerKeys; onActivated: { Player.seekBy(-Prefs.seekStepMs); playerScreen.wake() } }
    Shortcut { sequence: "Right"; enabled: win.playerKeys; onActivated: { Player.seekBy(Prefs.seekStepMs); playerScreen.wake() } }
    Shortcut { sequence: "Up"; enabled: win.playerKeys && win.route === "player"; onActivated: { Player.volume += 5; toast.show(qsTr("Volume %1%").arg(Player.volume)) } }
    Shortcut { sequence: "Down"; enabled: win.playerKeys && win.route === "player"; onActivated: { Player.volume -= 5; toast.show(qsTr("Volume %1%").arg(Player.volume)) } }
    Shortcut { sequence: "M"; enabled: win.playerKeys; onActivated: { Player.muted = !Player.muted; toast.show(Player.muted ? qsTr("Muted") : qsTr("Sound on")) } }
    Shortcut { sequence: "F"; enabled: win.route === "player"; onActivated: win.toggleFullscreen() }
    Shortcut { sequence: "N"; enabled: win.playerKeys; onActivated: Queue.next() }
    Shortcut { sequence: "P"; enabled: win.playerKeys; onActivated: Queue.previous() }
    Shortcut { sequence: "T"; enabled: win.route === "player"; onActivated: playerScreen.toolsOpen ? playerScreen.closePanels() : playerScreen.openTools() }
    Shortcut { sequence: "S"; enabled: win.playerKeys && Player.hasVideo
        onActivated: { const p = Player.takeSnapshot(MediaInput.picturesFolder()); toast.show(p ? qsTr("Screenshot saved to Pictures") : qsTr("Couldn’t take a screenshot")) } }
    Shortcut { sequence: "["; enabled: win.playerKeys; onActivated: { Player.rate = Math.max(0.25, Player.rate - 0.25); toast.show(qsTr("Speed %1×").arg(Player.rate)) } }
    Shortcut { sequence: "]"; enabled: win.playerKeys; onActivated: { Player.rate = Math.min(4, Player.rate + 0.25); toast.show(qsTr("Speed %1×").arg(Player.rate)) } }
    Shortcut { sequence: "G"; enabled: win.playerKeys; onActivated: { Player.subtitleDelay -= 100; toast.show(qsTr("Subtitle delay %1 ms").arg(Player.subtitleDelay)) } }
    Shortcut { sequence: "H"; enabled: win.playerKeys; onActivated: { Player.subtitleDelay += 100; toast.show(qsTr("Subtitle delay %1 ms").arg(Player.subtitleDelay)) } }
    Shortcut {
        sequence: "V"; enabled: win.playerKeys
        onActivated: {
            const t = Player.subtitleTracks
            if (!t.length) { toast.show(qsTr("No subtitles")); return }
            const i = t.findIndex(x => x.selected)
            if (i === t.length - 1) { Player.disableTrack(2); toast.show(qsTr("Subtitles off")) }
            else { Player.selectTrack(2, t[i + 1].id); toast.show(qsTr("Subtitles: %1").arg(t[i + 1].name)) }
        }
    }
    Shortcut {
        sequence: "B"; enabled: win.playerKeys
        onActivated: {
            const t = Player.audioTracks
            if (t.length < 2) return
            const n = t[(t.findIndex(x => x.selected) + 1) % t.length]
            Player.selectTrack(1, n.id)
            toast.show(qsTr("Audio: %1").arg(n.name))
        }
    }
    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (playerScreen.visible && playerScreen.closePanels()) return
            if (win.fullscreen) { win.showNormal(); return }
            if (win.route === "player") playerScreen.back()
        }
    }
}
