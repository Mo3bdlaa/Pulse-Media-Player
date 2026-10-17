import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Icon-only button; `label` is the accessible name and tooltip.
// variants: plain | overlay | tint | accent (filled) | ring (outlined glow — 02/03 play)
//           | square (bordered rounded square — 02 pip/fullscreen/settings)
T.Button {
    id: control
    property string iconName
    property string label
    property string variant: "plain"
    property int size: Theme.touchTarget
    property int iconSize: 20
    property bool checkedTint: false

    implicitWidth: size
    implicitHeight: size
    padding: 0
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : 0.4
    Accessible.name: label
    T.ToolTip.visible: hovered && label !== "" && !mobilePlatform
    T.ToolTip.text: label
    T.ToolTip.delay: 600
    readonly property bool mobilePlatform: Qt.platform.os === "android" || Qt.platform.os === "ios"

    contentItem: Item {
        PulseIcon {
            anchors.centerIn: parent
            name: control.iconName
            size: control.iconSize
            color: control.variant === "accent" ? Theme.textOnAccent
                 : control.variant === "ring" || control.checkedTint ? Theme.accent
                 : control.variant === "tint" ? Theme.textSecondary : Theme.text
        }
    }

    background: Rectangle {
        radius: control.variant === "square" ? 10 : width / 2
        gradient: control.variant === "accent" ? fill : null
        color: {
            switch (control.variant) {
            case "accent": return Theme.accent
            case "ring": return control.hovered ? Qt.rgba(1, 0.416, 0.157, 0.16) : Qt.rgba(0.05, 0.05, 0.06, 0.45)
            case "overlay": return control.hovered ? Qt.rgba(0.07, 0.07, 0.09, 0.85) : Qt.rgba(0.07, 0.07, 0.09, 0.55)
            case "square": return control.hovered ? Qt.rgba(0.16, 0.17, 0.21, 0.92) : Theme.glass
            default: return control.down ? Qt.rgba(1, 1, 1, 0.12) : control.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
            }
        }
        border.width: control.variant === "ring" ? 2.5 : control.variant === "square" ? 1 : 0
        border.color: control.variant === "ring" ? Theme.accent
                    : control.checkedTint ? Qt.rgba(1, 0.416, 0.157, 0.6) : Theme.glassBorder
        Gradient {
            id: fill
            GradientStop { position: 0.0; color: Theme.accentBright }
            GradientStop { position: 1.0; color: Theme.accentDeep }
        }
        AccentGlow { visible: control.variant === "ring" || control.variant === "accent"; strength: control.hovered ? 1 : 0.7 }
        FocusRing { target: control }
    }
}
