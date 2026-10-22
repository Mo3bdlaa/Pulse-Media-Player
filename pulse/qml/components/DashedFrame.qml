import QtQuick
import QtQuick.Shapes
import Pulse

Shape {
    id: root
    property real radius: 14
    property color strokeColor: Qt.rgba(1, 0.416, 0.157, 0.45)
    readonly property real l: 0.75
    readonly property real t: 0.75
    readonly property real r: width - 0.75
    readonly property real b: height - 0.75
    readonly property real k: radius
    ShapePath {
        strokeColor: root.strokeColor
        strokeWidth: 1.5
        strokeStyle: ShapePath.DashLine
        dashPattern: [5, 4]
        fillColor: Qt.rgba(0.07, 0.07, 0.09, 0.72)
        startX: root.l + root.k; startY: root.t
        PathLine { x: root.r - root.k; y: root.t }
        PathArc { x: root.r; y: root.t + root.k; radiusX: root.k; radiusY: root.k }
        PathLine { x: root.r; y: root.b - root.k }
        PathArc { x: root.r - root.k; y: root.b; radiusX: root.k; radiusY: root.k }
        PathLine { x: root.l + root.k; y: root.b }
        PathArc { x: root.l; y: root.b - root.k; radiusX: root.k; radiusY: root.k }
        PathLine { x: root.l; y: root.t + root.k }
        PathArc { x: root.l + root.k; y: root.t; radiusX: root.k; radiusY: root.k }
    }
}
