import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Pulse
import Pulse.Core

// 01 — Welcome / Home. Default only for an empty launch.
T.ScrollView {
    id: root
    property bool compact: false
    readonly property int pad: compact ? 16 : 36
    signal openFile()
    signal openFolder()
    signal openUrl()
    signal playRecent(url address)
    signal navigate(string route)

    contentWidth: availableWidth
    T.ScrollBar.horizontal.policy: T.ScrollBar.AlwaysOff

    HeroScene {
        width: root.availableWidth
        height: root.compact ? 300 : 330
        planetX: width * (root.compact ? 0.9 : 0.82)
        planetY: root.compact ? 18 : 92
        planetR: root.compact ? 44 : Math.min(112, width * 0.09)
        horizon: root.compact ? 200 : 214
    }

    ColumnLayout {
        width: root.availableWidth
        spacing: root.compact ? 20 : 26

        // Hero copy.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.topMargin: root.compact ? 12 : 34
            spacing: 12
            Row {
                spacing: 14
                Text {
                    id: lead
                    text: qsTr("Play anything")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? Theme.displaySizeCompact : 46
                    font.weight: Font.ExtraBold
                    font.letterSpacing: -0.9
                }
                Item {
                    width: accentWord.implicitWidth
                    height: accentWord.implicitHeight
                    Text {
                        id: accentWord
                        visible: false
                        text: qsTr("instantly.")
                        font: lead.font
                    }
                    LinearGradient {
                        anchors.fill: parent
                        source: accentWord
                        start: Qt.point(0, 0)
                        end: Qt.point(width, height)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.accentBright }
                            GradientStop { position: 0.6; color: "#FF9A3A" }
                            GradientStop { position: 1.0; color: Theme.highlight }
                        }
                    }
                }
                Accessible.role: Accessible.Heading
                Accessible.name: qsTr("Play anything instantly.")
            }
            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: 520
                color: Theme.textEmphasis
                font.pixelSize: 17
                lineHeight: 1.2
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                text: qsTr("Open a file, folder, or stream and start watching or listening in seconds. No library setup. No waiting.")
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.maximumWidth: 960 + 2 * root.pad
            columns: root.compact ? 2 : 3
            columnSpacing: root.compact ? 10 : 16
            rowSpacing: 10

            PulseButton {
                Layout.fillWidth: true
                Layout.columnSpan: root.compact ? 2 : 1
                variant: "primary"; iconName: "file-play"
                text: qsTr("Open File")
                description: root.compact ? "" : qsTr("Video, Audio, Subtitles")
                large: root.compact
                onClicked: root.openFile()
            }
            PulseButton { Layout.fillWidth: true; iconName: "folder"; large: root.compact; text: root.compact ? qsTr("Open Folder") : qsTr("Open Folder"); description: root.compact ? "" : qsTr("Play all media files"); onClicked: root.openFolder() }
            PulseButton { Layout.fillWidth: true; iconName: "link"; large: root.compact; text: qsTr("Open URL"); description: root.compact ? "" : qsTr("Stream from the web"); onClicked: root.openUrl() }
        }

        // Drop target (the whole window accepts drops).
        Item {
            visible: !root.compact
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            implicitHeight: 136
            DashedFrame { anchors.fill: parent; radius: 14 }
            Column {
                anchors.centerIn: parent
                spacing: 10
                Logo { anchors.horizontalCenter: parent.horizontalCenter; wordmark: false; markHeight: 38 }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Drop video, audio, or subtitle files here"); font.pixelSize: 15; font.weight: Font.DemiBold }
                Label { anchors.horizontalCenter: parent.horizontalCenter; role: "meta"; color: Theme.accentText; font.pixelSize: 13; text: qsTr("or click to open files")
                    TapHandler { onTapped: root.openFile() } }
            }
        }

        // Recent files.
        Glass {
            visible: Prefs.keepRecent
            Layout.fillWidth: true
            Layout.leftMargin: root.compact ? 0 : root.pad
            Layout.rightMargin: root.compact ? 0 : root.pad
            color: root.compact ? "transparent" : Theme.glass
            border.width: root.compact ? 0 : 1
            implicitHeight: recentCol.implicitHeight + (root.compact ? 0 : 36)

            ColumnLayout {
                id: recentCol
                anchors.fill: parent
                anchors.margins: root.compact ? 0 : 18
                anchors.leftMargin: root.compact ? root.pad : 20
                anchors.rightMargin: root.compact ? root.pad : 20
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    PulseIcon { name: "clock"; color: Theme.text; size: 20 }
                    Label { Layout.fillWidth: true; role: "section"; font.pixelSize: 19; text: qsTr("Recent Files"); Accessible.role: Accessible.Heading }
                    PulseButton { visible: Recent.count > 0; variant: "quiet"; text: qsTr("Clear"); implicitHeight: 34; onClicked: Recent.clear() }
                }
                Label {
                    visible: Recent.count === 0
                    color: Theme.textSecondary
                    text: qsTr("Files you open appear here. They stay on this device.")
                }
                // Positioner, not a Layout: Qt 6.4 layouts can crash when a
                // Repeater inside them gains or loses items.
                Grid {
                    id: recentGrid
                    Layout.fillWidth: true
                    columns: root.compact ? 1 : 4
                    columnSpacing: 18
                    rowSpacing: root.compact ? 6 : 18
                    readonly property real tileWidth: root.compact ? width : (width - 3 * columnSpacing) / 4
                    Repeater {
                        model: Recent
                        delegate: T.AbstractButton {
                            id: tile
                            required property int index
                            required property url url
                            required property string title
                            required property string detail
                            required property real progress
                            required property bool isAudio
                            required property bool isStream
                            required property double length
                            required property var when
                            visible: index < (root.compact ? 5 : 4)
                            readonly property real tileWidth: recentGrid.tileWidth
                            width: tileWidth
                            height: visible ? (root.compact ? 78 : Math.round(tileWidth * 9 / 16) + 58) : 0
                            Accessible.name: (progress > 0 ? qsTr("Resume %1") : qsTr("Play %1")).arg(title)
                            onClicked: root.playRecent(url)
                            background: Item { FocusRing { target: tile; radius_: 10 } }

                            MediaThumb {
                                id: thumb
                                width: root.compact ? 112 : parent.width
                                height: root.compact ? 63 : Math.round(tile.tileWidth * 9 / 16)
                                y: root.compact ? 7 : 0
                                source: tile.url
                                audio: tile.isAudio
                                stream: tile.isStream
                                progress: tile.progress
                                corner: tile.length > 0 ? MediaInput.formatTime(tile.length) : ""
                                scale: tile.hovered ? 1.02 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.motionFast } }
                            }
                            Column {
                                x: root.compact ? 126 : 0
                                y: root.compact ? 16 : thumb.height + 12
                                width: parent.width - x - 34
                                spacing: 3
                                Label { width: parent.width; text: tile.title; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Label { width: parent.width; role: "meta"; secondary: true; text: tile.detail + " · " + MediaInput.relativeTime(tile.when) }
                            }
                            IconButton {
                                anchors.right: parent.right
                                anchors.rightMargin: -8
                                y: root.compact ? 14 : thumb.height + 8
                                iconName: "more-vertical"; iconSize: 18; size: 36; variant: "tint"
                                label: qsTr("Options for %1").arg(tile.title)
                                onClicked: menu.popup()
                                T.Menu {
                                    id: menu
                                    T.MenuItem { text: qsTr("Play"); onTriggered: root.playRecent(tile.url) }
                                    T.MenuItem { text: qsTr("Remove from recent"); onTriggered: Recent.remove(tile.index) }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Quick access.
        ColumnLayout {
            visible: !root.compact
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            spacing: 14
            RowLayout {
                spacing: 10
                PulseIcon { name: "zap"; color: Theme.accent; size: 20 }
                Label { role: "section"; font.pixelSize: 19; text: qsTr("Quick Access") }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: root.availableWidth > 1150 ? 5 : 3
                columnSpacing: 14
                rowSpacing: 14
                Repeater {
                    model: [
                        { r: "library", i: "library", t: qsTr("Library"), d: qsTr("Browse your media") },
                        { r: "playlists", i: "playlists", t: qsTr("Playlists"), d: qsTr("Create and manage") },
                        { r: "network", i: "network", t: qsTr("Network Streams"), d: qsTr("Play from URL, TV, NAS") },
                        { r: "convert", i: "convert", t: qsTr("Convert"), d: qsTr("Change formats") },
                        { r: "settings", i: "settings", t: qsTr("Settings"), d: qsTr("Customize Pulse") }
                    ]
                    delegate: PulseButton {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        iconName: modelData.i
                        text: modelData.t
                        description: modelData.d
                        chevron: true
                        font.pixelSize: 14
                        onClicked: root.navigate(modelData.r)
                    }
                }
            }
        }

        // Tips & shortcuts.
        Glass {
            visible: !root.compact
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            Layout.bottomMargin: 32
            implicitHeight: 84
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                spacing: 28
                Row {
                    spacing: 14
                    PulseIcon { anchors.verticalCenter: parent.verticalCenter; name: "bulb"; color: Theme.highlight; size: 26 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Label { text: qsTr("Tips & Shortcuts"); font.weight: Font.DemiBold; font.pixelSize: 15 }
                        Label { role: "meta"; secondary: true; text: qsTr("Control playback faster with keyboard shortcuts.") }
                    }
                }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [["Space", qsTr("Play / Pause")], ["← →", qsTr("Seek")], ["F", qsTr("Fullscreen")], ["M", qsTr("Mute")], ["V", qsTr("Subtitles")]]
                    delegate: Column {
                        required property var modelData
                        visible: root.availableWidth > 1100
                        spacing: 6
                        Kbd { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[0] }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; role: "meta"; secondary: true; text: modelData[1] }
                    }
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: qsTr("View all shortcuts") + "  →"
                    color: Theme.accentText
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    TapHandler { onTapped: root.navigate("settings") }
                }
            }
        }
        Item { Layout.preferredHeight: root.compact ? 16 : 0 }
    }
}
