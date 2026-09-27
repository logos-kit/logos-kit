import QtQuick

// The native token: the Logos mark on a black disc (never recoloured).
Rectangle {
    property real size: 36
    width: size
    height: size
    radius: size / 2
    color: "#0a0a0c"
    border.width: 1
    border.color: "#14ffffff"
    LogosMark { anchors.centerIn: parent; size: parent.size * 0.52; white: true }
}
