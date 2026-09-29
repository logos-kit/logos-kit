import QtQuick

// A round icon button: hover tint, 0.92 press, focus ring.
Item {
    id: ib
    property string glyph: "x"
    property real size: 36
    property color color: Theme.text2
    property bool filled: false
    signal clicked()
    implicitWidth: size
    implicitHeight: size
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: glyph
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: ib.filled ? Theme.surface2 : mouse.containsMouse ? Theme.soft(Theme.text, 0.07) : "transparent"
        scale: mouse.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: Theme.dPress } }
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
        Glyph { anchors.centerIn: parent; name: ib.glyph; color: ib.color; width: ib.size * 0.46; height: width }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
    Keys.onReturnPressed: clicked()
    Keys.onSpacePressed: clicked()
    FocusRing { anchors.fill: parent; ringRadius: width / 2 + 3 }
}
