import QtQuick
import QtQuick.Controls.Basic as T
import Pulse
import Pulse.Core

// 06 — poster card: real frame or cover, title, year · length, quality badge.
T.AbstractButton {
    id: tile
    property url url
    property string title
    property string subtitle
    property string quality
    property bool isAudio: false
    property bool available: true
    signal activated()
    signal menu(Item button)

    focusPolicy: Qt.StrongFocus
    opacity: available ? 1 : 0.45
    Accessible.name: qsTr("Play %1").arg(title)
    Accessible.description: subtitle
    onClicked: activated()
    background: Item { FocusRing { target: tile; radius_: 12 } }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: tile.menu(tile) }

    MediaThumb {
        id: thumb
        width: parent.width
        height: Math.round(width * 0.9)
        radius: 12
        source: tile.url
        audio: tile.isAudio
        scale: tile.hovered ? 1.03 : 1
        Behavior on scale { NumberAnimation { duration: Theme.motionFast } }
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "transparent"
            border.width: 1
            border.color: tile.hovered ? Qt.rgba(1, 0.416, 0.157, 0.6) : Qt.rgba(1, 1, 1, 0.06)
        }
        Rectangle {
            visible: tile.hovered && tile.available
            anchors.centerIn: parent
            width: 52; height: 52; radius: 26
            color: Qt.rgba(0.05, 0.05, 0.06, 0.55)
            border.width: 2.5
            border.color: Theme.accent
            PulseIcon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 2; name: "play"; size: 22; color: Theme.accent }
            AccentGlow { strength: 0.8 }
        }
        IconButton {
            visible: tile.hovered || tile.activeFocus
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            size: 32; iconSize: 16; variant: "overlay"; iconName: "more-vertical"
            label: qsTr("Options for %1").arg(tile.title)
            onClicked: tile.menu(this)
        }
    }
    Item {
        anchors.top: thumb.bottom
        anchors.topMargin: 10
        width: parent.width
        height: 40
        Label {
            anchors.left: parent.left
            anchors.right: badge.visible ? badge.left : parent.right
            anchors.rightMargin: 8
            text: tile.title
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Label {
            y: 21
            width: parent.width
            role: "meta"
            secondary: true
            text: tile.available ? tile.subtitle : qsTr("Offline")
        }
        Rectangle {
            id: badge
            visible: tile.quality !== "" && tile.quality !== "SD"
            anchors.right: parent.right
            y: 1
            width: badgeText.implicitWidth + 10
            height: 18
            radius: 4
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.45)
            Text { id: badgeText; anchors.centerIn: parent; text: tile.quality; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.Bold }
        }
    }
}
