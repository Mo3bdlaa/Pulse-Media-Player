import QtQuick
import Pulse

// Key / value line in a details card; hidden when there is no value.
Item {
    id: root
    property string key
    property string value
    property real keyWidth: 120
    width: parent ? parent.width : 0
    visible: value !== ""
    height: visible ? Math.max(30, valueText.implicitHeight + 10) : 0
    Accessible.name: key + ": " + value
    Label { id: keyText; y: 6; width: root.keyWidth - 10; text: root.key; role: "meta"; secondary: true; font.pixelSize: 13 }
    Label {
        id: valueText
        x: root.keyWidth
        y: 6
        width: root.width - root.keyWidth
        text: root.value
        font.pixelSize: 13
        color: Theme.textEmphasis
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }
}
