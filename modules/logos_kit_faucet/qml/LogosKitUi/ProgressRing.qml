import QtQuick
import QtQuick.Shapes

// From 21st.dev edwinvakayil/progress (id 26542, spring-smoothed ring) and
// diceui/circular-progress (id 24462):
// https://21st.dev/@edwinvakayil/components/progress
// A track and an arc that springs to `value` (0..1). `indeterminate` spins a
// 90° arc instead. The centre takes any child (a percentage, a countdown).
Item {
    id: ring
    property real value: 0
    property bool indeterminate: false
    property real size: 64
    property real thickness: Math.max(3, size / 11)
    property color color: Theme.action
    property color track: Theme.surface2
    default property alias content: centre.data
    implicitWidth: size
    implicitHeight: size

    property real shown: indeterminate ? 0.25 : Math.max(0, Math.min(1, value))
    Behavior on shown {
        enabled: !Theme.reducedMotion
        SpringAnimation { spring: 2.6; damping: 0.32; epsilon: 0.001 }
    }

    Shape {
        id: arc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: ring.track
            strokeWidth: ring.thickness
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: (ring.size - ring.thickness) / 2; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.color
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.size / 2; centerY: ring.size / 2
                radiusX: (ring.size - ring.thickness) / 2; radiusY: radiusX
                startAngle: -90; sweepAngle: Math.max(0.01, ring.shown * 360)
            }
        }
        RotationAnimator on rotation {
            from: 0; to: 360; duration: 1100; loops: Animation.Infinite
            running: ring.indeterminate && ring.visible && !Theme.reducedMotion
        }
        SequentialAnimation on opacity {
            loops: Animation.Infinite; running: ring.indeterminate && ring.visible && Theme.reducedMotion
            NumberAnimation { to: 0.35; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 1000; easing.type: Easing.InOutSine }
        }
    }
    Item { id: centre; anchors.centerIn: parent; width: childrenRect.width; height: childrenRect.height }
}
