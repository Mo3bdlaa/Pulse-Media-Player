import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// 11 — conversion preset; the selected one is lit with ember.
T.AbstractButton {
    id: tile
    property string iconName
    property string detail
    property bool selected: false
    implicitHeight: 92
    focusPolicy: Qt.StrongFocus
    checkable: true
    checked: selected
    Accessible.role: Accessible.RadioButton
    Accessible.name: text
    Accessible.description: detail
    background: Rectangle {
        radius: 12
        color: tile.selected ? Qt.rgba(1, 0.416, 0.157, 0.16) : tile.hovered ? Qt.rgba(0.16, 0.17, 0.21, 0.9) : Qt.rgba(0.1, 0.11, 0.14, 0.85)
        border.width: tile.selected ? 1.5 : 1
        border.color: tile.selected ? Theme.accent : Theme.glassBorder
        AccentGlow { visible: tile.selected; strength: 0.45; glowRadius: 10 }
        FocusRing { target: tile; radius_: 12 }
    }
    contentItem: Column {
        leftPadding: 4
        spacing: 6
        PulseIcon { name: tile.iconName; size: 24; color: Theme.text }
        Text { width: parent.width - 8; text: tile.text; elide: Text.ElideRight; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold }
        Text { width: parent.width - 8; text: tile.detail; elide: Text.ElideRight; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12 }
    }
    padding: 14
}
