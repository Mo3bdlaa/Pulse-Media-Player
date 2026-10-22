import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Glass combo box. model: [{ text, value }]; `value` is the selected value.
T.ComboBox {
    id: control
    property var value
    signal picked(var value)

    textRole: "text"
    valueRole: "value"
    implicitHeight: 38
    implicitWidth: 170
    leftPadding: 12
    rightPadding: 34
    font.family: Theme.fontFamily
    font.pixelSize: 13
    focusPolicy: Qt.StrongFocus
    currentIndex: {
        for (let i = 0; i < (model ? model.length : 0); ++i)
            if (model[i].value === value) return i
        return -1
    }
    onActivated: (i) => control.picked(model[i].value)

    contentItem: Text {
        text: control.displayText
        font: control.font
        color: control.enabled ? Theme.text : Theme.iconMuted
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: PulseIcon {
        x: control.width - width - 12
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron-down"
        size: 16
        color: Theme.textSecondary
    }
    background: Rectangle {
        radius: 8
        color: control.hovered ? Qt.rgba(0.16, 0.17, 0.21, 0.95) : Qt.rgba(0.05, 0.05, 0.07, 0.7)
        border.width: 1
        border.color: control.activeFocus || control.popup.visible ? Qt.rgba(1, 0.416, 0.157, 0.6) : Theme.glassBorder
        FocusRing { target: control; radius_: 8 }
    }
    delegate: T.ItemDelegate {
        id: row
        required property var modelData
        required property int index
        width: ListView.view.width
        implicitHeight: 36
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: row.modelData.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: control.currentIndex === row.index ? Font.Bold : Font.Normal
            color: control.currentIndex === row.index ? Theme.accentText : Theme.text
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle { radius: 6; color: row.highlighted ? Qt.rgba(1, 0.416, 0.157, 0.16) : "transparent" }
    }
    popup: T.Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 320)
        padding: 6
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }
        background: Rectangle { radius: 10; color: "#F2181A21"; border.width: 1; border.color: Theme.glassBorder }
    }
}
