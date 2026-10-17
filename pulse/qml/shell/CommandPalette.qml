import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Templates as Tpl
import QtQuick.Layouts
import Pulse

// Ctrl+K: filterable list of real commands.
T.Popup {
    id: root
    property var commands: []   // [{ text, hint, icon, run }]
    readonly property var filtered: commands.filter(c => c.text.toLowerCase().indexOf(field.text.toLowerCase()) >= 0)

    modal: true
    focus: true
    width: Math.min(560, parent.width - 32)
    x: (parent.width - width) / 2
    y: 72
    padding: 8
    onOpened: { field.text = ""; field.forceActiveFocus(); list.currentIndex = 0 }

    Tpl.Overlay.modal: Rectangle { color: Qt.rgba(0.02, 0.02, 0.03, 0.55) }
    background: Rectangle { radius: Theme.radiusPanel; color: Theme.surface; border.width: 1; border.color: Theme.border }

    contentItem: ColumnLayout {
        spacing: 6
        T.TextField {
            id: field
            Layout.fillWidth: true
            implicitHeight: 44
            placeholderText: qsTr("Type a command")
            placeholderTextColor: Theme.textSecondary
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 15
            leftPadding: 14
            Accessible.name: qsTr("Command")
            background: Rectangle { radius: Theme.radiusControl; color: Theme.bg; border.width: 1; border.color: Theme.accent }
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onReturnPressed: list.run(list.currentIndex)
            Keys.onEnterPressed: list.run(list.currentIndex)
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 360)
            clip: true
            model: root.filtered
            function run(i) {
                if (i < 0 || i >= root.filtered.length) return
                const cmd = root.filtered[i]
                root.close()
                cmd.run()
            }
            delegate: T.ItemDelegate {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 44
                highlighted: ListView.isCurrentItem
                onClicked: list.run(index)
                contentItem: RowLayout {
                    spacing: 12
                    PulseIcon { name: modelData.icon || "chevron-right"; color: Theme.textSecondary; size: 18 }
                    Label { Layout.fillWidth: true; text: modelData.text }
                    Kbd { visible: !!modelData.hint; text: modelData.hint || "" }
                }
                background: Rectangle { radius: Theme.radiusControl; color: parent.highlighted || parent.hovered ? Theme.surfaceRaised : "transparent" }
            }
        }
    }
}
