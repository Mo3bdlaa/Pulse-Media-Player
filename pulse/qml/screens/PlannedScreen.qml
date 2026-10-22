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

    property bool banner: true

    ColumnLayout {
        anchors.fill: parent
        spacing: 20
        PageBanner {
            visible: root.banner && root.title !== ""
            Layout.fillWidth: true
            compact: root.compact
            title: root.title
            subtitle: root.summary
        }
        Card {
            Layout.leftMargin: root.banner ? (root.compact ? 16 : 36) : 0
            Layout.rightMargin: Layout.leftMargin
            lit: true
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
