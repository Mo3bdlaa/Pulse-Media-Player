import QtQuick
import QtQuick.Layouts
import Pulse

// Label + optional hint on the left, control on the right.
RowLayout {
    id: root
    property string label
    property string hint
    default property alias control: slot.data
    Layout.fillWidth: true
    spacing: 16
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Label { Layout.fillWidth: true; text: root.label; font.pixelSize: 14; font.weight: Font.Medium }
        Label { Layout.fillWidth: true; visible: root.hint !== ""; role: "meta"; secondary: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; text: root.hint }
    }
    Row { id: slot; Layout.alignment: Qt.AlignVCenter; spacing: 8 }
}
