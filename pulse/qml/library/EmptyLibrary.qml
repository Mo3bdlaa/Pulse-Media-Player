import QtQuick
import QtQuick.Layouts
import Pulse
import Pulse.Core

// First run of the library: nothing is indexed until a folder is added.
Item {
    id: root
    signal addFolder()
    readonly property var suggestions: (Library.revision, Library.folders, Library.suggestedFolders())

    Glass {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, (parent.height - height) / 3)
        width: Math.min(parent.width, 640)
        height: col.implicitHeight + 168
        lit: true
        clip: true
        HeroScene {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 170
            planetX: width * 0.5
            planetY: 70
            planetR: 46
            horizon: 150
        }
        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 136
            anchors.margins: 32
            spacing: 12
            Label { Layout.alignment: Qt.AlignHCenter; role: "section"; font.pixelSize: 22; text: qsTr("Build your library") }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                color: Theme.textEmphasis
                text: qsTr("Add the folders where you keep movies, shows and music. Pulse sorts them for you and remembers where you stopped. Your files stay exactly where they are.")
            }
            Flow {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                Layout.preferredWidth: Math.min(col.width, implicitWidth)
                spacing: 10
                PulseButton { variant: "primary"; iconName: "folder-plus"; text: qsTr("Add Folder"); onClicked: root.addFolder() }
                Repeater {
                    model: root.suggestions
                    delegate: PulseButton {
                        required property var modelData
                        iconName: "plus"
                        text: qsTr("Add %1").arg(modelData.name)
                        onClicked: Library.addFolder(modelData.url)
                    }
                }
            }
        }
    }
}
