import QtQuick
import QtQuick.Shapes

// From 21st.dev arihantcodes/task-checkbox (id 29942, the spring fill and the
// drawn-in check) and ruixen.ui/success-login-card (id 7976, the burst):
// https://21st.dev/@arihantcodes_1f7b8c4d/components/task-checkbox
// The disc springs in (scale 0 → 1), the check draws its two strokes, and a
// ring bursts outward once. `play()` replays it; it plays when shown.
Item {
    id: sc
    property real size: 72
    property color color: Theme.ok
    implicitWidth: size
    implicitHeight: size
    property real disc: 0
    property real t1: 0     // first stroke 0..1
    property real t2: 0     // second stroke 0..1

    function play() {
        if (Theme.reducedMotion) { disc = 1; t1 = 1; t2 = 1; return }
        disc = 0; t1 = 0; t2 = 0; burst.scale = 1; burst.opacity = 0
        seq.restart()
    }
    onVisibleChanged: if (visible) play()
    Component.onCompleted: if (visible) play()

    SequentialAnimation {
        id: seq
        ParallelAnimation {
            SpringAnimation { target: sc; property: "disc"; to: 1; spring: 4; damping: 0.28; epsilon: 0.002 }
            SequentialAnimation {
                PauseAnimation { duration: 120 }
                ParallelAnimation {
                    NumberAnimation { target: burst; property: "scale"; from: 1; to: 1.55; duration: 520; easing.type: Easing.OutCubic }
                    NumberAnimation { target: burst; property: "opacity"; from: 0.45; to: 0; duration: 520; easing.type: Easing.OutCubic }
                }
            }
            SequentialAnimation {
                PauseAnimation { duration: 160 }
                NumberAnimation { target: sc; property: "t1"; to: 1; duration: 140; easing.type: Easing.InCubic }
                NumberAnimation { target: sc; property: "t2"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            }
        }
    }

    Rectangle {
        id: burst
        anchors.centerIn: parent
        width: sc.size; height: width; radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: sc.color
        opacity: 0
    }
    Rectangle {
        anchors.centerIn: parent
        width: sc.size; height: width; radius: width / 2
        color: Theme.soft(sc.color, 0.16)
        scale: sc.disc
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.72; height: width; radius: width / 2
            color: sc.color
        }
    }
    // The check: a short stroke down-right, then a long one up-right.
    Shape {
        id: tick
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real w: Math.max(2.5, sc.size / 16)
        readonly property real ax: sc.size * 0.34
        readonly property real ay: sc.size * 0.51
        readonly property real bx: sc.size * 0.45
        readonly property real by: sc.size * 0.62
        readonly property real cx: sc.size * 0.67
        readonly property real cy: sc.size * 0.39
        ShapePath {
            strokeColor: sc.t1 > 0 ? "#ffffff" : "transparent"
            strokeWidth: tick.w
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: tick.ax; startY: tick.ay
            PathLine { x: tick.ax + (tick.bx - tick.ax) * sc.t1; y: tick.ay + (tick.by - tick.ay) * sc.t1 }
        }
        ShapePath {
            strokeColor: sc.t2 > 0 ? "#ffffff" : "transparent"
            strokeWidth: tick.w
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: tick.bx; startY: tick.by
            PathLine { x: tick.bx + (tick.cx - tick.bx) * sc.t2; y: tick.by + (tick.cy - tick.by) * sc.t2 }
        }
    }
}
