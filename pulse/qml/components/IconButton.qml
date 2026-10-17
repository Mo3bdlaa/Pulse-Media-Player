import QtQuick
import QtQuick.Controls.Basic as T
import Pulse

// Icon-only button. `label` is the accessible name and tooltip.
T.Button {
    id: control
    property string iconName
    property string label
    property string variant: "plain"   // plain | overlay | accent | tint
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
                 : control.checkedTint ? Theme.accent
                 : control.variant === "tint" ? Theme.textSecondary : Theme.text
        }
    }

    background: Rectangle {
        radius: width / 2
        color: {
            if (control.variant === "accent")
                return control.down ? Qt.darker(Theme.accent, 1.15) : control.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent
            if (control.variant === "overlay")
                return control.hovered ? Qt.rgba(0.07, 0.07, 0.09, 0.8) : Qt.rgba(0.07, 0.07, 0.09, 0.55)
            return control.down ? Qt.rgba(1, 1, 1, 0.12) : control.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        }
        Rectangle {
            visible: control.variant === "accent" && control.size >= 60
            anchors.fill: parent
            anchors.margins: -6
            radius: width / 2
            color: "transparent"
            border.width: 6
            border.color: Qt.rgba(1, 0.416, 0.157, 0.22)
        }
        FocusRing { target: control }
    }
}
