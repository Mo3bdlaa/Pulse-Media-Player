import QtQuick
import QtQuick.Layouts
import Pulse

// Honest placeholder for destinations scheduled in a later phase.
// The design reference lives in design/screens; nothing here pretends to work.
Item {
    id: root
    property string title
    property string summary
    property string phase
    property var points: []
    property bool compact: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 16 : 40
        spacing: 20
        Label { visible: root.title !== ""; role: "title"; text: root.title; Accessible.role: Accessible.Heading }
        Label { visible: root.summary !== ""; Layout.fillWidth: true; secondary: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; text: root.summary }
        Card {
            dashed: true
            Layout.fillWidth: true
            Layout.maximumWidth: 720
            implicitHeight: col.implicitHeight + 40
            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10
                RowLayout {
                    spacing: 10
                    Rectangle { radius: 6; color: Qt.rgba(1, 0.82, 0.4, 0.14); implicitWidth: phaseText.implicitWidth + 14; implicitHeight: 24
                        Text { id: phaseText; anchors.centerIn: parent; text: root.phase; color: Theme.highlight; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold } }
                    Label { text: qsTr("Planned — not available in this build yet"); font.weight: Font.DemiBold }
                }
                Repeater {
                    model: root.points
                    delegate: RowLayout {
                        required property string modelData
                        Layout.fillWidth: true
                        spacing: 10
                        PulseIcon { name: "check"; size: 16; color: Theme.textSecondary }
                        Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; secondary: true; text: modelData }
                    }
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
