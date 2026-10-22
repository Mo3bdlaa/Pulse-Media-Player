import QtQuick
import QtQuick.Shapes
import QtQuick.Particles
import Pulse
import Pulse.Core

// Signal Ember brand scene: molten planet over a ridge line with drifting
// embers. Drawn in code (no stock art), so it scales to any size and stays
// owned by Pulse. Used for Home and page banners only.
Item {
    id: root
    property bool animated: !Prefs.reduceMotion
    property real planetX: width * 0.80
    property real planetY: height * 0.42
    property real planetR: Math.min(width * 0.17, height * 0.62)
    property real horizon: height * 0.70
    property bool fadeLeft: true
    property color base: Theme.bg
    clip: true

    function ridge(seed, baseY, amp, step) {
        const pts = [Qt.point(0, height)]
        let s = seed
        const rnd = () => { s = (s * 9301 + 49297) % 233280; return s / 233280 }
        for (let x = 0; x <= width + step; x += step) {
            const n = Math.sin(x * 0.004 + seed) * 0.5 + Math.sin(x * 0.011 + seed * 2) * 0.3 + rnd() * 0.45
            pts.push(Qt.point(x, baseY - n * amp))
        }
        pts.push(Qt.point(width + step, height))
        return pts
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#140806" }
            GradientStop { position: 0.55; color: "#3A1409" }
            GradientStop { position: 0.75; color: "#5A1F0B" }
            GradientStop { position: 1.0; color: "#1A0906" }
        }
    }

    // Halo and planet.
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.planetX; centerY: root.planetY; centerRadius: root.planetR * 2.6
                focalX: root.planetX; focalY: root.planetY
                GradientStop { position: 0.0; color: Qt.rgba(1, 0.62, 0.30, 0.55) }
                GradientStop { position: 0.38; color: Qt.rgba(1, 0.40, 0.14, 0.20) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.planetX - root.planetR * 0.35; centerY: root.planetY - root.planetR * 0.35
                centerRadius: root.planetR * 1.5
                focalX: centerX; focalY: centerY
                GradientStop { position: 0.0; color: "#FFE7B0" }
                GradientStop { position: 0.22; color: "#FFB45C" }
                GradientStop { position: 0.55; color: "#F0631F" }
                GradientStop { position: 0.85; color: "#9A2A10" }
                GradientStop { position: 1.0; color: "#5A1608" }
            }
            startX: root.planetX + root.planetR; startY: root.planetY
            PathArc { x: root.planetX - root.planetR; y: root.planetY; radiusX: root.planetR; radiusY: root.planetR }
            PathArc { x: root.planetX + root.planetR; y: root.planetY; radiusX: root.planetR; radiusY: root.planetR }
        }
        // Night side.
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: root.planetX - root.planetR; y1: root.planetY - root.planetR
                x2: root.planetX + root.planetR; y2: root.planetY + root.planetR
                GradientStop { position: 0.45; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0.08, 0.02, 0.01, 0.75) }
            }
            startX: root.planetX + root.planetR; startY: root.planetY
            PathArc { x: root.planetX - root.planetR; y: root.planetY; radiusX: root.planetR; radiusY: root.planetR }
            PathArc { x: root.planetX + root.planetR; y: root.planetY; radiusX: root.planetR; radiusY: root.planetR }
        }
    }

    // Horizon haze.
    Rectangle {
        y: root.horizon - root.height * 0.22
        width: root.width
        height: root.height * 0.34
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.6; color: Qt.rgba(1, 0.42, 0.14, 0.32) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Ridges: far (lit edge) and near (silhouette).
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeColor: Qt.rgba(1, 0.48, 0.18, 0.55)
            strokeWidth: 1.5
            fillGradient: LinearGradient {
                x1: 0; y1: root.horizon - root.height * 0.18; x2: 0; y2: root.height
                GradientStop { position: 0.0; color: "#4A1A0C" }
                GradientStop { position: 1.0; color: "#160806" }
            }
            PathPolyline { path: root.ridge(3, root.horizon, root.height * 0.20, 26) }
        }
        ShapePath {
            strokeColor: Qt.rgba(1, 0.40, 0.12, 0.35)
            strokeWidth: 1
            fillColor: "#0D0505"
            PathPolyline { path: root.ridge(11, root.horizon + root.height * 0.16, root.height * 0.16, 34) }
        }
    }

    // Embers.
    ParticleSystem { id: sparks; running: root.animated && root.visible }
    ImageParticle {
        system: sparks
        source: "qrc:/qt/qml/Pulse/assets/fx/ember.png"
        colorVariation: 0.1
        entryEffect: ImageParticle.Fade
    }
    Emitter {
        system: sparks
        x: root.width * 0.35
        width: root.width * 0.65
        y: root.horizon
        height: root.height - root.horizon
        emitRate: root.width / 70
        lifeSpan: 4200
        lifeSpanVariation: 1800
        size: 5
        sizeVariation: 4
        endSize: 1
        velocity: AngleDirection { angle: 270; angleVariation: 22; magnitude: 26; magnitudeVariation: 14 }
        acceleration: AngleDirection { angle: 0; angleVariation: 180; magnitude: 4 }
    }

    // Blend into the app ground: bottom always, left for text legibility.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1.0; color: root.base }
        }
    }
    Rectangle {
        visible: root.fadeLeft
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.96) }
            GradientStop { position: 0.38; color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.72) }
            GradientStop { position: 0.62; color: "transparent" }
        }
    }
}
