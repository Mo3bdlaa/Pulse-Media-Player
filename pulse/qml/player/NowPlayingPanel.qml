import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 12 — under the video in the expanded Now Playing view: Info, Chapters,
// Audio & Subtitles, and Up Next with Autoplay.
Item {
    id: root
    property bool compact: false
    property var inspector
    signal showDetails(url url)

    property string tab: "info"
    readonly property var d: inspector ? inspector.details : ({})
    readonly property var lib: (Library.revision, Library.item(Player.url))
    readonly property var v: Player.videoTracks.length ? Player.videoTracks[0] : null
    readonly property var a: (Player.audioTracks.find(t => t.selected) || Player.audioTracks[0] || null)
    readonly property string title: lib.title || Player.title
    readonly property int year: lib.year || MediaFormat.year(d.date || Player.date)

    component Badge: Rectangle {
        property alias text: bt.text
        property bool strong: false
        visible: text !== ""
        width: bt.implicitWidth + 14
        height: 24
        radius: 5
        color: "transparent"
        border.width: 1
        border.color: strong ? Theme.text : Qt.rgba(1, 1, 1, 0.35)
        Text { id: bt; anchors.centerIn: parent; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: parent.strong ? Font.Bold : Font.DemiBold }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                Layout.fillWidth: true
                implicitHeight: 50
                Flickable {
                    anchors.fill: parent
                    anchors.leftMargin: root.compact ? 12 : 22
                    contentWidth: npTabs.width
                    interactive: contentWidth > width
                    clip: true
                UnderlineTabs {
                    id: npTabs
                    y: 6
                    value: root.tab
                    model: [
                        { value: "info", text: qsTr("Info") },
                        { value: "chapters", text: Player.chapters.length ? qsTr("Chapters (%1)").arg(Player.chapters.length) : qsTr("Chapters") },
                        { value: "tracks", text: qsTr("Audio & Subtitles") }
                    ].concat(root.compact ? [{ value: "next", text: qsTr("Up Next") }] : [])
                    onActivated: (val) => root.tab = val
                }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.glassBorder; z: -1 }
            }

            // -------------------------------------------------------- Info
            Flickable {
                visible: root.tab === "info"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: info.implicitHeight + 36
                clip: true
                T.ScrollBar.vertical: T.ScrollBar {}
                RowLayout {
                    id: info
                    x: root.compact ? 14 : 22
                    y: 20
                    width: parent.width - 2 * x
                    spacing: 22
                    MediaThumb {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: root.compact ? 96 : 150
                        Layout.preferredHeight: Layout.preferredWidth * 1.4
                        radius: 12
                        source: Player.url
                        framePos: 0.42
                        stream: !Player.url.toString().startsWith("file:")
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 9
                        Label { Layout.fillWidth: true; text: root.title + (root.year > 0 && root.title.indexOf(String(root.year)) < 0 ? " (" + root.year + ")" : ""); font.pixelSize: root.compact ? 19 : 24; font.weight: Font.Bold; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Label { height: 24; verticalAlignment: Text.AlignVCenter; color: Theme.textEmphasis; text: [root.year > 0 ? String(root.year) : "", MediaFormat.runtime(Player.length)].filter(s => s).join("   ") }
                            Repeater {
                                model: (root.d.genre || "").split(/[,;\/]/).map(s => s.trim()).filter(s => s)
                                delegate: Badge { required property var modelData; text: modelData }
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Badge { strong: true; text: root.v ? MediaFormat.shortQuality(root.v.width, root.v.height) : "" }
                            Badge { text: root.v ? MediaFormat.codec({ codec: root.v.codec, codecName: root.v.codecName }) : "" }
                            Badge { text: root.a ? [MediaFormat.codec({ codec: root.a.codec, codecName: root.a.codecName }), MediaFormat.channels(root.a.channels)].filter(s => s).join(" ") : "" }
                            Badge { text: root.v && root.v.frameRate ? Number(root.v.frameRate).toFixed(2).replace(/\.?0+$/, "") + " fps" : "" }
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.d.description || ""
                            color: Theme.textEmphasis
                            font.pixelSize: 14
                            lineHeight: 1.3
                            wrapMode: Text.WordWrap
                            maximumLineCount: root.compact ? 3 : 5
                        }
                        Column {
                            Layout.fillWidth: true
                            FactRow { key: qsTr("Director"); value: root.d.director || ""; keyWidth: 90 }
                            FactRow { key: qsTr("Cast"); value: root.d.actors || ""; keyWidth: 90 }
                            FactRow { key: qsTr("Genre"); value: root.d.genre || ""; keyWidth: 90 }
                            FactRow { key: qsTr("File"); value: MediaInput.describe(Player.url); keyWidth: 90 }
                        }
                        Label {
                            visible: Player.url.toString().startsWith("file:")
                            text: qsTr("More details") + "  ›"
                            color: Theme.accentText
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            TapHandler { onTapped: root.showDetails(Player.url) }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // -------------------------------------------------------- Chapters
            ListView {
                id: chapterList
                visible: root.tab === "chapters"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                topMargin: 12
                leftMargin: root.compact ? 10 : 18
                rightMargin: leftMargin
                spacing: 4
                model: Player.chapters
                T.ScrollBar.vertical: T.ScrollBar {}
                footer: Label {
                    width: chapterList.width - 2 * chapterList.leftMargin
                    height: Player.chapters.length === 0 ? 80 : 12
                    visible: Player.chapters.length === 0
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    secondary: true
                    text: qsTr("This file has no chapters.")
                }
                delegate: T.AbstractButton {
                    id: crow
                    required property var modelData
                    required property int index
                    readonly property bool current: index === Player.currentChapter
                    width: chapterList.width - chapterList.leftMargin - chapterList.rightMargin
                    height: 58
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: qsTr("Go to %1").arg(modelData.name)
                    onClicked: Player.setChapter(index)
                    background: Rectangle {
                        radius: 10
                        color: crow.current ? Qt.rgba(1, 0.416, 0.157, 0.16) : crow.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        border.width: crow.current ? 1 : 0
                        border.color: Qt.rgba(1, 0.416, 0.157, 0.5)
                        FocusRing { target: crow; radius_: 10 }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        spacing: 14
                        Text { anchors.verticalCenter: parent.verticalCenter; width: 20; text: crow.index + 1; color: crow.current ? Theme.accent : Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 76; height: 43; radius: 7; color: "#0B0C10"; clip: true
                            Image {
                                anchors.fill: parent
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(152, 86)
                                source: Player.url.toString().startsWith("file:") ? "image://thumb/" + encodeURIComponent(Player.url.toString()) + "?t=" + (crow.modelData.time + 2000) : ""
                            }
                        }
                        Label { anchors.verticalCenter: parent.verticalCenter; width: crow.width - 220; text: crow.modelData.name; font.pixelSize: 14; font.weight: crow.current ? Font.DemiBold : Font.Medium; color: crow.current ? Theme.accentText : Theme.text }
                    }
                    Label { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; role: "meta"; secondary: !crow.current; color: crow.current ? Theme.accentText : Theme.textSecondary; text: MediaInput.formatTime(crow.modelData.time) }
                }
            }

            // -------------------------------------------------------- Tracks
            Flickable {
                visible: root.tab === "tracks"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: trackGrid.implicitHeight + 32
                clip: true
                T.ScrollBar.vertical: T.ScrollBar {}
                GridLayout {
                    id: trackGrid
                    x: root.compact ? 14 : 22
                    y: 16
                    width: parent.width - 2 * x
                    columns: root.compact ? 1 : 2
                    columnSpacing: 24
                    rowSpacing: 18
                    component TrackPick: T.AbstractButton {
                        id: pick
                        property string name
                        property string detail
                        property bool on: false
                        width: parent ? parent.width : 0
                        height: 46
                        focusPolicy: Qt.StrongFocus
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: name
                        Accessible.checked: on
                        background: Rectangle {
                            radius: 9
                            color: pick.on ? Qt.rgba(1, 0.416, 0.157, 0.16) : pick.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                            border.width: pick.on ? 1 : 0
                            border.color: Qt.rgba(1, 0.416, 0.157, 0.5)
                            FocusRing { target: pick; radius_: 9 }
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 12
                            spacing: 12
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18; height: 18; radius: 9
                                color: "transparent"
                                border.width: 2
                                border.color: pick.on ? Theme.accent : Theme.textSecondary
                                Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Theme.accent; visible: pick.on }
                            }
                            Label { anchors.verticalCenter: parent.verticalCenter; width: pick.width - 170; text: pick.name; font.pixelSize: 14; font.weight: pick.on ? Font.DemiBold : Font.Medium }
                        }
                        Label { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; role: "meta"; secondary: true; text: pick.detail }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 6
                        Label { text: qsTr("Audio"); font.pixelSize: 15; font.weight: Font.Bold }
                        Column {
                            Layout.fillWidth: true
                            Repeater {
                                model: Player.audioTracks
                                delegate: TrackPick {
                                    required property var modelData
                                    name: modelData.name
                                    detail: [MediaFormat.codec({ codec: modelData.codec, codecName: modelData.codecName }), MediaFormat.channels(modelData.channels)].filter(s => s).join(" · ")
                                    on: modelData.selected
                                    onClicked: Player.selectTrack(1, modelData.id)
                                }
                            }
                        }
                        Label { visible: Player.audioTracks.length === 0; secondary: true; text: qsTr("No audio tracks") }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 6
                        Label { text: qsTr("Subtitles"); font.pixelSize: 15; font.weight: Font.Bold }
                        Column {
                            Layout.fillWidth: true
                            TrackPick { name: qsTr("Off"); on: !Player.subtitleTracks.some(t => t.selected); onClicked: Player.disableTrack(2) }
                            Repeater {
                                model: Player.subtitleTracks
                                delegate: TrackPick {
                                    required property var modelData
                                    name: modelData.name
                                    detail: MediaFormat.codec({ codec: modelData.codec, codecName: modelData.codecName })
                                    on: modelData.selected
                                    onClicked: Player.selectTrack(2, modelData.id)
                                }
                            }
                        }
                        Label { Layout.fillWidth: true; secondary: true; wrapMode: Text.WordWrap; font.pixelSize: 13
                            text: qsTr("Drop a subtitle file on the window to add it.") }
                    }
                }
            }

            // -------------------------------------------------------- Up Next (phone)
            UpNext { visible: root.compact && root.tab === "next"; Layout.fillWidth: true; Layout.fillHeight: true }
        }

        Rectangle { visible: !root.compact; Layout.fillHeight: true; width: 1; color: Theme.glassBorder }
        UpNext { visible: !root.compact; Layout.fillWidth: false; Layout.preferredWidth: Math.min(380, root.width * 0.36); Layout.fillHeight: true }
    }

    component UpNext: ColumnLayout {
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 16
            Layout.topMargin: 14
            Label { Layout.fillWidth: true; role: "section"; font.pixelSize: 18; text: qsTr("Up Next") }
            Label { text: qsTr("Autoplay"); role: "meta"; secondary: true }
            PulseSwitch { checked: Prefs.autoplayNext; onToggled: Prefs.autoplayNext = checked; Accessible.name: qsTr("Autoplay next") }
        }
        QueueList { Layout.fillWidth: true; Layout.fillHeight: true; Layout.leftMargin: 12; Layout.rightMargin: 12; dense: true }
    }
}
