import QtQuick
import Pulse

// Crop box over the preview (Edit & Export). `crop` is normalised to the
// source frame (x, y, w, h in 0..1); `aspect` (width / height in source
// pixels, 0 = free) constrains it. Lives inside the transformed preview,
// so dragging works the same whatever the rotation or flip.
Item {
    id: root
    property var crop: ({ x: 0, y: 0, w: 1, h: 1 })
    property real aspect: 0
    property real sourceAspect: 16 / 9   // source width / height
    signal edited(var crop)

    readonly property real minSize: 0.08

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    // Height (normalised) that gives `aspect` for a normalised width.
    function hFor(w) { return root.aspect > 0 ? w * root.sourceAspect / root.aspect : -1 }

    function resize(corner, px, py, start) {
        let x0 = start.x, y0 = start.y, x1 = start.x + start.w, y1 = start.y + start.h
        const nx = clamp(px / width, 0, 1), ny = clamp(py / height, 0, 1)
        if (corner.indexOf("l") >= 0) x0 = Math.min(nx, x1 - minSize)
        if (corner.indexOf("r") >= 0) x1 = Math.max(nx, x0 + minSize)
        if (corner.indexOf("t") >= 0) y0 = Math.min(ny, y1 - minSize)
        if (corner.indexOf("b") >= 0) y1 = Math.max(ny, y0 + minSize)
        let w = x1 - x0, h = y1 - y0
        if (root.aspect > 0) {
            h = hFor(w)
            if (corner.indexOf("t") >= 0) y0 = y1 - h; else y1 = y0 + h
            if (y0 < 0 || y1 > 1) {          // too tall: fit height, recompute width
                h = corner.indexOf("t") >= 0 ? y1 : 1 - y0
                y0 = corner.indexOf("t") >= 0 ? 0 : y0
                w = h * root.aspect / root.sourceAspect
                if (corner.indexOf("l") >= 0) x0 = x1 - w; else x1 = x0 + w
            }
        }
        root.edited({ x: clamp(x0, 0, 1 - w), y: clamp(y0, 0, 1 - h), w: w, h: h })
    }

    // Dim everything outside the box.
    Rectangle { x: 0; y: 0; width: parent.width; height: box.y; color: Qt.rgba(0, 0, 0, 0.6) }
    Rectangle { x: 0; y: box.y + box.height; width: parent.width; height: parent.height - y; color: Qt.rgba(0, 0, 0, 0.6) }
    Rectangle { x: 0; y: box.y; width: box.x; height: box.height; color: Qt.rgba(0, 0, 0, 0.6) }
    Rectangle { x: box.x + box.width; y: box.y; width: parent.width - x; height: box.height; color: Qt.rgba(0, 0, 0, 0.6) }

    Rectangle {
        id: box
        x: root.crop.x * root.width
        y: root.crop.y * root.height
        width: root.crop.w * root.width
        height: root.crop.h * root.height
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        // Rule of thirds.
        Repeater {
            model: 2
            delegate: Item {
                required property int index
                anchors.fill: parent
                Rectangle { x: box.width * (index + 1) / 3; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.35) }
                Rectangle { y: box.height * (index + 1) / 3; height: 1; width: parent.width; color: Qt.rgba(1, 1, 1, 0.35) }
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: 14
            cursorShape: Qt.SizeAllCursor
            property var start
            property point grab
            onPressed: (m) => { start = root.crop; grab = mapToItem(root, m.x, m.y) }
            onPositionChanged: (m) => {
                const p = mapToItem(root, m.x, m.y)
                root.edited({ x: root.clamp(start.x + (p.x - grab.x) / root.width, 0, 1 - start.w),
                              y: root.clamp(start.y + (p.y - grab.y) / root.height, 0, 1 - start.h),
                              w: start.w, h: start.h })
            }
        }
    }

    Repeater {
        model: ["tl", "tr", "bl", "br"]
        delegate: Rectangle {
            id: handle
            required property string modelData
            width: 22; height: 22; radius: 11
            color: Theme.text
            border.width: 3
            border.color: Theme.accent
            x: (modelData[1] === "l" ? box.x : box.x + box.width) - width / 2
            y: (modelData[0] === "t" ? box.y : box.y + box.height) - height / 2
            Accessible.role: Accessible.Indicator
            Accessible.name: qsTr("Crop corner")
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: handle.modelData === "tl" || handle.modelData === "br" ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                property var start
                onPressed: start = root.crop
                onPositionChanged: (m) => {
                    const p = mapToItem(root, m.x, m.y)
                    root.resize(handle.modelData[0] + handle.modelData[1], p.x, p.y, start)
                }
            }
        }
    }
}
