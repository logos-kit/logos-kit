import QtQuick
import "../LogosKitUi"
import QtQuick.Shapes

// Progress ring (proof sheet, island). `value` 0..1, eased, never backwards.
Item {
    id: ring
    property real value: 0
    property real size: 148
    property real thickness: 10
    property color track: Theme.surface2
    property color range: Theme.priv
    property real shown: 0
    width: size
    height: size
    onValueChanged: if (value > shown) shown = value
    Behavior on shown { NumberAnimation { duration: Theme.reducedMotion ? 0 : 600; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: ring.track
            strokeWidth: ring.thickness
            fillColor: "transparent"
            PathAngleArc { centerX: ring.size / 2; centerY: ring.size / 2; radiusX: (ring.size - ring.thickness) / 2; radiusY: (ring.size - ring.thickness) / 2; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: ring.range
            strokeWidth: ring.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: ring.size / 2; centerY: ring.size / 2; radiusX: (ring.size - ring.thickness) / 2; radiusY: (ring.size - ring.thickness) / 2; startAngle: -90; sweepAngle: 360 * Math.max(0.001, ring.shown) }
        }
    }
}
