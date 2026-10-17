import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// 09 — Network & Streams. URL playback now; local discovery is P3.
T.ScrollView {
    id: root
    property bool compact: false
    signal play(url address, bool enqueue)
    contentWidth: availableWidth

    function submit(enqueue) {
        const u = MediaInput.fromUserInput(field.text)
        if (u.toString() !== "") root.play(u, enqueue)
    }

    ColumnLayout {
        width: root.availableWidth
        spacing: 24
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: root.compact ? 16 : 40
            Layout.bottomMargin: 0
            Label { role: "title"; text: qsTr("Network & Streams"); Accessible.role: Accessible.Heading }
            Label { secondary: true; text: qsTr("Play from an address, or browse shares on your local network.") }
        }
        Card {
            Layout.fillWidth: true
            Layout.leftMargin: root.compact ? 16 : 40
            Layout.rightMargin: Layout.leftMargin
            implicitHeight: urlCol.implicitHeight + 40
            ColumnLayout {
                id: urlCol
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14
                Label { role: "section"; font.pixelSize: 16; text: qsTr("Open network address") }
                GridLayout {
                    Layout.fillWidth: true
                    columns: root.compact ? 1 : 3
                    columnSpacing: 10
                    rowSpacing: 10
                    T.TextField {
                        id: field
                        Layout.fillWidth: true
                        implicitHeight: 48
                        placeholderText: "https://example.org/live/channel.m3u8"
                        placeholderTextColor: Theme.textSecondary
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        leftPadding: 14
                        inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
                        Accessible.name: qsTr("Network address")
                        background: Rectangle { radius: 10; color: Theme.bg; border.width: 1; border.color: field.activeFocus ? Theme.accent : Theme.border }
                        onAccepted: root.submit(false)
                    }
                    PulseButton { variant: "primary"; iconName: "play"; text: qsTr("Play"); implicitHeight: 48; enabled: field.text.length > 0; onClicked: root.submit(false) }
                    PulseButton { text: qsTr("Add to queue"); implicitHeight: 48; enabled: field.text.length > 0; onClicked: root.submit(true) }
                }
                Label { Layout.fillWidth: true; role: "meta"; secondary: true; wrapMode: Text.WordWrap; elide: Text.ElideNone
                    text: qsTr("Supported protocols depend on the engine build for this platform.") }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.compact ? 16 : 40
            Layout.rightMargin: Layout.leftMargin
            spacing: 10
            Label { role: "section"; font.pixelSize: 16; text: qsTr("Recent addresses") }
            Label {
                id: noStreams
                property int streams: 0
                visible: streams === 0
                secondary: true
                text: qsTr("Addresses you play appear here. Clear them from Home › Clear history.")
            }
            Repeater {
                model: Recent
                delegate: T.ItemDelegate {
                    id: item
                    required property url url
                    required property bool isStream
                    visible: isStream
                    Component.onCompleted: if (isStream) noStreams.streams++
                    Component.onDestruction: if (isStream) noStreams.streams--
                    Layout.fillWidth: true
                    implicitHeight: isStream ? 52 : 0
                    onClicked: root.play(url, false)
                    contentItem: RowLayout {
                        PulseIcon { name: "link"; color: Theme.textSecondary }
                        Label { Layout.fillWidth: true; text: item.url.toString() }
                    }
                    background: Rectangle { radius: 10; color: item.hovered ? Theme.surface : "transparent"; FocusRing { target: item; radius_: 10 } }
                }
            }
        }
        PlannedScreen {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            compact: root.compact
            title: ""
            phase: "P3"
            summary: ""
            points: [qsTr("Browse SMB and UPnP / DLNA servers found on your network"), qsTr("Saved sources with logins kept in the system keychain")]
        }
    }
}
