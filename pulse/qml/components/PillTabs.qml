import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Filter pills (06 / 08): the selected pill is filled with the ember gradient.
// model: [{ text, value }]
Flow {
    id: root
    property var model: []
    property var value
    signal activated(var value)
    spacing: 8
    Accessible.role: Accessible.PageTabList

    Repeater {
        model: root.model
        delegate: T.AbstractButton {
            id: pill
            required property var modelData
            readonly property bool on: root.value === modelData.value
            height: 36
            width: label.implicitWidth + 32
            focusPolicy: Qt.StrongFocus
            Accessible.role: Accessible.PageTab
            Accessible.name: modelData.text
            Accessible.selected: on
            onClicked: root.activated(modelData.value)
            contentItem: Text {
                id: label
                text: pill.modelData.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: pill.on ? Theme.textOnAccent : Theme.textEmphasis
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: pill.on ? Font.Bold : Font.DemiBold
            }
            background: Rectangle {
                radius: 9
                gradient: pill.on ? fill : null
                color: pill.on ? Theme.accent : pill.hovered ? Qt.rgba(0.16, 0.17, 0.21, 0.92) : Qt.rgba(0.08, 0.09, 0.11, 0.85)
                border.width: pill.on ? 0 : 1
                border.color: Theme.glassBorder
                Gradient {
                    id: fill
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.accentBright }
                    GradientStop { position: 1; color: Theme.accentDeep }
                }
                AccentGlow { visible: pill.on; strength: 0.55; glowRadius: 8 }
                FocusRing { target: pill; radius_: 9 }
            }
        }
    }
}
