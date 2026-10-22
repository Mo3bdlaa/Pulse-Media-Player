import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 08 — right column: cover, details, playback options, quick actions.
Flickable {
    id: root
    required property Item page
    readonly property var p: page.current
    contentHeight: col.implicitHeight
    clip: true

    component ActionTile: T.AbstractButton {
        id: at
        property string iconName
        property bool danger: false
        width: 56
        height: 60
        focusPolicy: Qt.StrongFocus
        Accessible.name: text
        contentItem: Column {
            spacing: 6
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 38; height: 38; radius: 10
                color: at.hovered ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Theme.glassBorder
                PulseIcon { anchors.centerIn: parent; name: at.iconName; size: 18; color: at.danger ? Theme.errorText : Theme.text }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: at.text; color: Theme.textEmphasis; font.family: Theme.fontFamily; font.pixelSize: 12 }
        }
        background: Item { FocusRing { target: at } }
    }
    component Fact: RowLayout {
        property string key
        property string value
        Layout.fillWidth: true
        spacing: 12
        Label { Layout.preferredWidth: 86; Layout.alignment: Qt.AlignTop; role: "meta"; secondary: true; text: parent.key }
        Label { Layout.fillWidth: true; role: "meta"; color: Theme.textEmphasis; wrapMode: Text.WordWrap; elide: Text.ElideNone; maximumLineCount: 4; text: parent.value }
    }
    component QuickAction: T.AbstractButton {
        id: qa
        property string iconName
        Layout.fillWidth: true
        height: 44
        focusPolicy: Qt.StrongFocus
        contentItem: Row {
            spacing: 12
            leftPadding: 4
            PulseIcon { anchors.verticalCenter: parent.verticalCenter; name: qa.iconName; size: 18; color: Theme.textEmphasis }
            Text { anchors.verticalCenter: parent.verticalCenter; text: qa.text; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 14 }
        }
        background: Rectangle {
            radius: 8
            color: qa.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
            border.width: 1
            border.color: Theme.glassBorder
            FocusRing { target: qa; radius_: 8 }
        }
    }

    ColumnLayout {
        id: col
        width: root.width
        spacing: 14

        Glass {
            Layout.fillWidth: true
            implicitHeight: coverCol.implicitHeight + 32
            radius: 16
            ColumnLayout {
                id: coverCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                PlaylistCover { Layout.fillWidth: true; Layout.preferredHeight: width * 0.66; cover: root.p.cover || ""; kind: root.p.kind || ""; radius: 12 }
                Label { Layout.fillWidth: true; text: root.p.name || ""; font.pixelSize: 17; font.weight: Font.Bold }
                Label { role: "meta"; color: Theme.textEmphasis; text: root.page.totalText(root.p) }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    ActionTile { text: qsTr("Edit"); iconName: "pencil"; onClicked: root.page.describe() }
                    Item { Layout.fillWidth: true }
                    ActionTile { text: qsTr("Export"); iconName: "upload"; onClicked: root.page.exportFile() }
                    Item { Layout.fillWidth: true }
                    ActionTile { text: qsTr("Delete"); iconName: "trash"; danger: true; onClicked: root.page.askDelete() }
                }
            }
        }

        Glass {
            Layout.fillWidth: true
            implicitHeight: facts.implicitHeight + 32
            radius: 16
            ColumnLayout {
                id: facts
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                Label { font.pixelSize: 14; font.weight: Font.Bold; text: qsTr("Playlist Details") }
                Fact { key: qsTr("Name"); value: root.p.name || "" }
                Fact { key: qsTr("Description"); value: root.p.description || "—" }
                Fact { key: qsTr("Type"); value: root.page.kindLabel(root.p.kind) }
                Fact { key: qsTr("Created"); value: root.p.created ? Qt.formatDateTime(root.p.created, Qt.locale().dateTimeFormat(Locale.ShortFormat)) : "" }
                Fact { key: qsTr("Last Modified"); value: root.p.modified ? Qt.formatDateTime(root.p.modified, Qt.locale().dateTimeFormat(Locale.ShortFormat)) : "" }
            }
        }

        Glass {
            Layout.fillWidth: true
            implicitHeight: opts.implicitHeight + 32
            radius: 16
            ColumnLayout {
                id: opts
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                Label { font.pixelSize: 14; font.weight: Font.Bold; text: qsTr("Playback Options") }
                RowLayout {
                    Layout.fillWidth: true
                    PulseIcon { name: "shuffle"; size: 17; color: Theme.textEmphasis }
                    Label { Layout.fillWidth: true; Layout.leftMargin: 6; text: qsTr("Shuffle") }
                    PulseSwitch { checked: Queue.shuffle; onToggled: Queue.shuffle = checked; Accessible.name: qsTr("Shuffle") }
                }
                RowLayout {
                    Layout.fillWidth: true
                    PulseIcon { name: "repeat"; size: 17; color: Theme.textEmphasis }
                    Label { Layout.fillWidth: true; Layout.leftMargin: 6; text: qsTr("Repeat") }
                    Dropdown {
                        implicitWidth: 96
                        model: [{ text: qsTr("Off"), value: 0 }, { text: qsTr("All"), value: 1 }, { text: qsTr("One"), value: 2 }]
                        value: Queue.repeat
                        onPicked: (v) => Queue.repeat = v
                        Accessible.name: qsTr("Repeat")
                    }
                }
            }
        }

        Glass {
            Layout.fillWidth: true
            implicitHeight: quick.implicitHeight + 32
            radius: 16
            ColumnLayout {
                id: quick
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                Label { font.pixelSize: 14; font.weight: Font.Bold; text: qsTr("Quick Actions") }
                QuickAction { text: qsTr("Save as File"); iconName: "file-text"; onClicked: root.page.exportFile() }
                QuickAction { text: qsTr("Import Playlist"); iconName: "download"; onClicked: root.page.importFile() }
                QuickAction { text: qsTr("Clear Playlist"); iconName: "reset"; enabled: (root.p.itemCount || 0) > 0; opacity: enabled ? 1 : 0.4; onClicked: Playlists.clear(root.page.selectedId) }
            }
        }
    }
}
