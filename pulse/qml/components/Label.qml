import QtQuick
import Pulse

// Body text with Pulse defaults. role: display | title | section | body | meta
Text {
    property string role: "body"
    property bool secondary: false
    readonly property int roleSize: role === "display" ? Theme.displaySize : role === "title" ? Theme.titleSize
                                  : role === "section" ? Theme.sectionSize : role === "meta" ? Theme.metaSize : Theme.bodySize
    color: secondary ? Theme.textSecondary : Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: roleSize
    font.weight: role === "display" || role === "title" ? Font.ExtraBold
               : role === "section" ? Font.Bold : Font.Medium
    font.letterSpacing: role === "display" ? -0.02 * roleSize : role === "title" ? -0.01 * roleSize : 0
    elide: Text.ElideRight
    textFormat: Text.PlainText
}
