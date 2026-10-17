import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Templates as Tpl
import QtQuick.Layouts
import Pulse

T.Popup {
    id: root
    signal accepted(url address, bool enqueue)

    modal: true
    focus: true
    width: Math.min(560, parent.width - 32)
    x: (parent.width - width) / 2
    y: Math.max(32, (parent.height - height) / 3)
    padding: 20
    onOpened: { field.text = ""; field.forceActiveFocus() }
    Tpl.Overlay.modal: Rectangle { color: Qt.rgba(0.02, 0.02, 0.03, 0.55) }
    background: Rectangle { radius: Theme.radiusPanel; color: Theme.surface; border.width: 1; border.color: Theme.border }

    function submit(enqueue) {
        const u = MediaInput.fromUserInput(field.text)
        if (u.toString() === "") return
        root.close()
        root.accepted(u, enqueue)
    }

    contentItem: ColumnLayout {
        spacing: 14
        Label { role: "section"; text: qsTr("Open network address") }
        T.TextField {
            id: field
            Layout.fillWidth: true
            implicitHeight: 48
            placeholderText: "https://…, rtsp://…, smb://…"
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
        Label { Layout.fillWidth: true; role: "meta"; secondary: true; wrapMode: Text.WordWrap; text: qsTr("Any address the playback engine supports, such as HTTP(S), HLS, DASH, RTSP, RTMP, SMB or FTP.") }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8
            PulseButton { text: qsTr("Cancel"); variant: "quiet"; onClicked: root.close() }
            PulseButton { text: qsTr("Add to queue"); onClicked: root.submit(true) }
            PulseButton { text: qsTr("Play"); variant: "primary"; iconName: "play"; onClicked: root.submit(false) }
        }
    }
}
