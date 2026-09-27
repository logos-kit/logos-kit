import QtQuick
import QtQuick.Shapes

Item {
    id: sp
    property real size: 20
    property color color: Theme.text2
    width: size
    height: size
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: sp.visible }
        ShapePath {
            strokeColor: sp.color
            strokeWidth: Math.max(2, sp.size / 9)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: sp.size / 2; centerY: sp.size / 2; radiusX: sp.size / 2 - 2; radiusY: sp.size / 2 - 2; startAngle: 0; sweepAngle: 270 }
        }
    }
}
