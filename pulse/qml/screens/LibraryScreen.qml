import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Dialogs
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 06 — Media Library: folders the user chose, sorted into Movies, TV Shows,
// Music and Other. Files are never moved or changed.
Item {
    id: root
    property bool compact: false
    readonly property int pad: compact ? 16 : 32
    property bool listMode: false
    signal play(var urls, int start)
    signal enqueue(var urls)
    signal addToPlaylist(var urls)
    signal convert(var urls)
    signal showDetails(url url)
    signal edit(url url)

    readonly property var categories: [
        { value: "all", text: qsTr("All"), name: qsTr("All Media"), icon: "library" },
        { value: "movies", text: qsTr("Movies"), name: qsTr("Movies"), icon: "film" },
        { value: "tv", text: qsTr("TV Shows"), name: qsTr("TV Shows"), icon: "tv" },
        { value: "music", text: qsTr("Music"), name: qsTr("Music"), icon: "music" },
        { value: "other", text: qsTr("Other"), name: qsTr("Other"), icon: "file" }
    ]
    readonly property bool empty: Library.folders.length === 0
    readonly property bool overview: Library.category === "all" && Library.search === "" && !empty

    function categoryName(v) { return categories.find(c => c.value === v).name }

    // Music plays on from the chosen track; a film plays alone.
    function playItem(index, url, isAudio) {
        if (isAudio) {
            const urls = Library.viewUrls().filter(u => MediaInput.isAudio(u))
            root.play(urls, Math.max(0, urls.findIndex(u => u.toString() === url.toString())))
        } else {
            root.play([url], 0)
        }
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Add a folder to the library")
        onAccepted: Library.addFolder(selectedFolder)
    }

    // One context menu for every tile.
    PulseMenu {
        id: itemMenu
        property url url
        property bool isAudio: false
        PulseMenuItem { text: qsTr("Play"); iconName: "play"; onTriggered: root.play([itemMenu.url], 0) }
        PulseMenuItem { text: qsTr("Details"); iconName: "info"; onTriggered: root.showDetails(itemMenu.url) }
        PulseMenuItem { text: qsTr("Add to Queue"); iconName: "queue"; onTriggered: root.enqueue([itemMenu.url]) }
        PulseMenuItem { text: qsTr("Add to Playlist…"); iconName: "playlists"; onTriggered: root.addToPlaylist([itemMenu.url]) }
        PulseMenuItem { text: qsTr("Convert…"); iconName: "convert"; onTriggered: root.convert([itemMenu.url]) }
        PulseMenuItem { text: qsTr("Edit…"); iconName: "crop"; visible: !itemMenu.isAudio; height: visible ? implicitHeight : 0; onTriggered: root.edit(itemMenu.url) }
        PulseMenuItem { text: qsTr("Show in Folder"); iconName: "folder"; onTriggered: Qt.openUrlExternally(MediaInput.folderOf(itemMenu.url)) }
    }
    function openMenu(button, url, isAudio) {
        itemMenu.url = url
        itemMenu.isAudio = isAudio
        itemMenu.popup(button, 0, button.height)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ------------------------------------------------------------ header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.topMargin: root.compact ? 10 : 24
            spacing: 24
            ColumnLayout {
                Layout.fillWidth: root.compact
                spacing: 4
                Label { Layout.fillWidth: root.compact; role: "title"; font.pixelSize: root.compact ? 26 : 30; text: qsTr("Media Library"); Accessible.role: Accessible.Heading }
                Label { visible: !root.compact; color: Theme.textEmphasis; font.pixelSize: 14; text: qsTr("Your movies, shows, and music. All in one place.") }
            }
            SearchField {
                id: search
                visible: !root.compact && !root.empty
                Layout.fillWidth: true
                Layout.maximumWidth: 420
                placeholderText: qsTr("Search media, titles, artists, or folders…")
                onTextChanged: Library.search = text
            }
            Item { Layout.fillWidth: true; visible: !root.compact && root.empty }
            Row {
                spacing: 10
                PulseButton {
                    visible: !root.compact
                    iconName: "folder-plus"
                    text: qsTr("Add Folder")
                    onClicked: folderDialog.open()
                }
                PulseButton {
                    visible: !root.compact && !root.empty
                    iconName: "refresh"
                    text: Library.scanning ? qsTr("Scanning…") : qsTr("Scan Library")
                    enabled: !Library.scanning
                    onClicked: Library.rescan()
                }
                IconButton { visible: root.compact; iconName: "folder-plus"; variant: "square"; label: qsTr("Add Folder"); onClicked: folderDialog.open() }
                Rectangle {
                    visible: !root.empty && !root.compact
                    width: 88; height: Theme.touchTarget
                    radius: 10
                    color: Theme.glass
                    border.width: 1
                    border.color: Theme.glassBorder
                    Row {
                        anchors.centerIn: parent
                        IconButton { size: 40; iconName: "grid"; label: qsTr("Grid view"); checkedTint: !root.listMode; onClicked: root.listMode = false }
                        IconButton { size: 40; iconName: "list"; label: qsTr("List view"); checkedTint: root.listMode; onClicked: root.listMode = true }
                    }
                }
                IconButton {
                    visible: !root.empty
                    iconName: "more"; variant: "square"; label: qsTr("Sort and more")
                    onClicked: sortMenu.popup(this, 0, height)
                    PulseMenu {
                        id: sortMenu
                        PulseMenuItem { text: qsTr("Sort by Date Added"); iconName: Library.sort === "added" ? "check" : ""; onTriggered: Library.sort = "added" }
                        PulseMenuItem { text: qsTr("Sort by Title"); iconName: Library.sort === "title" ? "check" : ""; onTriggered: Library.sort = "title" }
                        PulseMenuItem { text: qsTr("Sort by Year"); iconName: Library.sort === "year" ? "check" : ""; onTriggered: Library.sort = "year" }
                        PulseMenuItem { text: qsTr("Play All"); iconName: "play"; enabled: Library.count > 0; onTriggered: root.play(Library.viewUrls(), 0) }
                        PulseMenuItem { visible: root.compact; height: visible ? implicitHeight : 0; text: qsTr("Scan Library"); iconName: "refresh"; onTriggered: Library.rescan() }
                    }
                }
            }
        }
        SearchField {
            visible: root.compact && !root.empty
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.topMargin: 10
            placeholderText: qsTr("Search media…")
            onTextChanged: Library.search = text
        }
        PillTabs {
            visible: !root.empty
            Layout.fillWidth: true
            Layout.leftMargin: root.compact ? root.pad : root.pad + (sources.visible ? sources.width + 24 : 0)
            Layout.rightMargin: root.pad
            Layout.topMargin: 14
            model: root.categories
            value: Library.category
            onActivated: (v) => Library.category = v
        }

        // ------------------------------------------------------------ body
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 18
            spacing: 24

            // Sources and folders (06, left column).
            Flickable {
                id: sources
                visible: !root.compact && !root.empty
                Layout.fillHeight: true
                Layout.preferredWidth: 212
                Layout.leftMargin: root.pad
                contentHeight: sourceCol.implicitHeight + 24
                clip: true
                Column {
                    id: sourceCol
                    width: parent.width
                    spacing: 4
                    Item {
                        width: parent.width; height: 36
                        Label { anchors.verticalCenter: parent.verticalCenter; role: "section"; font.pixelSize: 16; text: qsTr("Sources") }
                        IconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; size: 32; iconSize: 16; iconName: "plus"; label: qsTr("Add Folder"); onClicked: folderDialog.open() }
                    }
                    Repeater {
                        model: root.categories
                        delegate: T.AbstractButton {
                            id: src
                            required property var modelData
                            readonly property bool on: Library.category === modelData.value
                            width: sourceCol.width
                            height: 38
                            focusPolicy: Qt.StrongFocus
                            Accessible.name: modelData.name
                            onClicked: Library.category = modelData.value
                            background: Rectangle {
                                radius: 8
                                gradient: src.on ? srcFill : null
                                color: src.on ? Theme.accent : src.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                                Gradient {
                                    id: srcFill
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: Qt.rgba(1, 0.416, 0.157, 0.85) }
                                    GradientStop { position: 1; color: Qt.rgba(0.886, 0.314, 0.102, 0.55) }
                                }
                                FocusRing { target: src; radius_: 8 }
                            }
                            contentItem: RowLayout {
                                spacing: 12
                                PulseIcon { Layout.leftMargin: 4; name: src.modelData.icon; size: 17; color: src.on ? Theme.textOnAccent : Theme.textEmphasis }
                                Label { Layout.fillWidth: true; text: src.modelData.name; font.pixelSize: 14; font.weight: src.on ? Font.Bold : Font.Medium; color: src.on ? Theme.textOnAccent : Theme.text }
                                Label { Layout.rightMargin: 6; text: (Library.counts[src.modelData.value] || 0).toLocaleString(Qt.locale(), "f", 0); role: "meta"; color: src.on ? Theme.textOnAccent : Theme.textSecondary }
                            }
                        }
                    }
                    Item { width: 1; height: 18 }
                    Label { role: "section"; font.pixelSize: 16; text: qsTr("Folders"); height: 32 }
                    Repeater {
                        model: Library.folders
                        delegate: Item {
                            id: folderRow
                            required property var modelData
                            width: sourceCol.width
                            height: 50
                            PulseIcon { id: fIcon; anchors.verticalCenter: parent.verticalCenter; name: "folder"; size: 22; color: folderRow.modelData.online ? Theme.accent : Theme.iconMuted }
                            Column {
                                anchors.left: fIcon.right
                                anchors.leftMargin: 12
                                anchors.right: fMore.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Label { width: parent.width; text: folderRow.modelData.name; font.pixelSize: 14 }
                                Label { width: parent.width; role: "meta"; secondary: true; elide: Text.ElideMiddle
                                    text: folderRow.modelData.online ? folderRow.modelData.display : qsTr("Offline · %1").arg(folderRow.modelData.display) }
                            }
                            IconButton {
                                id: fMore
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                size: 32; iconSize: 16; iconName: "more-vertical"; variant: "tint"
                                label: qsTr("Options for %1").arg(folderRow.modelData.name)
                                onClicked: folderMenu.popup(this, 0, height)
                                PulseMenu {
                                    id: folderMenu
                                    PulseMenuItem { text: qsTr("Open Folder"); iconName: "folder"; onTriggered: Qt.openUrlExternally(MediaInput.localUrl(folderRow.modelData.path)) }
                                    PulseMenuItem { text: qsTr("Scan Again"); iconName: "refresh"; onTriggered: Library.rescan() }
                                    PulseMenuItem { text: qsTr("Remove from Library"); iconName: "trash"; danger: true; onTriggered: Library.removeFolder(folderRow.modelData.path) }
                                }
                            }
                        }
                    }
                    PulseButton { variant: "quiet"; iconName: "plus"; text: qsTr("Add Folder…"); leftPadding: 0; onClicked: folderDialog.open() }
                }
            }

            // ---------------------------------------------------- content
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: root.compact || root.empty ? root.pad : 0
                Layout.rightMargin: root.pad

                EmptyLibrary {
                    visible: root.empty
                    anchors.fill: parent
                    onAddFolder: folderDialog.open()
                }

                GridView {
                    id: grid
                    visible: !root.empty
                    anchors.fill: parent
                    clip: true
                    readonly property int gap: 16
                    readonly property int columns: Math.max(2, Math.floor((width + gap) / (root.compact ? 140 : 150)))
                    readonly property real tileWidth: (width - (columns - 1) * gap) / columns
                    cellWidth: root.listMode ? width : tileWidth + gap * (columns - 1) / columns
                    cellHeight: root.listMode ? 68 : Math.round(tileWidth * 0.9) + 62
                    model: Library
                    // Refreshes reset the model; without this the view jumps past its header.
                    currentIndex: -1
                    highlightFollowsCurrentItem: false
                    boundsBehavior: Flickable.StopAtBounds
                    T.ScrollBar.vertical: T.ScrollBar { policy: T.ScrollBar.AsNeeded }
                    header: LibraryOverview {
                        width: grid.width
                        overview: root.overview
                        compact: root.compact
                        title: Library.search !== "" ? qsTr("Results for “%1”").arg(Library.search)
                             : root.overview ? qsTr("All Media") : root.categoryName(Library.category)
                        onPlayUrl: (url, isAudio) => root.play([url], 0)
                        onMenuFor: (button, url, isAudio) => root.openMenu(button, url, isAudio)
                    }
                    footer: Item {
                        width: grid.width
                        height: Library.count === 0 ? 160 : 24
                        Label {
                            visible: Library.count === 0
                            anchors.centerIn: parent
                            secondary: true
                            text: Library.scanning ? qsTr("Scanning your folders…")
                                : Library.search !== "" ? qsTr("Nothing matches “%1”.").arg(Library.search)
                                : qsTr("Nothing here yet.")
                        }
                    }
                    delegate: Item {
                        id: cell
                        required property int index
                        required property url url
                        required property string title
                        required property string subtitle
                        required property string quality
                        required property bool isAudio
                        required property bool available
                        required property double durationMs
                        width: grid.cellWidth
                        height: grid.cellHeight

                        PosterTile {
                            visible: !root.listMode
                            width: grid.tileWidth
                            height: parent.height - grid.gap
                            url: cell.url; title: cell.title; subtitle: cell.subtitle; quality: cell.quality
                            isAudio: cell.isAudio; available: cell.available
                            onActivated: root.playItem(cell.index, cell.url, cell.isAudio)
                            onMenu: (button) => root.openMenu(button, cell.url, cell.isAudio)
                        }
                        LibraryRow {
                            visible: root.listMode
                            width: parent.width
                            height: parent.height - 6
                            url: cell.url; title: cell.title; subtitle: cell.subtitle; quality: cell.quality
                            isAudio: cell.isAudio; available: cell.available; durationMs: cell.durationMs
                            onActivated: root.playItem(cell.index, cell.url, cell.isAudio)
                            onMenu: (button) => root.openMenu(button, cell.url, cell.isAudio)
                        }
                    }
                }
            }
        }
    }
}
