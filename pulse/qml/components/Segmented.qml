import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Radio group rendered as a segmented control. model: [{ text, value }]
Rectangle {
    id: root
    property var model: []
    property var value
    property bool accentSelection: true
    signal activated(var value)

    implicitHeight: 40
    radius: 10
    color: Qt.rgba(0.04, 0.04, 0.05, 0.6)
    border.width: 1
    border.color: Theme.glassBorder
    Accessible.role: Accessible.RadioButton

    Row {
        anchors.fill: parent
        anchors.margins: 3
        Repeater {
            model: root.model
            delegate: T.AbstractButton {
                id: seg
                required property var modelData
                readonly property bool on: root.value === modelData.value
                width: (root.width - 6) / root.model.length
                height: parent.height
                focusPolicy: Qt.StrongFocus
                checkable: true
                checked: on
                Accessible.role: Accessible.RadioButton
                Accessible.name: modelData.text
                onClicked: root.activated(modelData.value)
                background: Rectangle {
                    radius: 8
                    color: seg.on ? (root.accentSelection ? Theme.accent : Theme.surfaceRaised) : seg.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    FocusRing { target: seg; radius_: 8 }
                }
                contentItem: Text {
                    text: seg.modelData.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: seg.on ? (root.accentSelection ? Theme.textOnAccent : Theme.text) : Theme.textEmphasis
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: seg.on ? Font.Bold : Font.DemiBold
                }
            }
        }
    }
}
