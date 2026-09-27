import QtQuick

// Round 32 px control (close, back, settings).
Rectangle {
    id: ib
    property string icon: "x"
    property string label: ""
    signal clicked()
    width: 32
    height: 32
    radius: 16
    color: Theme.surface2
    opacity: enabled ? 1 : 0.3
    Accessible.role: Accessible.Button
    Accessible.name: label
    Glyph { anchors.centerIn: parent; name: ib.icon; color: Theme.text2; width: 15; height: 15 }
    scale: m.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: Theme.dPress } }
    MouseArea { id: m; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
}
