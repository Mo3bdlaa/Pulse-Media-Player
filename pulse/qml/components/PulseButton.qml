import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// primary: ember gradient + bloom, white text (01 Open File)
// secondary: glass card;  quiet: text only;  danger: red outline
// `description` turns it into a two-line action card.
T.Button {
    id: control
    property string variant: "secondary"
    property string iconName
    property string shortcutHint
    property string description
    property bool large: false
    property bool active: false
    property bool chevron: false

    readonly property bool card: description !== ""
    readonly property color fg: variant === "primary" ? Theme.textOnAccent
                              : variant === "danger" ? Theme.errorText
                              : variant === "quiet" ? Theme.textSecondary
                              : active ? Theme.accentText : Theme.text

    implicitHeight: card ? 76 : large ? 56 : Theme.touchTarget
    implicitWidth: card ? 240 : Math.max(implicitHeight, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: variant === "quiet" ? 12 : card ? 20 : 18
    rightPadding: leftPadding
    font.family: Theme.fontFamily
    font.pixelSize: large || card ? 16 : 14
    font.weight: variant === "primary" || card ? Font.Bold : Font.DemiBold
    opacity: enabled ? 1 : 0.4
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    Accessible.description: description

    contentItem: Row {
        spacing: control.card ? 16 : 8
        PulseIcon {
            visible: control.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: control.iconName
            size: control.card ? 30 : control.large ? 22 : 18
            color: control.variant === "primary" ? Theme.textOnAccent
                 : control.card ? Theme.text
                 : control.active ? Theme.accent : control.fg
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: control.card ? control.availableWidth - 46 - (hint.visible ? hint.width + 16 : 0) - (chev.visible ? 22 : 0) : implicitWidth
            spacing: 3
            Text {
                text: control.text
                font: control.font
                color: control.fg
                visible: text !== ""
            }
            Text {
                visible: control.card
                width: parent.width
                text: control.description
                elide: Text.ElideRight
                color: control.variant === "primary" ? Qt.rgba(1, 1, 1, 0.88) : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
        }
        Kbd {
            id: hint
            visible: control.shortcutHint !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: control.shortcutHint
            accentBg: control.variant === "primary"
        }
        PulseIcon {
            id: chev
            visible: control.chevron
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron-right"
            size: 16
            color: Theme.textSecondary
        }
    }

    background: Rectangle {
        id: bg
        radius: control.card ? 12 : 10
        gradient: control.variant === "primary" ? accentFill : null
        color: control.variant === "primary" ? Theme.accent
             : control.variant === "secondary" && control.active ? Theme.accentTint
             : control.variant === "secondary" ? (control.hovered ? Qt.rgba(0.16, 0.17, 0.21, 0.9) : Theme.glass)
             : control.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        border.width: control.variant === "secondary" || control.variant === "danger" ? 1 : 0
        border.color: control.variant === "danger" ? Theme.error
                    : control.active || control.hovered ? Qt.rgba(1, 0.416, 0.157, 0.55) : Theme.glassBorder
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }

        Gradient {
            id: accentFill
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: control.down ? Theme.accentDeep : Theme.accentBright }
            GradientStop { position: 1.0; color: control.down ? "#C8441A" : Theme.accentDeep }
        }
        AccentGlow { visible: control.variant === "primary"; strength: control.hovered ? 1 : 0.75 }
        FocusRing { target: control }
    }
}
