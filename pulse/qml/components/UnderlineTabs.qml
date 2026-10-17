import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Tabs with an ember underline (10 / 11). model: [{ text, value }]
Row {
    id: root
    property var model: []
    property var value
    property bool boxed: false
    signal activated(var value)
    spacing: boxed ? 10 : 6
    Accessible.role: Accessible.PageTabList

    Repeater {
        model: root.model
        delegate: T.AbstractButton {
            id: tab
            required property var modelData
            readonly property bool on: root.value === modelData.value
            height: 44
            width: label.implicitWidth + (root.boxed ? 48 : 28)
            focusPolicy: Qt.StrongFocus
            Accessible.role: Accessible.PageTab
            Accessible.name: modelData.text
            Accessible.selected: on
            onClicked: root.activated(modelData.value)
            contentItem: Text {
                id: label
                text: tab.modelData.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: tab.on || tab.hovered ? Theme.text : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: tab.on ? Font.DemiBold : Font.Medium
            }
            background: Rectangle {
                radius: 10
                color: root.boxed ? (tab.on ? Qt.rgba(1, 0.416, 0.157, 0.12) : Qt.rgba(0.08, 0.09, 0.11, 0.8)) : "transparent"
                border.width: root.boxed ? 1 : 0
                border.color: tab.on ? Qt.rgba(1, 0.416, 0.157, 0.4) : Theme.glassBorder
                Rectangle {
                    visible: tab.on
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - (root.boxed ? 0 : 8)
                    height: 3
                    radius: 1.5
                    color: Theme.accent
                    AccentGlow { strength: 0.6; glowRadius: 6 }
                }
                FocusRing { target: tab }
            }
        }
    }
}
