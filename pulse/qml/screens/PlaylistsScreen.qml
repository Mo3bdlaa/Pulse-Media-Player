import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Dialogs
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 08 — Playlists: list, the open playlist's tracks, and its details.
Item {
    id: root
    property bool compact: false
    readonly property int pad: compact ? 16 : 32
    property string selectedId
    property bool phoneDetail: false
    readonly property var current: (Playlists.revision, selectedId !== "" ? Playlists.get(selectedId) : ({}))
    readonly property var tracks: (Playlists.revision, selectedId !== "" ? Playlists.items(selectedId) : [])
    readonly property bool wide: width >= 1180
    signal play(var urls, int start)
    signal toast(string message)

    function select(id) { selectedId = id; if (compact) phoneDetail = true }
    function ensureSelection() {
        if (Playlists.count === 0) { selectedId = ""; return }
        if (selectedId === "" || Playlists.rowOf(selectedId) < 0)
            selectedId = Playlists.idAt(0)
    }
    Connections { target: Playlists; function onViewChanged() { root.ensureSelection() } }
    Component.onCompleted: ensureSelection()

    function totalText(p) {
        const n = p.itemCount || 0
        const items = n === 1 ? qsTr("1 item") : qsTr("%1 items").arg(n)
        return p.durationMs > 0 ? items + " · " + MediaInput.formatTime(p.durationMs) : items
    }
    function kindLabel(k) { return k === "movies" ? qsTr("Movies") : k === "music" ? qsTr("Music") : qsTr("Custom") }

    function playAll(shuffle) {
        const urls = Playlists.urls(selectedId)
        if (urls.length === 0) { root.toast(qsTr("This playlist has nothing to play")); return }
        Queue.shuffle = shuffle
        root.play(urls, shuffle ? Math.floor(Math.random() * urls.length) : 0)
    }

    // ---------------------------------------------------------------- dialogs
    PromptDialog {
        id: newDialog
        title: qsTr("New playlist")
        placeholder: qsTr("Playlist name")
        acceptText: qsTr("Create")
        onAccepted: (text) => root.select(Playlists.create(text))
    }
    PromptDialog {
        id: renameDialog
        title: qsTr("Rename playlist")
        placeholder: qsTr("Playlist name")
        onAccepted: (text) => Playlists.rename(root.selectedId, text)
    }
    PromptDialog {
        id: describeDialog
        title: qsTr("Description")
        placeholder: qsTr("What is this playlist for?")
        multiline: true
        onAccepted: (text) => Playlists.setDescription(root.selectedId, text)
    }
    FileDialog {
        id: addFiles
        title: qsTr("Add media to the playlist")
        fileMode: FileDialog.OpenFiles
        onAccepted: Playlists.addUrls(root.selectedId, selectedFiles)
    }
    FolderDialog {
        id: addFolder
        title: qsTr("Add a folder to the playlist")
        onAccepted: Playlists.addUrls(root.selectedId, [selectedFolder])
    }
    FileDialog {
        id: importDialog
        title: qsTr("Import playlist")
        nameFilters: [qsTr("Playlists (*.m3u *.m3u8)")]
        onAccepted: {
            const id = Playlists.importM3u(selectedFile)
            if (id === "") root.toast(qsTr("Nothing playable was found in that playlist"))
            else { Playlists.filter = "all"; root.select(id) }
        }
    }
    FileDialog {
        id: exportDialog
        title: qsTr("Save playlist as")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "m3u8"
        nameFilters: [qsTr("M3U8 playlist (*.m3u8)")]
        onAccepted: root.toast(Playlists.exportM3u(root.selectedId, selectedFile) ? qsTr("Playlist saved") : qsTr("Couldn’t save the playlist"))
    }
    T.Popup {
        id: confirmDelete
        modal: true
        anchors.centerIn: parent
        width: Math.min(420, root.width - 32)
        padding: 20
        background: Rectangle { radius: Theme.radiusPanel; color: Theme.surface; border.width: 1; border.color: Theme.border }
        contentItem: ColumnLayout {
            spacing: 14
            Label { role: "section"; text: qsTr("Delete “%1”?").arg(root.current.name || "") }
            Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.textEmphasis
                text: qsTr("Only the playlist is deleted. The files it points to stay where they are.") }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                PulseButton { text: qsTr("Cancel"); variant: "quiet"; onClicked: confirmDelete.close() }
                PulseButton { text: qsTr("Delete"); variant: "danger"; iconName: "trash"
                    onClicked: { confirmDelete.close(); Playlists.remove(root.selectedId); root.phoneDetail = false } }
            }
        }
    }

    PulseMenu {
        id: playlistMenu
        PulseMenuItem { text: qsTr("Rename…"); iconName: "pencil"; onTriggered: renameDialog.ask(root.current.name) }
        PulseMenuItem { text: qsTr("Edit Description…"); iconName: "file-text"; onTriggered: describeDialog.ask(root.current.description) }
        PulseMenuItem { text: qsTr("Add Folder…"); iconName: "folder-plus"; onTriggered: addFolder.open() }
        PulseMenuItem { text: qsTr("Add Current Queue"); iconName: "queue"; enabled: Queue.count > 0; onTriggered: Playlists.addUrls(root.selectedId, Queue.urls()) }
        PulseMenuItem { text: qsTr("Save as File…"); iconName: "upload"; onTriggered: exportDialog.open() }
        PulseMenuItem { text: qsTr("Clear Playlist"); iconName: "reset"; enabled: (root.current.itemCount || 0) > 0; onTriggered: Playlists.clear(root.selectedId) }
        PulseMenuItem { text: qsTr("Delete Playlist"); iconName: "trash"; danger: true; onTriggered: confirmDelete.open() }
    }
    PulseMenu {
        id: listMenu
        property string playlistId
        PulseMenuItem { text: qsTr("Play"); iconName: "play"; onTriggered: { root.selectedId = listMenu.playlistId; root.playAll(false) } }
        PulseMenuItem { text: qsTr("Rename…"); iconName: "pencil"; onTriggered: { root.selectedId = listMenu.playlistId; renameDialog.ask(root.current.name) } }
        PulseMenuItem { text: qsTr("Save as File…"); iconName: "upload"; onTriggered: { root.selectedId = listMenu.playlistId; exportDialog.open() } }
        PulseMenuItem { text: qsTr("Delete"); iconName: "trash"; danger: true; onTriggered: { root.selectedId = listMenu.playlistId; confirmDelete.open() } }
    }
    PulseMenu {
        id: trackMenu
        property int index: -1
        property url url
        PulseMenuItem { text: qsTr("Play from Here"); iconName: "play"; onTriggered: root.play(Playlists.urls(root.selectedId), trackMenu.index) }
        PulseMenuItem { text: qsTr("Move Up"); iconName: "chevron-left"; enabled: trackMenu.index > 0; onTriggered: Playlists.moveItem(root.selectedId, trackMenu.index, trackMenu.index - 1) }
        PulseMenuItem { text: qsTr("Move Down"); iconName: "chevron-right"; enabled: trackMenu.index < root.tracks.length - 1; onTriggered: Playlists.moveItem(root.selectedId, trackMenu.index, trackMenu.index + 1) }
        PulseMenuItem { text: qsTr("Show in Folder"); iconName: "folder"; enabled: trackMenu.url.toString().startsWith("file:"); onTriggered: Qt.openUrlExternally(MediaInput.folderOf(trackMenu.url)) }
        PulseMenuItem { text: qsTr("Remove from Playlist"); iconName: "close"; danger: true; onTriggered: Playlists.removeItem(root.selectedId, trackMenu.index) }
    }

    // ---------------------------------------------------------------- layout
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: !(root.compact && root.phoneDetail)

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.topMargin: root.compact ? 10 : 24
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label { role: "title"; font.pixelSize: root.compact ? 26 : 30; text: qsTr("Playlists"); Accessible.role: Accessible.Heading }
                Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.textEmphasis; font.pixelSize: 14; text: qsTr("Create, organize and enjoy your favorite media.") }
            }
            SearchField {
                visible: !root.compact && Playlists.totalCount > 0
                Layout.preferredWidth: 240
                placeholderText: qsTr("Search playlists…")
                onTextChanged: Playlists.search = text
            }
            PulseButton { visible: !root.compact; variant: "primary"; iconName: "plus"; text: qsTr("New Playlist"); onClicked: newDialog.ask("") }
            IconButton { variant: root.compact ? "accent" : "square"; iconName: root.compact ? "plus" : "download"
                label: root.compact ? qsTr("New Playlist") : qsTr("Import Playlist…")
                onClicked: root.compact ? newDialog.ask("") : importDialog.open() }
        }

        PillTabs {
            visible: Playlists.totalCount > 0
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.topMargin: 16
            value: Playlists.filter
            model: [
                { value: "all", text: qsTr("All Playlists (%1)").arg(Playlists.counts.all || 0) },
                { value: "movies", text: qsTr("Movies (%1)").arg(Playlists.counts.movies || 0) },
                { value: "music", text: qsTr("Music (%1)").arg(Playlists.counts.music || 0) },
                { value: "custom", text: qsTr("Custom (%1)").arg(Playlists.counts.custom || 0) }
            ]
            onActivated: (v) => Playlists.filter = v
        }

        // No playlists yet.
        Item {
            visible: Playlists.totalCount === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Glass {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(16, (parent.height - height) / 3)
                width: Math.min(parent.width - 2 * root.pad, 600)
                height: emptyCol.implicitHeight + 168
                lit: true
                clip: true
                HeroScene { anchors.left: parent.left; anchors.right: parent.right; height: 160; planetX: width * 0.5; planetY: 64; planetR: 42; horizon: 140 }
                ColumnLayout {
                    id: emptyCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 136
                    anchors.margins: 32
                    spacing: 12
                    Label { Layout.alignment: Qt.AlignHCenter; role: "section"; font.pixelSize: 22; text: qsTr("Make your first playlist") }
                    Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; elide: Text.ElideNone; color: Theme.textEmphasis
                        text: qsTr("Mix films, episodes and songs. Playlists point to your files and streams; nothing is copied.") }
                    Flow {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 10
                        Layout.preferredWidth: Math.min(emptyCol.width, implicitWidth)
                        spacing: 10
                        PulseButton { variant: "primary"; iconName: "plus"; text: qsTr("New Playlist"); onClicked: newDialog.ask("") }
                        PulseButton { visible: Queue.count > 0; iconName: "queue"; text: qsTr("Save Current Queue")
                            onClicked: root.select(Playlists.create(qsTr("Queue %1").arg(Qt.formatDate(new Date(), Qt.locale().dateFormat(Locale.ShortFormat))), Queue.urls())) }
                        PulseButton { iconName: "download"; text: qsTr("Import M3U"); onClicked: importDialog.open() }
                    }
                }
            }
        }

        RowLayout {
            visible: Playlists.totalCount > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 16
            Layout.leftMargin: root.compact ? 0 : root.pad
            Layout.rightMargin: root.compact ? 0 : root.pad
            Layout.bottomMargin: root.compact ? 0 : 20
            spacing: 16

            // ------------------------------------------------ playlist list
            ListView {
                id: list
                Layout.fillHeight: true
                Layout.fillWidth: root.compact
                Layout.preferredWidth: root.compact ? -1 : 270
                clip: true
                spacing: 6
                model: Playlists
                leftMargin: root.compact ? root.pad : 0
                rightMargin: root.compact ? root.pad : 0
                T.ScrollBar.vertical: T.ScrollBar {}
                footer: Item {
                    width: list.width
                    height: Playlists.count === 0 ? 80 : 12
                    Label { visible: Playlists.count === 0; anchors.centerIn: parent; secondary: true; text: qsTr("No playlists here.") }
                }
                delegate: T.AbstractButton {
                    id: prow
                    required property string playlistId
                    required property string name
                    required property int itemCount
                    required property double durationMs
                    required property url cover
                    required property string kind
                    readonly property bool on: !root.compact && root.selectedId === playlistId
                    width: list.width - list.leftMargin - list.rightMargin
                    height: 76
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: name
                    Accessible.selected: on
                    onClicked: root.select(playlistId)
                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: { listMenu.playlistId = prow.playlistId; listMenu.popup() } }
                    background: Rectangle {
                        radius: 12
                        gradient: prow.on ? sel : null
                        color: prow.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        border.width: prow.on ? 1 : 0
                        border.color: Qt.rgba(1, 0.416, 0.157, 0.45)
                        Gradient {
                            id: sel
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.rgba(1, 0.416, 0.157, 0.32) }
                            GradientStop { position: 1; color: Qt.rgba(1, 0.416, 0.157, 0.08) }
                        }
                        FocusRing { target: prow; radius_: 12 }
                    }
                    PlaylistCover { id: pc; x: 8; anchors.verticalCenter: parent.verticalCenter; width: 60; height: 60; cover: prow.cover; kind: prow.kind }
                    Column {
                        anchors.left: pc.right
                        anchors.leftMargin: 14
                        anchors.right: pmore.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Label { width: parent.width; text: prow.name; font.pixelSize: 15; font.weight: prow.on ? Font.Bold : Font.DemiBold }
                        Label { width: parent.width; role: "meta"; color: prow.on ? Theme.textEmphasis : Theme.textSecondary
                            text: root.totalText({ itemCount: prow.itemCount, durationMs: prow.durationMs }) }
                    }
                    IconButton {
                        id: pmore
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        size: 36; iconSize: 18; iconName: "more-vertical"; variant: "tint"
                        label: qsTr("Options for %1").arg(prow.name)
                        onClicked: { listMenu.playlistId = prow.playlistId; listMenu.popup(this, 0, height) }
                    }
                }
            }

            // ------------------------------------------------ open playlist
            PlaylistDetail {
                visible: !root.compact && root.selectedId !== ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                page: root
            }

            // ------------------------------------------------ details panel
            PlaylistSidePanel {
                visible: !root.compact && root.wide && root.selectedId !== ""
                Layout.fillHeight: true
                Layout.preferredWidth: 270
                page: root
            }
        }
    }

    // Phone: the open playlist covers the list (M3 style).
    ColumnLayout {
        anchors.fill: parent
        visible: root.compact && root.phoneDetail && root.selectedId !== ""
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.topMargin: 6
            IconButton { iconName: "chevron-left"; label: qsTr("Back to playlists"); onClicked: root.phoneDetail = false }
            Item { Layout.fillWidth: true }
        }
        PlaylistDetail {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            page: root
        }
    }

    // Menus are opened by the child panels through these.
    function openPlaylistMenu(button) { playlistMenu.popup(button, 0, button.height) }
    function openTrackMenu(button, index, url) { trackMenu.index = index; trackMenu.url = url; trackMenu.popup(button, 0, button.height) }
    function addMedia() { addFiles.open() }
    function rename() { renameDialog.ask(current.name) }
    function describe() { describeDialog.ask(current.description) }
    function exportFile() { exportDialog.open() }
    function importFile() { importDialog.open() }
    function askDelete() { confirmDelete.open() }
}
