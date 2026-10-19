import QtQuick
import QtQuick.Controls.Basic as T
import QtQuick.Layouts
import Pulse
import Pulse.Core

// Edit & Export: trim, crop, rotate or flip, remove audio, then save a new
// file through the Convert queue. The original is never changed.
Item {
    id: root
    property url url
    property bool compact: false
    signal back()
    signal exported(string name)

    MediaInspector { id: inspector; url: root.visible ? root.url : "" }

    readonly property var v: (inspector.details.video || [])[0] || null
    readonly property int srcW: v ? v.width : 0
    readonly property int srcH: v ? v.height : 0
    readonly property real srcAspect: srcW > 0 && srcH > 0 ? srcW / srcH : 16 / 9
    readonly property double duration: inspector.details.durationMs || 0
    readonly property bool hasAudio: (inspector.details.audio || []).length > 0
    readonly property bool ready: srcW > 0 && duration > 0

    // Edit state.
    property double previewMs: 0
    property double startMs: 0
    property double endMs: 0            // 0 = to the end
    property string cropMode: "none"    // none | free | 16:9 | 4:3 | 1:1 | 9:16 | 21:9
    property var crop: ({ x: 0, y: 0, w: 1, h: 1 })
    property int turns: 0               // clockwise quarter turns
    property bool mirrored: false
    property bool noAudio: false
    property string preset: "mp4"
    property int resolution: 0

    readonly property double effectiveEnd: endMs > 0 ? endMs : duration
    readonly property var aspects: ({ "16:9": 16 / 9, "4:3": 4 / 3, "1:1": 1, "9:16": 9 / 16, "21:9": 21 / 9 })
    // The core's transform names for the rotation/flip combination.
    readonly property string transformType: mirrored ? ["hflip", "antitranspose", "vflip", "transpose"][turns]
                                                 : ["", "90", "180", "270"][turns]
    readonly property var cropPixels: cropMode === "none" ? null : {
        "x": Math.round(crop.x * srcW) & ~1, "y": Math.round(crop.y * srcH) & ~1,
        "w": Math.round(crop.w * srcW) & ~1, "h": Math.round(crop.h * srcH) & ~1
    }
    readonly property size outputSize: {
        let w = cropPixels ? cropPixels.w : srcW, h = cropPixels ? cropPixels.h : srcH
        if (turns % 2 === 1) { const t = w; w = h; h = t }
        return Qt.size(w, h)
    }
    readonly property bool changed: startMs > 0 || endMs > 0 || cropMode !== "none" || turns !== 0 || mirrored || noAudio

    onUrlChanged: reset()
    function reset() {
        previewMs = 0; startMs = 0; endMs = 0; cropMode = "none"; crop = { x: 0, y: 0, w: 1, h: 1 }
        turns = 0; mirrored = false; noAudio = false
    }

    function setCropMode(mode) {
        cropMode = mode
        if (mode === "none" || mode === "free") {
            if (mode === "none") crop = { x: 0, y: 0, w: 1, h: 1 }
            return
        }
        // Largest centred box with that shape.
        const a = aspects[mode]
        let w = 1, h = srcAspect / a
        if (h > 1) { h = 1; w = a / srcAspect }
        crop = { x: (1 - w) / 2, y: (1 - h) / 2, w: w, h: h }
    }

    function exportFile() {
        const edit = {
            startMs: Math.round(startMs), endMs: endMs > 0 && endMs < duration ? Math.round(endMs) : 0,
            transform: transformType, noAudio: noAudio, sourceWidth: srcW, sourceHeight: srcH
        }
        if (cropPixels && (cropPixels.w < srcW || cropPixels.h < srcH))
            edit.crop = [cropPixels.x, cropPixels.y, cropPixels.w, cropPixels.h]
        Converter.addEdit(url, edit, preset)
        root.exported(MediaInput.displayName(url))
    }

    component ToolTitle: Label { font.pixelSize: 14; font.weight: Font.Bold; Layout.topMargin: 4 }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.compact ? 12 : 24
        spacing: 14

        // ------------------------------------------------------------ header
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            IconButton { iconName: "chevron-left"; label: qsTr("Back"); variant: "overlay"; onClicked: root.back() }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { text: qsTr("Edit & Export"); font.pixelSize: root.compact ? 20 : 24; font.weight: Font.ExtraBold; Accessible.role: Accessible.Heading }
                Label { Layout.fillWidth: true; role: "meta"; secondary: true; text: MediaInput.displayName(root.url) + (root.ready ? "  ·  " + root.srcW + " × " + root.srcH + "  ·  " + MediaInput.formatTime(root.duration) : "") }
            }
            PulseButton { visible: root.changed; variant: "quiet"; text: qsTr("Reset"); onClicked: root.reset() }
            PulseButton { variant: "primary"; iconName: "download"; text: qsTr("Export"); enabled: root.ready && root.changed && root.effectiveEnd - root.startMs >= 500; onClicked: root.exportFile() }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.compact ? 1 : 2
            columnSpacing: 18
            rowSpacing: 14

            // -------------------------------------------------------- preview
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                Rectangle {
                    id: stage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 220
                    radius: 14
                    color: "#07080A"
                    clip: true

                    // Fit the (turned) frame inside the stage.
                    readonly property real frameAspect: root.turns % 2 ? 1 / root.srcAspect : root.srcAspect
                    readonly property real fitW: Math.min(width - 24, (height - 24) * frameAspect)
                    readonly property real fitH: fitW / frameAspect

                    Item {
                        id: frame
                        anchors.centerIn: parent
                        // Unturned size; the transform below turns and mirrors it.
                        width: root.turns % 2 ? stage.fitH : stage.fitW
                        height: root.turns % 2 ? stage.fitW : stage.fitH
                        transform: [
                            Scale { origin.x: frame.width / 2; origin.y: frame.height / 2; xScale: root.mirrored ? -1 : 1 },
                            Rotation { origin.x: frame.width / 2; origin.y: frame.height / 2; angle: root.turns * 90 }
                        ]
                        Behavior on width { enabled: !Prefs.reduceMotion; NumberAnimation { duration: Theme.motionFast } }

                        // Double-buffered so the frame never blinks while the next one loads.
                        Image {
                            id: shown
                            anchors.fill: parent
                            fillMode: Image.Stretch
                            sourceSize: Qt.size(1280, 1280)
                        }
                        Image {
                            id: loading
                            visible: false
                            asynchronous: true
                            sourceSize: Qt.size(1280, 1280)
                            source: root.ready && root.url.toString().startsWith("file:")
                                    ? "image://thumb/" + encodeURIComponent(root.url.toString()) + "?t=" + Math.round(root.previewMs / 250) * 250 + "&precise=1" : ""
                            onStatusChanged: if (status === Image.Ready) shown.source = source
                        }
                        CropOverlay {
                            anchors.fill: parent
                            visible: root.cropMode !== "none"
                            crop: root.crop
                            aspect: root.aspects[root.cropMode] || 0
                            sourceAspect: root.srcAspect
                            onEdited: (c) => root.crop = c
                        }
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: !root.ready
                        secondary: true
                        text: inspector.loading ? qsTr("Reading the video…") : qsTr("This file has no video to edit.")
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        visible: root.ready
                        width: sizeText.implicitWidth + 16
                        height: 26
                        radius: 6
                        color: Qt.rgba(0.05, 0.05, 0.06, 0.82)
                        Text { id: sizeText; anchors.centerIn: parent; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
                            text: MediaInput.formatTime(root.previewMs) + "   ·   " + qsTr("Output %1 × %2").arg(root.outputSize.width).arg(root.outputSize.height) }
                    }
                }

                // ---------------------------------------------------- trim
                Glass {
                    Layout.fillWidth: true
                    implicitHeight: trimCol.implicitHeight + 28
                    radius: 14
                    ColumnLayout {
                        id: trimCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            PulseIcon { name: "film"; size: 18; color: Theme.text }
                            Label { text: qsTr("Trim"); font.pixelSize: 14; font.weight: Font.Bold }
                            Item { Layout.fillWidth: true }
                            Label { role: "meta"; color: Theme.textEmphasis
                                text: qsTr("%1 – %2  ·  length %3").arg(MediaInput.formatTime(root.startMs)).arg(MediaInput.formatTime(root.effectiveEnd)).arg(MediaInput.formatTime(root.effectiveEnd - root.startMs)) }
                        }
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 64
                            // Filmstrip.
                            Row {
                                id: strip
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                clip: true
                                readonly property int count: Math.max(4, Math.floor(width / 96))
                                Repeater {
                                    model: root.ready ? strip.count : 0
                                    delegate: Image {
                                        required property int index
                                        width: strip.width / strip.count
                                        height: strip.height
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        sourceSize: Qt.size(192, 108)
                                        source: "image://thumb/" + encodeURIComponent(root.url.toString()) + "?t=" + Math.round(root.duration * (index + 0.5) / strip.count)
                                    }
                                }
                            }
                            T.RangeSlider {
                                id: range
                                anchors.fill: parent
                                enabled: root.ready
                                from: 0
                                to: Math.max(1, root.duration)
                                // Values follow the edit state; set after `to` so they are not clamped early.
                                function sync() { setValues(root.startMs, root.effectiveEnd) }
                                onToChanged: sync()
                                Connections { target: root; function onStartMsChanged() { range.sync() } function onEffectiveEndChanged() { range.sync() } }
                                leftPadding: 10
                                rightPadding: 10
                                first.onMoved: { root.startMs = Math.min(first.value, root.effectiveEnd - 500); root.previewMs = root.startMs }
                                second.onMoved: { root.endMs = Math.max(second.value, root.startMs + 500); root.previewMs = root.endMs }
                                Accessible.name: qsTr("Trim")
                                background: Item {
                                    // Shade what is cut away; frame what stays.
                                    Rectangle { x: range.leftPadding; width: range.first.visualPosition * range.availableWidth; height: parent.height; color: Qt.rgba(0, 0, 0, 0.62) }
                                    Rectangle { x: range.leftPadding + range.second.visualPosition * range.availableWidth; width: (1 - range.second.visualPosition) * range.availableWidth; height: parent.height; color: Qt.rgba(0, 0, 0, 0.62) }
                                    Rectangle {
                                        x: range.leftPadding + range.first.visualPosition * range.availableWidth
                                        width: (range.second.visualPosition - range.first.visualPosition) * range.availableWidth
                                        height: parent.height
                                        color: "transparent"
                                        radius: 6
                                        border.width: 3
                                        border.color: Theme.accent
                                    }
                                    Rectangle {   // preview position
                                        x: range.leftPadding + root.previewMs / Math.max(1, root.duration) * range.availableWidth - 1
                                        width: 2
                                        height: parent.height
                                        color: Theme.highlight
                                    }
                                }
                                first.handle: Rectangle {
                                    x: range.leftPadding + range.first.visualPosition * range.availableWidth - width / 2
                                    y: (range.height - height) / 2
                                    width: 16; height: range.height + 8; radius: 6
                                    color: Theme.accent
                                    Rectangle { anchors.centerIn: parent; width: 2; height: 20; color: "white" }
                                    Accessible.name: qsTr("Trim start")
                                }
                                second.handle: Rectangle {
                                    x: range.leftPadding + range.second.visualPosition * range.availableWidth - width / 2
                                    y: (range.height - height) / 2
                                    width: 16; height: range.height + 8; radius: 6
                                    color: Theme.accent
                                    Rectangle { anchors.centerIn: parent; width: 2; height: 20; color: "white" }
                                    Accessible.name: qsTr("Trim end")
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            PulseSlider {
                                Layout.fillWidth: true
                                from: 0
                                to: Math.max(1, root.duration)
                                value: root.previewMs
                                enabled: root.ready
                                Accessible.name: qsTr("Preview position")
                                onMoved: root.previewMs = value
                            }
                            PulseButton { implicitHeight: 36; font.pixelSize: 13; text: qsTr("Set Start"); enabled: root.ready && root.previewMs < root.effectiveEnd - 500; onClicked: root.startMs = root.previewMs }
                            PulseButton { implicitHeight: 36; font.pixelSize: 13; text: qsTr("Set End"); enabled: root.ready && root.previewMs > root.startMs + 500; onClicked: root.endMs = root.previewMs }
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: root.startMs > 0
                            wrapMode: Text.WordWrap
                            role: "meta"
                            secondary: true
                            text: qsTr("The cut starts at the nearest keyframe before the start point, so a moment of extra video may remain.")
                        }
                    }
                }
            }

            // -------------------------------------------------------- tools
            Glass {
                Layout.fillWidth: root.compact
                Layout.preferredWidth: root.compact ? -1 : 320
                Layout.fillHeight: !root.compact
                implicitHeight: tools.implicitHeight + 32
                radius: 16
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 16
                    contentHeight: tools.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    ColumnLayout {
                        id: tools
                        width: parent.width
                        spacing: 10

                        ToolTitle { text: qsTr("Crop") }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [
                                    { value: "none", text: qsTr("Original") }, { value: "free", text: qsTr("Free") },
                                    { value: "16:9", text: "16:9" }, { value: "4:3", text: "4:3" }, { value: "1:1", text: "1:1" },
                                    { value: "9:16", text: "9:16" }, { value: "21:9", text: "21:9" }
                                ]
                                delegate: PulseButton {
                                    required property var modelData
                                    implicitHeight: 34
                                    font.pixelSize: 12
                                    text: modelData.text
                                    active: root.cropMode === modelData.value
                                    enabled: root.ready
                                    onClicked: root.setCropMode(modelData.value)
                                }
                            }
                        }
                        Label { Layout.fillWidth: true; visible: root.cropMode !== "none"; role: "meta"; secondary: true; wrapMode: Text.WordWrap
                            text: qsTr("Drag the box or its corners on the picture.") }

                        ToolTitle { text: qsTr("Rotate & Flip") }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 8
                            rowSpacing: 8
                            PulseButton { Layout.fillWidth: true; implicitHeight: 40; iconName: "reset"; text: qsTr("Left"); enabled: root.ready; onClicked: root.turns = (root.turns + 3) % 4; Accessible.name: qsTr("Rotate left") }
                            PulseButton { Layout.fillWidth: true; implicitHeight: 40; iconName: "refresh"; text: qsTr("Right"); enabled: root.ready; onClicked: root.turns = (root.turns + 1) % 4; Accessible.name: qsTr("Rotate right") }
                            PulseButton { Layout.fillWidth: true; Layout.columnSpan: 2; implicitHeight: 40; iconName: "convert"; text: qsTr("Mirror"); active: root.mirrored; enabled: root.ready; onClicked: root.mirrored = !root.mirrored }
                        }
                        Label { Layout.fillWidth: true; role: "meta"; color: Theme.textEmphasis
                            text: root.turns === 0 && !root.mirrored ? qsTr("Upright") : [root.turns ? qsTr("Turned %1°").arg(root.turns * 90) : "", root.mirrored ? qsTr("mirrored") : ""].filter(s => s).join(", ") }

                        ToolTitle { text: qsTr("Audio") }
                        SettingRow {
                            label: qsTr("Remove audio")
                            PulseSwitch { checked: root.noAudio; enabled: root.hasAudio; onToggled: root.noAudio = checked; Accessible.name: qsTr("Remove audio") }
                        }

                        ToolTitle { text: qsTr("Save As") }
                        Dropdown {
                            Layout.fillWidth: true
                            model: Converter.presets.filter(p => p.id !== "mp3").map(p => ({ text: p.name, value: p.id }))
                            value: root.preset
                            onPicked: (v) => root.preset = v
                            Accessible.name: qsTr("Output format")
                        }
                        Label { Layout.fillWidth: true; role: "meta"; secondary: true; wrapMode: Text.WordWrap
                            text: qsTr("Saved next to the original as “%1”. The original is not changed.")
                                    .arg(MediaInput.displayName(MediaInput.localUrl(Converter.outputPathFor(root.url, root.preset, true)))) }
                        PulseButton {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            variant: "primary"
                            iconName: "download"
                            text: qsTr("Export")
                            enabled: root.ready && root.changed && root.effectiveEnd - root.startMs >= 500
                            onClicked: root.exportFile()
                        }
                        Label { Layout.fillWidth: true; visible: !root.changed; role: "meta"; secondary: true; wrapMode: Text.WordWrap
                            text: qsTr("Trim, crop, turn or remove the audio to export a new file.") }
                    }
                }
            }
        }
    }
}
