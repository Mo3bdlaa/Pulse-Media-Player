import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 07 — Media Details: everything the file itself says — tags, tracks,
// chapters, frames — plus where it lives and when it was played here.
T.ScrollView {
    id: root
    property url url
    property bool compact: false
    property string tab: "overview"
    readonly property int pad: compact ? 16 : 32
    signal back()
    signal playAt(url url, double ms)
    signal enqueue(var urls)
    signal addToPlaylist(var urls)
    signal convert(var urls)

    contentWidth: availableWidth
    T.ScrollBar.horizontal.policy: T.ScrollBar.AlwaysOff
    onUrlChanged: { tab = "overview"; contentItem.contentY = 0 }

    MediaInspector { id: inspector; url: root.visible ? root.url : "" }

    readonly property var d: inspector.details
    readonly property var lib: (Library.revision, Library.item(url))
    readonly property var hist: (Recent.revision, Recent.history(url))
    readonly property var videos: d.video || []
    readonly property var audios: d.audio || []
    readonly property var subs: d.subtitles || []
    readonly property var chapters: inspector.chapters
    readonly property var v: videos.length ? videos[0] : null
    readonly property bool isAudio: videos.length === 0 && audios.length > 0
    readonly property double duration: d.durationMs || lib.durationMs || 0
    readonly property string title: lib.title || d.title || MediaInput.displayName(url)
    readonly property int year: lib.year || MediaFormat.year(d.date)
    readonly property var genres: (d.genre || "").split(/[,;\/]/).map(s => s.trim()).filter(s => s !== "")
    readonly property bool wide: availableWidth >= 1100
    readonly property var facts: [
        [qsTr("Director"), d.director || ""],
        [qsTr("Cast"), d.actors || ""],
        [qsTr("Artist"), d.artist || ""],
        [qsTr("Album"), d.album || ""],
        [qsTr("Show"), d.showName ? d.showName + (d.season ? " · " + qsTr("Season %1").arg(d.season) : "") + (d.episode ? " · " + qsTr("Episode %1").arg(d.episode) : "") : ""],
        [qsTr("Studio"), d.publisher || ""],
        [qsTr("Release Date"), d.date || ""],
        [qsTr("Rating"), d.rating || ""],
        [qsTr("Copyright"), d.copyright || ""]
    ].filter(f => f[1] !== "")

    PulseMenu {
        id: moreMenu
        PulseMenuItem { text: qsTr("Add to Playlist…"); iconName: "playlists"; onTriggered: root.addToPlaylist([root.url]) }
        PulseMenuItem { text: qsTr("Convert…"); iconName: "convert"; onTriggered: root.convert([root.url]) }
        PulseMenuItem { text: qsTr("Show in Folder"); iconName: "folder"; onTriggered: Qt.openUrlExternally(MediaInput.folderOf(root.url)) }
    }

    ColumnLayout {
        width: root.availableWidth
        spacing: 0

        // ------------------------------------------------------------ hero
        Item {
            Layout.fillWidth: true
            implicitHeight: hero.implicitHeight + (root.compact ? 70 : 96)
            clip: true

            // Backdrop: a frame from the file itself, faded into the page.
            MediaThumb {
                anchors.fill: parent
                radius: 0
                source: root.url
                audio: root.isAudio
                framePos: 0.42
                opacity: 0.42
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(0.055, 0.06, 0.075, 0.97) }
                    GradientStop { position: 0.55; color: Qt.rgba(0.055, 0.06, 0.075, 0.6) }
                    GradientStop { position: 1; color: Qt.rgba(0.055, 0.06, 0.075, 0.35) }
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 120
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Theme.bg }
                }
            }

            RowLayout {
                id: header
                x: root.pad - 8
                y: root.compact ? 8 : 18
                width: parent.width - 2 * root.pad + 8
                spacing: 10
                IconButton { iconName: "chevron-left"; label: qsTr("Back"); variant: "overlay"; onClicked: root.back() }
                Label { Layout.fillWidth: true; text: qsTr("Media Details"); font.pixelSize: 18; font.weight: Font.DemiBold }
            }

            GridLayout {
                id: hero
                x: root.pad
                y: header.y + header.height + (root.compact ? 12 : 22)
                width: parent.width - 2 * root.pad
                columns: root.compact ? 1 : root.wide && root.facts.length > 0 ? 3 : 2
                columnSpacing: 30
                rowSpacing: 18

                // Poster: a frame (video) or the cover (audio).
                Item {
                    Layout.alignment: root.compact ? Qt.AlignHCenter : Qt.AlignTop
                    Layout.preferredWidth: root.compact ? 190 : 210
                    Layout.preferredHeight: root.isAudio ? Layout.preferredWidth : Layout.preferredWidth * 1.4
                    AccentGlow { strength: 0.35; glowRadius: 24 }
                    MediaThumb {
                        anchors.fill: parent
                        radius: 14
                        source: root.url
                        audio: root.isAudio
                        framePos: 0.42
                        badge: root.v ? MediaFormat.shortQuality(root.v.width, root.v.height) : ""
                    }
                    Rectangle { anchors.fill: parent; radius: 14; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1) }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 10
                    Label {
                        Layout.fillWidth: true
                        text: root.title + (root.year > 0 && root.title.indexOf(String(root.year)) < 0 && !root.isAudio ? " (" + root.year + ")" : "")
                        font.pixelSize: root.compact ? 28 : 40
                        font.weight: Font.ExtraBold
                        font.letterSpacing: -0.6
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        Accessible.role: Accessible.Heading
                    }
                    Label {
                        Layout.fillWidth: true
                        color: Theme.textEmphasis
                        font.pixelSize: 16
                        text: [root.year > 0 ? String(root.year) : "", MediaFormat.runtime(root.duration),
                               root.v ? MediaFormat.shortQuality(root.v.width, root.v.height) : "",
                               root.audios.length ? MediaFormat.channels(root.audios[0].channels) : ""].filter(s => s !== "").join("  •  ")
                    }
                    Flow {
                        Layout.fillWidth: true
                        visible: chipRepeater.count > 0
                        spacing: 8
                        Repeater {
                            id: chipRepeater
                            model: root.genres.length ? root.genres : (root.lib.category ? [{ movies: qsTr("Movie"), tv: qsTr("TV Show"), music: qsTr("Music"), other: qsTr("Video") }[root.lib.category]] : [])
                            delegate: Rectangle {
                                required property var modelData
                                width: chipText.implicitWidth + 22
                                height: 30
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1
                                border.color: Theme.glassBorder
                                Text { id: chipText; anchors.centerIn: parent; text: parent.modelData; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Medium }
                            }
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 640
                        visible: text !== ""
                        text: root.d.description || ""
                        color: Theme.textEmphasis
                        font.pixelSize: 15
                        lineHeight: 1.3
                        wrapMode: Text.WordWrap
                        maximumLineCount: root.compact ? 6 : 5
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: !root.d.description && !inspector.loading
                        text: MediaInput.describe(root.url) + (root.lib.folder ? "  •  " + qsTr("In your library") : "")
                        color: Theme.textSecondary
                        font.pixelSize: 14
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 10
                        PulseButton {
                            variant: "primary"
                            iconName: "play"
                            large: true
                            text: root.hist.position > 0 ? qsTr("Resume %1").arg(MediaInput.formatTime(root.hist.position)) : qsTr("Play")
                            onClicked: root.playAt(root.url, root.hist.position || 0)
                        }
                        PulseButton { visible: root.hist.position > 0; large: true; iconName: "restore"; text: qsTr("Start Over"); onClicked: root.playAt(root.url, 0) }
                        PulseButton { large: true; iconName: "queue"; text: qsTr("Add to Queue"); onClicked: root.enqueue([root.url]) }
                        IconButton { size: 56; variant: "square"; iconName: "more"; label: qsTr("More actions"); onClicked: moreMenu.popup(this, 0, height) }
                    }
                }

                // Credits and release facts, when the file carries them.
                Glass {
                    visible: !root.compact && root.wide && root.facts.length > 0
                    Layout.preferredWidth: 380
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: factCol.implicitHeight + 32
                    radius: 14
                    Column {
                        id: factCol
                        x: 16; y: 16
                        width: parent.width - 32
                        Repeater {
                            model: root.facts
                            delegate: FactRow { required property var modelData; key: modelData[0]; value: modelData[1]; keyWidth: 110 }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------ tabs
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            implicitHeight: 46
            Flickable {
                anchors.fill: parent
                contentWidth: tabs.width
                interactive: contentWidth > width
                clip: true
                UnderlineTabs {
                    id: tabs
                    value: root.tab
                    model: [
                        { value: "overview", text: qsTr("Overview") },
                        { value: "technical", text: qsTr("Technical Details") },
                        { value: "chapters", text: root.chapters.length ? qsTr("Chapters (%1)").arg(root.chapters.length) : qsTr("Chapters") },
                        { value: "audio", text: qsTr("Audio Tracks (%1)").arg(root.audios.length) },
                        { value: "subtitles", text: qsTr("Subtitles (%1)").arg(root.subs.length) }
                    ]
                    onActivated: (v) => root.tab = v
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.glassBorder; z: -1 }
        }

        // ------------------------------------------------------------ cards
        GridLayout {
            id: cards
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.topMargin: 18
            readonly property bool overview: root.tab === "overview"
            columns: root.compact ? 1 : overview ? (root.availableWidth > 1180 ? 3 : 2) : root.tab === "technical" ? 2 : 1
            columnSpacing: 16
            rowSpacing: 16

            DetailCard {
                visible: cards.overview || root.tab === "technical"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                iconName: "info"
                title: qsTr("Media Information")
                action: PulseButton { visible: root.url.toString().startsWith("file:"); implicitHeight: 34; iconName: "folder"; text: qsTr("Open Folder"); font.pixelSize: 13
                    onClicked: Qt.openUrlExternally(MediaInput.folderOf(root.url)) }
                FactRow { key: qsTr("File Name"); value: root.d.fileName || MediaInput.displayName(root.url) }
                FactRow { key: qsTr("File Path"); value: root.d.filePath || "" }
                FactRow { key: qsTr("File Size"); value: MediaFormat.bytes(root.d.fileSize || 0) }
                FactRow { key: qsTr("Duration"); value: root.duration > 0 ? MediaInput.formatTime(root.duration) : "" }
                FactRow { key: qsTr("Resolution"); value: root.v ? root.v.width + " × " + root.v.height + " (" + MediaFormat.quality(root.v.width, root.v.height) + ")" : "" }
                FactRow { key: qsTr("Aspect Ratio"); value: root.v ? MediaFormat.aspect(root.v.aspect) : "" }
                FactRow { key: qsTr("Frame Rate"); value: root.v && root.v.frameRate ? Number(root.v.frameRate).toFixed(3).replace(/\.?0+$/, "") + " fps" : "" }
                FactRow { key: qsTr("Container"); value: root.d.container || "" }
                FactRow { key: qsTr("Date Added"); value: root.lib.added ? Qt.formatDateTime(root.lib.added, Qt.locale().dateTimeFormat(Locale.ShortFormat)) : "" }
                FactRow { key: qsTr("Last Played"); value: root.hist.lastPlayed ? Qt.formatDateTime(root.hist.lastPlayed, Qt.locale().dateTimeFormat(Locale.ShortFormat)) : qsTr("Not played yet") }
                FactRow { key: qsTr("Play Count"); value: root.hist.playCount ? String(root.hist.playCount) : "" }
            }

            ColumnLayout {
                visible: cards.overview || root.tab === "technical" || root.tab === "audio" || root.tab === "subtitles"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: 16

                DetailCard {
                    visible: root.videos.length > 0 && (cards.overview || root.tab === "technical")
                    Layout.fillWidth: true
                    iconName: "film"
                    title: root.videos.length > 1 ? qsTr("Video (%1 Tracks)").arg(root.videos.length) : qsTr("Video")
                    FactRow { key: qsTr("Codec"); value: MediaFormat.codec(root.v) }
                    FactRow { key: qsTr("Profile"); value: MediaFormat.profile(root.v) }
                    FactRow { key: qsTr("Resolution"); value: root.v ? root.v.width + " × " + root.v.height : "" }
                    FactRow { key: qsTr("Aspect Ratio"); value: root.v ? MediaFormat.aspect(root.v.aspect) : "" }
                    FactRow { key: qsTr("Frame Rate"); value: root.v && root.v.frameRate ? Number(root.v.frameRate).toFixed(3).replace(/\.?0+$/, "") + " fps" : "" }
                    FactRow { key: qsTr("Bitrate"); value: root.v ? MediaFormat.bitrate(root.v.bitrate) : "" }
                    FactRow { key: qsTr("Language"); value: root.v ? MediaFormat.language(root.v.language) : "" }
                }
                DetailCard {
                    visible: cards.overview || root.tab === "technical" || root.tab === "audio"
                    Layout.fillWidth: true
                    iconName: "volume"
                    title: qsTr("Audio (%1 Tracks)").arg(root.audios.length)
                    Repeater {
                        model: root.audios
                        delegate: TrackRow {
                            required property var modelData
                            required property int index
                            number: index + 1
                            current: Player.url.toString() === root.url.toString() && (Player.audioTracks[index] || {}).selected === true
                            name: [MediaFormat.language(modelData.language), modelData.description || modelData.name].filter(s => s).join(" – ") || qsTr("Track %1").arg(index + 1)
                            codec: MediaFormat.codec(modelData) + (modelData.channels ? " " + MediaFormat.channels(modelData.channels) : "")
                            detail: [modelData.sampleRate ? (modelData.sampleRate / 1000) + " kHz" : "", MediaFormat.bitrate(modelData.bitrate)].filter(s => s).join(" · ")
                        }
                    }
                    Label { visible: root.audios.length === 0; text: inspector.loading ? qsTr("Reading…") : qsTr("No audio"); secondary: true; font.pixelSize: 13 }
                }
                DetailCard {
                    visible: !root.isAudio && (cards.overview || root.tab === "technical" || root.tab === "subtitles")
                    Layout.fillWidth: true
                    iconName: "subtitles"
                    title: qsTr("Subtitles (%1 Tracks)").arg(root.subs.length)
                    Repeater {
                        model: root.subs
                        delegate: TrackRow {
                            required property var modelData
                            required property int index
                            number: index + 1
                            current: Player.url.toString() === root.url.toString() && (Player.subtitleTracks[index] || {}).selected === true
                            name: [MediaFormat.language(modelData.language), modelData.description || modelData.name].filter(s => s).join(" – ") || qsTr("Track %1").arg(index + 1)
                            codec: MediaFormat.codec(modelData)
                            detail: modelData.encoding || ""
                        }
                    }
                    Label { visible: root.subs.length === 0; secondary: true; font.pixelSize: 13; wrapMode: Text.WordWrap; width: parent.width
                        text: qsTr("No subtitles inside the file. Subtitle files dropped on the player are added while it plays.") }
                }
            }

            DetailCard {
                visible: !root.isAudio && (cards.overview || root.tab === "chapters")
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                Layout.columnSpan: cards.overview && cards.columns === 2 ? 2 : 1
                iconName: "list"
                title: root.chapters.length ? qsTr("Chapters (%1)").arg(root.chapters.length) : qsTr("Chapters")
                Repeater {
                    model: root.chapters
                    delegate: T.AbstractButton {
                        id: ch
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: 54
                        focusPolicy: Qt.StrongFocus
                        Accessible.name: qsTr("Play from %1").arg(modelData.name)
                        onClicked: root.playAt(root.url, modelData.time)
                        background: Rectangle {
                            radius: 8
                            color: ch.index === 0 ? Qt.rgba(1, 0.416, 0.157, 0.14) : ch.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                            border.width: ch.index === 0 ? 1 : 0
                            border.color: Qt.rgba(1, 0.416, 0.157, 0.45)
                            FocusRing { target: ch; radius_: 8 }
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10
                            spacing: 12
                            Text { anchors.verticalCenter: parent.verticalCenter; width: 18; text: ch.index + 1; color: ch.index === 0 ? Theme.accent : Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13 }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 64; height: 36; radius: 6; color: "#0B0C10"; clip: true
                                Image {
                                    anchors.fill: parent
                                    asynchronous: true
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize: Qt.size(128, 72)
                                    source: root.url.toString().startsWith("file:") ? "image://thumb/" + encodeURIComponent(root.url.toString()) + "?t=" + (ch.modelData.time + 2000) : ""
                                }
                            }
                            Label { anchors.verticalCenter: parent.verticalCenter; width: ch.width - 200; text: ch.modelData.name; font.pixelSize: 14 }
                        }
                        Label {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: MediaInput.formatTime(ch.modelData.time)
                            role: "meta"
                            color: ch.index === 0 ? Theme.accentText : Theme.textSecondary
                        }
                    }
                }
                Label {
                    visible: root.chapters.length === 0
                    width: parent.width
                    wrapMode: Text.WordWrap
                    secondary: true
                    font.pixelSize: 13
                    text: inspector.loading ? qsTr("Reading chapters…") : qsTr("This file has no chapters. Frames from across it are below.")
                }
            }
        }

        // ------------------------------------------------------------ frames
        ColumnLayout {
            visible: !root.isAudio && (root.tab === "overview" || root.tab === "chapters") && root.url.toString().startsWith("file:")
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.topMargin: 22
            Layout.bottomMargin: 32
            spacing: 12
            RowLayout {
                spacing: 10
                PulseIcon { name: "camera"; size: 20; color: Theme.text }
                Label { text: qsTr("Frames"); font.pixelSize: 16; font.weight: Font.Bold }
                Label { role: "meta"; secondary: true; text: qsTr("Click a frame to play from there") }
            }
            Grid {
                id: frames
                Layout.fillWidth: true
                columns: root.compact ? 2 : root.availableWidth > 1100 ? 6 : 4
                spacing: 12
                Repeater {
                    model: [0.08, 0.24, 0.4, 0.56, 0.72, 0.88].slice(0, root.compact ? 4 : root.availableWidth > 1100 ? 6 : 4)
                    delegate: T.AbstractButton {
                        id: frame
                        required property real modelData
                        width: (frames.width - (frames.columns - 1) * frames.spacing) / frames.columns
                        height: width * 9 / 16
                        focusPolicy: Qt.StrongFocus
                        Accessible.name: qsTr("Play from %1").arg(MediaInput.formatTime(root.duration * modelData))
                        onClicked: root.playAt(root.url, root.duration * modelData)
                        background: Item { FocusRing { target: frame; radius_: 10 } }
                        MediaThumb {
                            anchors.fill: parent
                            radius: 10
                            source: root.url
                            framePos: frame.modelData
                            corner: root.duration > 0 ? MediaInput.formatTime(root.duration * frame.modelData) : ""
                            scale: frame.hovered ? 1.03 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.motionFast } }
                        }
                    }
                }
            }
        }
        Item { Layout.preferredHeight: 24 }
    }
}
