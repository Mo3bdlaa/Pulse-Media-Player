import QtQuick
import Qt5Compat.GraphicalEffects
import Pulse

// Soft orange bloom behind accent surfaces (buttons, active nav, play ring).
RectangularGlow {
    property Item target: parent
    property real strength: 1
    anchors.fill: target
    glowRadius: 14
    spread: 0.12
    cornerRadius: (target && target.radius !== undefined ? target.radius : 10) + glowRadius
    color: Theme.accentGlow
    opacity: strength
    z: -1
}
