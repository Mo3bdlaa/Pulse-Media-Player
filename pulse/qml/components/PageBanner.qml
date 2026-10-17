import QtQuick
import QtQuick.Layouts
import Pulse

// Page header over the ember scene (09 / 10 / 11): big title, one-line
// subtitle, optional actions on the right.
Item {
    id: root
    property string title
    property string subtitle
    property bool compact: false
    default property alias actions: actionRow.data
    implicitHeight: compact ? 132 : 178

    HeroScene {
        anchors.fill: parent
        planetX: width * 0.66
        planetY: height * 0.42
        planetR: Math.min(62, height * 0.36)
        horizon: height * 0.78
    }
    ColumnLayout {
        anchors.left: parent.left
        anchors.right: root.compact ? parent.right : undefined
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.compact ? 16 : 36
        anchors.bottomMargin: root.compact ? 14 : 26
        spacing: 6
        Label { role: "title"; font.pixelSize: root.compact ? 28 : 36; text: root.title; Accessible.role: Accessible.Heading }
        Label { Layout.fillWidth: root.compact; visible: root.subtitle !== ""; color: Theme.textEmphasis; font.pixelSize: 15; text: root.subtitle
            wrapMode: root.compact ? Text.WordWrap : Text.NoWrap; elide: root.compact ? Text.ElideNone : Text.ElideRight }
    }
    Row {
        id: actionRow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.compact ? 16 : 36
        anchors.bottomMargin: root.compact ? 14 : 28
        spacing: 10
    }
}
