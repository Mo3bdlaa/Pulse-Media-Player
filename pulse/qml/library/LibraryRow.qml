import QtQuick
import QtQuick.Controls.Basic as T
import Pulse
import Pulse.Core

// 06 list view row.
T.AbstractButton {
    id: row
    property url url
    property string title
    property string subtitle
    property string quality
    property bool isAudio: false
    property bool available: true
    property double durationMs: 0
    signal activated()
    signal menu(Item button)

    focusPolicy: Qt.StrongFocus
    opacity: available ? 1 : 0.45
    Accessible.name: qsTr("Play %1").arg(title)
    onClicked: activated()
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: row.menu(row) }
    background: Rectangle {
        radius: 10
        color: row.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
        FocusRing { target: row; radius_: 10 }
    }
    MediaThumb {
        id: thumb
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 92; height: 52; radius: 8
        source: row.url
        audio: row.isAudio
    }
    Column {
        anchors.left: thumb.right
        anchors.leftMargin: 14
        anchors.right: meta.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Label { width: parent.width; text: row.title; font.pixelSize: 14; font.weight: Font.DemiBold }
        Label { width: parent.width; role: "meta"; secondary: true; text: row.available ? row.subtitle : qsTr("Offline") }
    }
    Row {
        id: meta
        anchors.right: more.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16
        Label { anchors.verticalCenter: parent.verticalCenter; visible: row.quality !== ""; role: "meta"; color: Theme.textEmphasis; text: row.quality }
        Label { anchors.verticalCenter: parent.verticalCenter; width: 64; horizontalAlignment: Text.AlignRight; role: "meta"; secondary: true
            text: row.durationMs > 0 ? MediaInput.formatTime(row.durationMs) : "" }
    }
    IconButton {
        id: more
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        size: 36; iconSize: 18; iconName: "more-vertical"; variant: "tint"
        label: qsTr("Options for %1").arg(row.title)
        onClicked: row.menu(this)
    }
}
