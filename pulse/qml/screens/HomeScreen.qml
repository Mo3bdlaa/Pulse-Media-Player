import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import QtQuick.Shapes
import Pulse
import Pulse.Core

// 01 — Welcome / Home. Default only for an empty launch.
T.ScrollView {
    id: root
    property bool compact: false
    signal openFile()
    signal openFolder()
    signal openUrl()
    signal playRecent(url address)
    signal navigate(string route)

    contentWidth: availableWidth
    T.ScrollBar.horizontal.policy: T.ScrollBar.AlwaysOff

    // Brand glow: the one decorative moment, top-right; matte elsewhere.
    Shape {
        width: root.availableWidth
        height: 520
                ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.availableWidth * 0.92; centerY: -40
                centerRadius: 620
                focalX: centerX; focalY: centerY
                GradientStop { position: 0; color: Qt.rgba(1, 0.416, 0.157, 0.16) }
                GradientStop { position: 1; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: root.availableWidth; y: 0 }
            PathLine { x: root.availableWidth; y: 520 }
            PathLine { x: 0; y: 520 }
            PathLine { x: 0; y: 0 }
        }
    }

    ColumnLayout {
        width: root.availableWidth
        spacing: Theme.spaceXL + 8

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.compact ? 16 : 40
            Layout.rightMargin: Layout.leftMargin
            Layout.topMargin: root.compact ? 16 : 32
            spacing: 10
            Text {
                Layout.fillWidth: true
                textFormat: Text.StyledText
                text: qsTr("Play anything") + " <font color='" + Theme.accent + "'>" + qsTr("instantly.") + "</font>"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: root.compact ? Theme.displaySizeCompact : Theme.displaySize
                font.weight: Font.ExtraBold
                font.letterSpacing: root.compact ? -0.6 : -0.88
                wrapMode: Text.WordWrap
                Accessible.role: Accessible.Heading
                Accessible.name: qsTr("Play anything instantly.")
            }
            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: 560
                secondary: true
                font.pixelSize: 16
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                text: qsTr("Open a file, a folder or a stream and start watching or listening in seconds. No library setup, no account, no waiting.")
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.compact ? 16 : 40
            Layout.rightMargin: Layout.leftMargin
            columns: root.compact ? 2 : 3
            columnSpacing: root.compact ? 10 : 16
            rowSpacing: 10

            PulseButton {
                Layout.fillWidth: true
                Layout.columnSpan: root.compact ? 2 : 1
                variant: "primary"; large: true; iconName: "file-play"
                text: qsTr("Open File")
                description: root.compact ? "" : qsTr("Video, audio or subtitles")
                shortcutHint: root.compact ? "" : "Ctrl O"
                onClicked: root.openFile()
            }
            PulseButton { Layout.fillWidth: true; large: true; iconName: "folder"; text: root.compact ? qsTr("Folder") : qsTr("Open Folder"); description: root.compact ? "" : qsTr("Plays everything inside as a queue"); shortcutHint: root.compact ? "" : "Ctrl F"; onClicked: root.openFolder() }
            PulseButton { Layout.fillWidth: true; large: true; iconName: "link"; text: root.compact ? qsTr("URL") : qsTr("Open URL"); description: root.compact ? "" : qsTr("HTTP, HLS, RTSP and more"); shortcutHint: root.compact ? "" : "Ctrl N"; onClicked: root.openUrl() }
        }

        // Drop target hint (the whole window accepts drops).
        Rectangle {
            visible: !root.compact
            Layout.fillWidth: true
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            implicitHeight: 128
            radius: Theme.radiusPanel
            color: "transparent"
            border.width: 1.5
            border.color: Theme.border
            Column {
                anchors.centerIn: parent
                spacing: 8
                Logo { anchors.horizontalCenter: parent.horizontalCenter; wordmark: false; markHeight: 30 }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Drop video, audio or subtitle files anywhere in this window"); font.pixelSize: 15; font.weight: Font.DemiBold }
                Label { anchors.horizontalCenter: parent.horizontalCenter; role: "meta"; secondary: true; font.pixelSize: 13; text: qsTr("Several files start a queue. A subtitle dropped while playing is added to the current video.") }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.compact ? 16 : 40
            Layout.rightMargin: Layout.leftMargin
            spacing: 16
            visible: Prefs.keepRecent

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                PulseIcon { name: "clock"; color: Theme.textSecondary }
                Label { Layout.fillWidth: true; role: "section"; text: qsTr("Recent files"); Accessible.role: Accessible.Heading }
                PulseButton { visible: Recent.count > 0; variant: "quiet"; text: qsTr("Clear history"); implicitHeight: 36; onClicked: Recent.clear() }
            }

            Label {
                visible: Recent.count === 0
                secondary: true
                text: qsTr("Files you open will appear here. They stay on this device.")
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.compact ? 1 : Math.max(2, Math.min(5, Math.floor(root.availableWidth / 280)))
                columnSpacing: 16
                rowSpacing: root.compact ? 4 : 20
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
                        visible: index < (root.compact ? 6 : 8)
                        Layout.fillWidth: true
                        implicitHeight: root.compact ? 70 : thumb.height + 54
                        Accessible.name: (progress > 0 ? qsTr("Resume %1") : qsTr("Play %1")).arg(title)
                        onClicked: root.playRecent(url)
                        background: Item { FocusRing { target: tile; radius_: Theme.radiusCard } }

                        MediaThumb {
                            id: thumb
                            width: root.compact ? 96 : parent.width
                            height: root.compact ? 54 : width * 9 / 16
                            y: root.compact ? 8 : 0
                            source: tile.url
                            audio: tile.isAudio
                            stream: tile.isStream
                            progress: tile.progress
                            corner: tile.length > 0 ? MediaInput.formatTime(tile.length) : ""
                            opacity: tile.hovered ? 0.85 : 1
                        }
                        Column {
                            x: root.compact ? 110 : 0
                            y: root.compact ? 14 : thumb.height + 10
                            width: parent.width - x - 36
                            spacing: 2
                            Label { width: parent.width; text: tile.title; font.weight: Font.DemiBold }
                            Label { width: parent.width; role: "meta"; secondary: true; text: tile.detail }
                        }
                        IconButton {
                            anchors.right: parent.right
                            y: root.compact ? 13 : thumb.height + 6
                            iconName: "close"; iconSize: 14; size: 32; variant: "tint"
                            label: qsTr("Remove %1 from recent files").arg(tile.title)
                            onClicked: Recent.remove(tile.index)
                        }
                    }
                }
            }
        }

        // Keyboard strip (desktop only).
        Rectangle {
            visible: !root.compact
            Layout.fillWidth: true
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            Layout.bottomMargin: 40
            implicitHeight: flow.implicitHeight + 32
            radius: Theme.radiusCard
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
            Flow {
                id: flow
                anchors.fill: parent
                anchors.margins: 16
                anchors.leftMargin: 20
                spacing: 24
                Row {
                    spacing: 10
                    PulseIcon { anchors.verticalCenter: parent.verticalCenter; name: "keyboard"; color: Theme.highlight; size: 22 }
                    Column {
                        Label { text: qsTr("Keyboard first"); font.weight: Font.DemiBold }
                        Label { role: "meta"; secondary: true; text: qsTr("Every control has a shortcut.") }
                    }
                }
                Repeater {
                    model: [["Space", qsTr("Play / pause")], ["← →", qsTr("Seek")], ["F", qsTr("Fullscreen")], ["M", qsTr("Mute")], ["V", qsTr("Subtitles")]]
                    delegate: Row {
                        required property var modelData
                        spacing: 8
                        height: 36
                        Kbd { anchors.verticalCenter: parent.verticalCenter; text: modelData[0] }
                        Label { anchors.verticalCenter: parent.verticalCenter; role: "meta"; secondary: true; text: modelData[1] }
                    }
                }
            }
        }
        Item { Layout.preferredHeight: root.compact ? 16 : 0 }
    }
}
