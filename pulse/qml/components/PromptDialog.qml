import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Templates as Tpl
import QtQuick.Layouts
import Pulse

// One-field dialog: new playlist, rename.
T.Popup {
    id: root
    property string title
    property string placeholder
    property string acceptText: qsTr("Save")
    property string text
    property bool multiline: false
    signal accepted(string text)

    function ask(initial) { root.text = initial || ""; open() }

    modal: true
    focus: true
    width: Math.min(460, parent.width - 32)
    x: (parent.width - width) / 2
    y: Math.max(32, (parent.height - height) / 3)
    padding: 20
    onOpened: { field.text = root.text; area.text = root.text; (root.multiline ? area : field).forceActiveFocus(); field.selectAll() }
    Tpl.Overlay.modal: Rectangle { color: Qt.rgba(0.02, 0.02, 0.03, 0.55) }
    background: Rectangle { radius: Theme.radiusPanel; color: Theme.surface; border.width: 1; border.color: Theme.border }

    function submit() {
        const t = (root.multiline ? area.text : field.text).trim()
        if (!root.multiline && t === "") return
        root.close()
        root.accepted(t)
    }

    contentItem: ColumnLayout {
        spacing: 14
        Label { role: "section"; text: root.title }
        T.TextField {
            id: field
            visible: !root.multiline
            Layout.fillWidth: true
            implicitHeight: 46
            placeholderText: root.placeholder
            placeholderTextColor: Theme.textSecondary
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 15
            leftPadding: 14
            selectByMouse: true
            Accessible.name: root.title
            background: Rectangle { radius: 10; color: Theme.bg; border.width: 1; border.color: field.activeFocus ? Theme.accent : Theme.border }
            onAccepted: root.submit()
        }
        T.TextArea {
            id: area
            visible: root.multiline
            Layout.fillWidth: true
            implicitHeight: 110
            placeholderText: root.placeholder
            placeholderTextColor: Theme.textSecondary
            color: Theme.text
            wrapMode: TextEdit.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: 14
            padding: 12
            selectByMouse: true
            Accessible.name: root.title
            background: Rectangle { radius: 10; color: Theme.bg; border.width: 1; border.color: area.activeFocus ? Theme.accent : Theme.border }
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 8
            PulseButton { text: qsTr("Cancel"); variant: "quiet"; onClicked: root.close() }
            PulseButton { text: root.acceptText; variant: "primary"; onClicked: root.submit() }
        }
    }
}
