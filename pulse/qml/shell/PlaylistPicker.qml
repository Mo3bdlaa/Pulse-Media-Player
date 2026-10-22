import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Templates as Tpl
import QtQuick.Layouts
import Pulse
import Pulse.Core

// "Add to Playlist…": pick an existing playlist or name a new one.
T.Popup {
    id: root
    property var urls: []
    signal added(string name, int count)

    function pick(list) { urls = list; open() }

    modal: true
    focus: true
    width: Math.min(420, parent.width - 32)
    x: (parent.width - width) / 2
    y: Math.max(32, (parent.height - height) / 3)
    padding: 20
    readonly property var lists: visible ? Playlists.all() : []
    onOpened: field.text = ""
    Tpl.Overlay.modal: Rectangle { color: Qt.rgba(0.02, 0.02, 0.03, 0.55) }
    background: Rectangle { radius: Theme.radiusPanel; color: Theme.surface; border.width: 1; border.color: Theme.border }

    function addTo(id, name) {
        Playlists.addUrls(id, root.urls)
        root.close()
        root.added(name, root.urls.length)
    }

    contentItem: ColumnLayout {
        spacing: 12
        Label { role: "section"; text: qsTr("Add to Playlist") }
        ListView {
            id: list
            visible: root.lists.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 260)
            clip: true
            model: root.lists
            delegate: T.ItemDelegate {
                id: d
                required property var modelData
                width: list.width
                height: 46
                onClicked: root.addTo(modelData.id, modelData.name)
                contentItem: RowLayout {
                    spacing: 12
                    PulseIcon { name: "playlists"; size: 18; color: Theme.textEmphasis }
                    Label { Layout.fillWidth: true; text: d.modelData.name }
                    Label { role: "meta"; secondary: true; text: d.modelData.itemCount }
                }
                background: Rectangle { radius: 8; color: d.hovered || d.activeFocus ? Qt.rgba(1, 0.416, 0.157, 0.14) : "transparent" }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            T.TextField {
                id: field
                Layout.fillWidth: true
                implicitHeight: 42
                placeholderText: qsTr("New playlist name")
                placeholderTextColor: Theme.textSecondary
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 14
                leftPadding: 12
                selectByMouse: true
                background: Rectangle { radius: 10; color: Theme.bg; border.width: 1; border.color: field.activeFocus ? Theme.accent : Theme.border }
                onAccepted: create.clicked()
            }
            PulseButton {
                id: create
                variant: "primary"
                iconName: "plus"
                text: qsTr("Create")
                onClicked: {
                    const name = field.text.trim() || qsTr("Untitled Playlist")
                    Playlists.create(name, root.urls)
                    root.close()
                    root.added(name, root.urls.length)
                }
            }
        }
    }
}
