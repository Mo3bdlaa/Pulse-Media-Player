import QtQuick
import QtQuick.Window
import Pulse

// Recolourable stroke icon from assets/icons (see IconProvider).
Image {
    id: root
    property string name
    property color color: Theme.text
    property int size: 20

    width: size
    height: size
    source: name ? "image://icon/" + name + "?color=" + encodeURIComponent(color.toString()) : ""
    sourceSize: Qt.size(size * Screen.devicePixelRatio, size * Screen.devicePixelRatio)
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: false
    Accessible.ignored: true
}
