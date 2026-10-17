import QtQuick
import QtQuick.Controls.Basic as T
import Pulse
import Pulse.Core

// Seek bar: played, chapter marks, A–B range, hover time + chapter.
T.Slider {
    id: control
    property bool onVideo: true
    readonly property real lengthMs: Player.length

    from: 0
    to: 1
    value: pressed ? value : Player.position
    enabled: Player.seekable && lengthMs > 0
    live: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: 28
    stepSize: lengthMs > 0 ? Prefs.seekStepMs / lengthMs : 0.01
    Accessible.name: qsTr("Seek")
    Accessible.description: MediaInput.formatTime(Player.time) + " / " + MediaInput.formatTime(lengthMs)
    onMoved: if (!pressed) Player.setPosition(value)
    onPressedChanged: if (!pressed) Player.setPosition(value)

    function chapterAt(pos) {
        const t = pos * lengthMs
        let name = ""
        for (const c of Player.chapters) if (c.time <= t) name = c.name
        return name
    }

    HoverHandler { id: hover }

    background: Item {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: control.pressed || hover.hovered ? 8 : 6
        Behavior on height { NumberAnimation { duration: Theme.motionFast } }

        Rectangle { anchors.fill: parent; radius: height / 2; color: control.onVideo ? Qt.rgba(0.97, 0.96, 0.94, 0.22) : Theme.surfaceRaised }
        Rectangle {
            visible: Player.loopA >= 0 && control.lengthMs > 0
            x: parent.width * Player.loopA / control.lengthMs
            width: Player.loopB >= 0 ? parent.width * (Player.loopB - Player.loopA) / control.lengthMs : 3
            height: parent.height
            color: Qt.rgba(1, 0.82, 0.4, Player.loopB >= 0 ? 0.35 : 1)
        }
        Rectangle { width: parent.width * control.visualPosition; height: parent.height; radius: height / 2; color: Theme.accent }
        Repeater {
            model: control.lengthMs > 0 ? Player.chapters : []
            delegate: Rectangle {
                required property var modelData
                visible: modelData.time > 0
                x: control.availableWidth * modelData.time / control.lengthMs - 1
                y: -2
                width: 2
                height: parent.height + 4
                color: Theme.bg
            }
        }
    }

    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 18
        height: 18
        radius: 9
        color: Theme.text
        visible: control.enabled
        border.width: 4
        border.color: Qt.rgba(1, 0.416, 0.157, 0.45)
        FocusRing { target: control; radius_: 9 }
    }

    // Hover / scrub preview: time and chapter name. Frame previews come later.
    Rectangle {
        readonly property real pos: control.pressed ? control.visualPosition
                                    : Math.max(0, Math.min(1, (hover.point.position.x - control.leftPadding) / control.availableWidth))
        visible: control.enabled && (hover.hovered || control.pressed)
        x: Math.max(0, Math.min(control.width - width, control.leftPadding + pos * control.availableWidth - width / 2))
        y: -height - 8
        width: tip.implicitWidth + 16
        height: 26
        radius: 6
        color: Qt.rgba(0.07, 0.07, 0.09, 0.92)
        Text {
            id: tip
            anchors.centerIn: parent
            readonly property string chapter: control.chapterAt(parent.pos)
            text: (chapter ? chapter + " · " : "") + MediaInput.formatTime(parent.pos * control.lengthMs)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
           
        }
    }
}
