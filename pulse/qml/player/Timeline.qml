import QtQuick
import QtQuick.Controls.Basic as T
import Pulse
import Pulse.Core

// Seek bar (02): chapter labels above, chapter dots on the track, A–B range,
// and a frame preview while hovering or scrubbing.
Item {
    id: root
    property bool onVideo: true
    property bool chapterLabels: onVideo
    readonly property real lengthMs: Player.length
    readonly property bool pressed: slider.pressed
    readonly property var chapters: lengthMs > 0 ? Player.chapters : []
    readonly property bool roomForLabels: chapters.length > 1 && slider.availableWidth / chapters.length > 92

    implicitHeight: slider.implicitHeight + (chapterLabels && roomForLabels ? 40 : 0)

    function chapterAt(ms) {
        let idx = -1
        for (let i = 0; i < chapters.length; ++i) if (chapters[i].time <= ms) idx = i
        return idx
    }

    // Chapter labels: "Chapter 3" / "38:24", current one in ember.
    Item {
        id: labels
        visible: root.chapterLabels && root.roomForLabels
        width: parent.width
        height: 40
        Repeater {
            model: labels.visible ? root.chapters : []
            delegate: Column {
                required property var modelData
                required property int index
                readonly property bool current: index === Player.currentChapter
                x: slider.leftPadding + slider.availableWidth * modelData.time / root.lengthMs + (index === 0 ? 0 : -width / 2)
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.name
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: MediaInput.formatTime(modelData.time)
                    color: parent.current ? Theme.accent : Theme.textEmphasis
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: parent.current ? Font.Bold : Font.Normal
                }
            }
        }
    }

    T.Slider {
        id: slider
        anchors.bottom: parent.bottom
        width: parent.width
        from: 0
        to: 1
        value: pressed ? value : Player.position
        enabled: Player.seekable && root.lengthMs > 0
        live: true
        focusPolicy: Qt.StrongFocus
        implicitHeight: 28
        stepSize: root.lengthMs > 0 ? Prefs.seekStepMs / root.lengthMs : 0.01
        Accessible.name: qsTr("Seek")
        Accessible.description: MediaInput.formatTime(Player.time) + " / " + MediaInput.formatTime(root.lengthMs)
        onMoved: if (!pressed) Player.setPosition(value)
        onPressedChanged: if (!pressed) Player.setPosition(value)

        HoverHandler { id: hover }

        background: Item {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: slider.hovered || slider.pressed ? 6 : 4
            Behavior on height { NumberAnimation { duration: Theme.motionFast } }

            Rectangle { anchors.fill: parent; radius: height / 2; color: root.onVideo ? Qt.rgba(0.97, 0.96, 0.94, 0.25) : Qt.rgba(1, 1, 1, 0.12) }
            Rectangle {
                visible: Player.loopA >= 0 && root.lengthMs > 0
                x: parent.width * Player.loopA / root.lengthMs
                width: Player.loopB >= 0 ? parent.width * (Player.loopB - Player.loopA) / root.lengthMs : 3
                height: parent.height
                color: Qt.rgba(1, 0.82, 0.4, Player.loopB >= 0 ? 0.4 : 1)
            }
            Rectangle {
                width: parent.width * slider.visualPosition
                height: parent.height
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.accentDeep }
                    GradientStop { position: 1.0; color: Theme.accentBright }
                }
            }
            Repeater {
                model: root.chapters
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool passed: modelData.time <= Player.time
                    x: slider.availableWidth * modelData.time / root.lengthMs - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: index === Player.currentChapter ? 10 : 7
                    height: width
                    radius: width / 2
                    color: index === Player.currentChapter ? Theme.accent : passed ? "#FFD9C2" : Theme.text
                    border.width: index === Player.currentChapter ? 2 : 0
                    border.color: "#FFE0C8"
                }
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 18
            height: 18
            radius: 9
            color: Theme.text
            visible: slider.enabled
            border.width: 3
            border.color: Theme.accent
            AccentGlow { strength: 0.9; glowRadius: 10 }
            FocusRing { target: slider; radius_: 9 }
        }
    }

    // Frame preview (video) or time + chapter (audio, streams).
    Item {
        id: preview
        readonly property real pos: slider.pressed ? slider.visualPosition
                                    : Math.max(0, Math.min(1, (hover.point.position.x - slider.leftPadding) / slider.availableWidth))
        readonly property real ms: pos * root.lengthMs
        readonly property int chapter: root.chapterAt(ms)
        // Thumbnails are requested on a 5 s grid so scrubbing reuses the cache.
        readonly property real bucket: Math.round(ms / 5000) * 5000
        visible: slider.enabled && ((hover.hovered && slider.hovered) || slider.pressed)
        width: Player.hasVideo ? 180 : tip.implicitWidth + 18
        height: Player.hasVideo ? 112 : 28
        x: Math.max(0, Math.min(root.width - width, slider.leftPadding + pos * slider.availableWidth - width / 2))
        y: slider.y - height - 14
        z: 10

        Rectangle {
            anchors.fill: parent
            visible: Player.hasVideo
            radius: 10
            color: "#000"
            border.width: 2
            border.color: Theme.text
            clip: true
            Image {
                anchors.fill: parent
                anchors.margins: 2
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(320, 180)
                source: preview.visible && Player.url.toString().startsWith("file:")
                        ? "image://thumb/" + encodeURIComponent(Player.url.toString()) + "?t=" + preview.bucket : ""
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 2
                height: 26
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.85) }
                }
            }
        }
        Text {
            id: tip
            anchors.horizontalCenter: Player.hasVideo ? undefined : parent.horizontalCenter
            anchors.verticalCenter: Player.hasVideo ? undefined : parent.verticalCenter
            anchors.left: Player.hasVideo ? parent.left : undefined
            anchors.right: Player.hasVideo ? parent.right : undefined
            anchors.bottom: Player.hasVideo ? parent.bottom : undefined
            anchors.margins: 9
            text: (preview.chapter >= 0 ? root.chapters[preview.chapter].name + (Player.hasVideo ? "" : " · ") : "")
                  + (Player.hasVideo ? "" : MediaInput.formatTime(preview.ms))
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            visible: Player.hasVideo
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 9
            text: MediaInput.formatTime(preview.ms)
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Bold
        }
        Rectangle {
            visible: !Player.hasVideo
            anchors.fill: parent
            z: -1
            radius: 6
            color: Qt.rgba(0.07, 0.07, 0.09, 0.92)
        }
    }
}
