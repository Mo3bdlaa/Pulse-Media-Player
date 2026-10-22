import QtQuick
import QtQuick.Controls.Basic as T
import Pulse
import Pulse.Core

// Header of the library grid: Recently Added and Continue Watching (06),
// then the title of the grid below.
Column {
    id: root
    property bool overview: true
    property bool compact: false
    property string title
    signal playUrl(url url, bool isAudio)
    signal menuFor(Item button, url url, bool isAudio)

    readonly property int gap: 16
    readonly property int columns: Math.max(2, Math.floor((width + gap) / (compact ? 140 : 150)))
    readonly property real tileWidth: (width - (columns - 1) * gap) / columns
    readonly property var recent: overview ? (Library.revision, Library.recentlyAdded(columns)) : []
    readonly property var resume: overview ? (Recent.revision, Recent.continueWatching(compact ? 2 : width > 1080 ? 4 : width > 700 ? 3 : 2)) : []
    spacing: 14
    bottomPadding: 6

    component SectionTitle: Item {
        id: st
        property alias text: t.text
        property string count
        property int extraTop: 0
        width: root.width
        height: 30 + extraTop
        Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 10
            Label { id: t; role: "section"; font.pixelSize: 17; Accessible.role: Accessible.Heading }
            Label { anchors.baseline: t.baseline; role: "meta"; secondary: true; text: st.count }
        }
    }

    SectionTitle { visible: root.overview && root.recent.length > 0; text: qsTr("Recently Added") }
    Row {
        visible: root.overview && root.recent.length > 0
        spacing: root.gap
        Repeater {
            model: root.recent
            delegate: PosterTile {
                required property var modelData
                width: root.tileWidth
                height: Math.round(root.tileWidth * 0.9) + 50
                url: modelData.url; title: modelData.title; subtitle: modelData.subtitle
                quality: modelData.quality; isAudio: modelData.isAudio
                onActivated: root.playUrl(modelData.url, modelData.isAudio)
                onMenu: (button) => root.menuFor(button, modelData.url, modelData.isAudio)
            }
        }
    }

    SectionTitle { visible: root.overview && root.resume.length > 0; text: qsTr("Continue Watching"); extraTop: 8 }
    Grid {
        visible: root.overview && root.resume.length > 0
        columns: root.compact ? 1 : root.width > 1080 ? 4 : root.width > 700 ? 3 : 2
        columnSpacing: root.gap
        rowSpacing: 10
        Repeater {
            model: root.resume
            delegate: T.AbstractButton {
                id: card
                required property var modelData
                readonly property var info: (Library.revision, Library.item(modelData.url))
                width: (root.width - (parent.columns - 1) * root.gap) / parent.columns
                height: 84
                focusPolicy: Qt.StrongFocus
                Accessible.name: qsTr("Resume %1").arg(info.title || modelData.title)
                onClicked: root.playUrl(modelData.url, modelData.isAudio)
                background: Glass {
                    radius: 12
                    border.color: card.hovered ? Qt.rgba(1, 0.416, 0.157, 0.5) : Theme.glassBorder
                    FocusRing { target: card; radius_: 12 }
                }
                MediaThumb {
                    id: rt
                    x: 6; y: 6
                    width: 112; height: 72; radius: 9
                    source: card.modelData.url
                    audio: card.modelData.isAudio
                    framePos: card.modelData.progress
                    Rectangle {
                        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 8
                        width: 26; height: 26; radius: 13
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.accentBright }
                            GradientStop { position: 1; color: Theme.accentDeep }
                        }
                        PulseIcon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; name: "play"; size: 12; color: "white" }
                    }
                }
                Column {
                    anchors.left: rt.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9
                    Label { width: parent.width; font.pixelSize: 14; font.weight: Font.DemiBold
                        text: !card.info.title ? card.modelData.title
                            : card.info.category === "tv" ? card.info.title + " · " + card.info.subtitle.split(" · ")[0] : card.info.title }
                    Rectangle {
                        width: parent.width; height: 3; radius: 1.5
                        color: Qt.rgba(1, 1, 1, 0.15)
                        Rectangle { width: parent.width * card.modelData.progress; height: 3; radius: 1.5; color: Theme.accent }
                    }
                    Label { width: parent.width; role: "meta"; secondary: true
                        text: MediaInput.formatTime(card.modelData.position) + " / " + MediaInput.formatTime(card.modelData.length) }
                }
            }
        }
    }

    SectionTitle {
        text: root.title
        count: Library.count > 0 ? Library.count.toLocaleString(Qt.locale(), "f", 0) : ""
        extraTop: root.overview ? 8 : 0
    }
}
