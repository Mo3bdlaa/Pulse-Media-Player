import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Variants follow the Foundations board: primary, secondary, quiet, danger.
T.Button {
    id: control
    property string variant: "secondary"
    property string iconName
    property string shortcutHint
    property bool large: false
    property string description      // second line on large action cards
    property bool active: false   // toggled-on state for secondary buttons (e.g. Repeat all)

    readonly property color fg: variant === "primary" ? Theme.textOnAccent
                              : variant === "danger" ? Theme.errorText
                              : variant === "quiet" ? Theme.textSecondary
                              : active ? Theme.accentText : Theme.text

    implicitHeight: description !== "" ? 72 : large ? 56 : Theme.touchTarget
    implicitWidth: description !== "" ? 240 : Math.max(implicitHeight, contentItem.implicitWidth + leftPadding + rightPadding)
    leftPadding: variant === "quiet" ? 12 : 18
    rightPadding: leftPadding
    font.family: Theme.fontFamily
    font.pixelSize: large || description !== "" ? 16 : 14
    font.weight: variant === "primary" ? Font.Bold : Font.DemiBold
    opacity: enabled ? 1 : 0.4
    focusPolicy: Qt.StrongFocus
    Accessible.name: text

    contentItem: Row {
        spacing: control.description !== "" ? 14 : 8
        PulseIcon {
            visible: control.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: control.iconName
            color: control.description !== "" && control.variant !== "primary" ? Theme.accent
                 : control.variant === "secondary" && !control.large && !control.active ? Theme.text : control.fg
            size: control.description !== "" ? 28 : control.large ? 22 : 18
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: control.description !== "" ? control.availableWidth - 28 - 14 - (hint.visible ? hint.width + 14 : 0) : implicitWidth
            spacing: 2
            Text {
                text: control.text
                font: control.font
                color: control.fg
                visible: text !== ""
            }
            Text {
                visible: control.description !== ""
                width: parent.width
                text: control.description
                elide: Text.ElideRight
                color: control.variant === "primary" ? Theme.textOnAccent : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: control.variant === "primary" ? Font.Medium : Font.Normal
            }
        }
        Kbd {
            id: hint
            visible: control.shortcutHint !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: control.shortcutHint
            accentBg: control.variant === "primary"
        }
    }

    background: Rectangle {
        radius: control.large ? Theme.radiusCard : 10
        color: {
            if (control.variant === "primary")
                return control.down ? Qt.darker(Theme.accent, 1.15) : control.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
            if (control.variant === "secondary" && control.active)
                return Qt.rgba(1, 0.416, 0.157, control.hovered ? 0.18 : 0.12)
            if (control.variant === "secondary")
                return control.down ? Theme.surfaceRaised : control.hovered ? Qt.lighter(Theme.surface, 1.2) : Theme.surface
            return control.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        }
        border.width: control.variant === "secondary" || control.variant === "danger" ? 1 : 0
        border.color: control.variant === "danger" ? Theme.error : control.active ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        FocusRing { target: control }
    }
}
