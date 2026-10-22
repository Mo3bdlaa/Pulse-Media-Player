import QtQuick
import QtQuick.Layouts
import Pulse

// 10 — a settings group: icon, title, one-line description, rows.
Glass {
    id: root
    property string iconName
    property string title
    property string description
    default property alias rows: body.data
    radius: 16
    implicitHeight: col.implicitHeight + 40

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14
        RowLayout {
            spacing: 14
            PulseIcon { name: root.iconName; size: 30; color: Theme.text }
            ColumnLayout {
                spacing: 2
                Label { text: root.title; font.pixelSize: 17; font.weight: Font.Bold }
                Label { visible: root.description !== ""; role: "meta"; secondary: true; font.pixelSize: 13; text: root.description }
            }
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 14
        }
    }
}
