import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 08 — the open playlist: header, actions and its tracks.
Glass {
    id: root
    required property Item page
    readonly property var p: page.current
    readonly property bool narrow: width < 620
    component Head: Text { color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }
    radius: 16
    color: page.compact ? "transparent" : Theme.glass
    border.width: page.compact ? 0 : 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.page.compact ? 0 : 20
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            PlaylistCover {
                Layout.preferredWidth: root.narrow ? 96 : 132
                Layout.preferredHeight: root.narrow ? 96 : 132
                cover: root.p.cover || ""
                kind: root.p.kind || ""
                radius: 12
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Row {
                    id: nameRow
                    Layout.fillWidth: true
                    spacing: 6
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, nameRow.width - 40)
                        text: root.p.name || ""
                        font.pixelSize: root.narrow ? 22 : 28
                        font.weight: Font.ExtraBold
                        Accessible.role: Accessible.Heading
                    }
                    IconButton { anchors.verticalCenter: parent.verticalCenter; size: 34; iconSize: 16; iconName: "pencil"; variant: "tint"; label: qsTr("Rename"); onClicked: root.page.rename() }
                }
                Label { color: Theme.textEmphasis; text: root.page.totalText(root.p) }
                Label {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 520
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    color: root.p.description ? Theme.textEmphasis : Theme.accentText
                    font.pixelSize: 13
                    lineHeight: 1.25
                    text: root.p.description || qsTr("Add a description")
                    TapHandler { enabled: !root.p.description; onTapped: root.page.describe() }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 10
            PulseButton { variant: "primary"; iconName: "play"; text: qsTr("Play All"); enabled: (root.p.itemCount || 0) > 0; onClicked: root.page.playAll(false) }
            PulseButton { iconName: "shuffle"; text: qsTr("Shuffle"); enabled: (root.p.itemCount || 0) > 1; onClicked: root.page.playAll(true) }
            PulseButton { iconName: "plus"; text: qsTr("Add Media"); onClicked: root.page.addMedia() }
            IconButton { variant: "square"; iconName: "more"; label: qsTr("More playlist actions"); onClicked: root.page.openPlaylistMenu(this) }
        }

        // Column titles.
        RowLayout {
            visible: root.page.tracks.length > 0 && !root.narrow
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 0
            Head { Layout.preferredWidth: 40; text: "#"; horizontalAlignment: Text.AlignHCenter }
            Head { Layout.fillWidth: true; Layout.leftMargin: 64; text: qsTr("TITLE") }
            Head { Layout.preferredWidth: 90; text: qsTr("DURATION") }
            Head { Layout.preferredWidth: 90; text: qsTr("TYPE") }
            Item { Layout.preferredWidth: 40 }
        }
        Rectangle { visible: root.page.tracks.length > 0 && !root.narrow; Layout.fillWidth: true; height: 1; color: Theme.glassBorder }

        ListView {
            id: tracks
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.page.tracks
            T.ScrollBar.vertical: T.ScrollBar {}
            footer: Item {
                width: tracks.width
                height: root.page.tracks.length === 0 ? 160 : 12
                Column {
                    visible: root.page.tracks.length === 0
                    anchors.centerIn: parent
                    spacing: 12
                    Label { anchors.horizontalCenter: parent.horizontalCenter; secondary: true; text: qsTr("This playlist is empty.") }
                    PulseButton { anchors.horizontalCenter: parent.horizontalCenter; iconName: "plus"; text: qsTr("Add Media"); onClicked: root.page.addMedia() }
                }
            }
            delegate: T.AbstractButton {
                id: tr
                required property var modelData
                required property int index
                readonly property bool playing: Player.hasMedia && Queue.currentUrl.toString() === modelData.url.toString()
                width: tracks.width
                height: 50
                focusPolicy: Qt.StrongFocus
                opacity: modelData.available ? 1 : 0.45
                Accessible.name: qsTr("Play %1").arg(modelData.title)
                onClicked: root.page.play(Playlists.urls(root.page.selectedId), Math.max(0, Playlists.urls(root.page.selectedId).findIndex(u => u.toString() === modelData.url.toString())))
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.page.openTrackMenu(tr, tr.index, tr.modelData.url) }
                background: Rectangle {
                    radius: 8
                    gradient: tr.playing ? hl : null
                    color: tr.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    Gradient {
                        id: hl
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.rgba(1, 0.416, 0.157, 0.28) }
                        GradientStop { position: 1; color: Qt.rgba(1, 0.416, 0.157, 0.06) }
                    }
                    FocusRing { target: tr; radius_: 8 }
                }
                RowLayout {
                    anchors.fill: parent
                    spacing: 0
                    Item {
                        Layout.preferredWidth: 40
                        Layout.fillHeight: true
                        Text { visible: !tr.playing; anchors.centerIn: parent; text: tr.index + 1; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13 }
                        PulseBars { visible: tr.playing; anchors.centerIn: parent; width: 16; height: 14; count: 3; progress: 1; playing: Player.playing; animated: !Prefs.reduceMotion }
                    }
                    MediaThumb { Layout.preferredWidth: 52; Layout.preferredHeight: 32; radius: 6; source: tr.modelData.url; audio: tr.modelData.isAudio; stream: !tr.modelData.url.toString().startsWith("file:") }
                    Label { Layout.fillWidth: true; Layout.leftMargin: 12; text: tr.modelData.title; font.pixelSize: 14; color: tr.playing ? Theme.accentText : Theme.text; font.weight: tr.playing ? Font.DemiBold : Font.Medium }
                    Label { Layout.preferredWidth: 90; role: "meta"; color: Theme.textEmphasis
                        text: !tr.modelData.available ? qsTr("Missing") : tr.modelData.durationMs > 0 ? MediaInput.formatTime(tr.modelData.durationMs) : "" }
                    Row {
                        visible: !root.narrow
                        Layout.preferredWidth: 90
                        spacing: 8
                        PulseIcon { anchors.verticalCenter: parent.verticalCenter; size: 15; color: Theme.textSecondary
                            name: tr.modelData.isAudio ? "music" : tr.modelData.url.toString().startsWith("file:") ? "film" : "network" }
                        Label { anchors.verticalCenter: parent.verticalCenter; role: "meta"; color: Theme.textEmphasis
                            text: tr.modelData.isAudio ? qsTr("Audio") : tr.modelData.url.toString().startsWith("file:") ? qsTr("Video") : qsTr("Stream") }
                    }
                    IconButton {
                        Layout.preferredWidth: 40
                        size: 34; iconSize: 17; iconName: "more"; variant: "tint"
                        label: qsTr("Options for %1").arg(tr.modelData.title)
                        onClicked: root.page.openTrackMenu(this, tr.index, tr.modelData.url)
                    }
                }
            }
        }
    }
}
