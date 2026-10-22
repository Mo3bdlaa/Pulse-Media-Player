import QtQuick
import QtQuick.Layouts
import Pulse

// 07 — a titled glass card; rows go inside.
Glass {
    id: root
    property string iconName
    property string title
    property alias action: actionSlot.data
    default property alias rows: body.data
    radius: 14
    implicitHeight: col.implicitHeight + 32

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            PulseIcon { name: root.iconName; size: 20; color: Theme.text }
            Label { Layout.fillWidth: true; text: root.title; font.pixelSize: 16; font.weight: Font.Bold; Accessible.role: Accessible.Heading }
            Row { id: actionSlot }
        }
        Column {
            id: body
            Layout.fillWidth: true
            spacing: 2
        }
    }
}
