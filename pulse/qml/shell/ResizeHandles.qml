import QtQuick

// Edge and corner grips for the frameless desktop window.
Item {
    id: root
    property var window
    property int grip: 6
    anchors.fill: parent

    component Grip: MouseArea {
        property int edges
        hoverEnabled: true
        onPressed: root.window.startSystemResize(edges)
    }
    Grip { edges: Qt.LeftEdge; cursorShape: Qt.SizeHorCursor; x: 0; y: root.grip; width: root.grip; height: parent.height - 2 * root.grip }
    Grip { edges: Qt.RightEdge; cursorShape: Qt.SizeHorCursor; x: parent.width - root.grip; y: root.grip; width: root.grip; height: parent.height - 2 * root.grip }
    Grip { edges: Qt.TopEdge; cursorShape: Qt.SizeVerCursor; x: root.grip; y: 0; width: parent.width - 2 * root.grip; height: root.grip }
    Grip { edges: Qt.BottomEdge; cursorShape: Qt.SizeVerCursor; x: root.grip; y: parent.height - root.grip; width: parent.width - 2 * root.grip; height: root.grip }
    Grip { edges: Qt.LeftEdge | Qt.TopEdge; cursorShape: Qt.SizeFDiagCursor; width: root.grip; height: root.grip }
    Grip { edges: Qt.RightEdge | Qt.BottomEdge; cursorShape: Qt.SizeFDiagCursor; x: parent.width - root.grip; y: parent.height - root.grip; width: root.grip; height: root.grip }
    Grip { edges: Qt.RightEdge | Qt.TopEdge; cursorShape: Qt.SizeBDiagCursor; x: parent.width - root.grip; width: root.grip; height: root.grip }
    Grip { edges: Qt.LeftEdge | Qt.BottomEdge; cursorShape: Qt.SizeBDiagCursor; y: parent.height - root.grip; width: root.grip; height: root.grip }
}
