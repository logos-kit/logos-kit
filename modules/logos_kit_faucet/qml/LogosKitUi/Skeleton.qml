import QtQuick

// Loading placeholder: a rounded bar with a slow shimmer.
Rectangle {
    id: sk
    implicitHeight: 14
    radius: Math.min(height / 2, 8)
    color: Theme.surface2
    clip: true
    Rectangle {
        width: sk.width * 0.5
        height: sk.height
        x: -width
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.soft(Theme.text, Theme.dark ? 0.06 : 0.05) }
            GradientStop { position: 1; color: "transparent" }
        }
        NumberAnimation on x {
            from: -sk.width * 0.5; to: sk.width; duration: 1300
            loops: Animation.Infinite; running: sk.visible && !Theme.reducedMotion
        }
    }
}
