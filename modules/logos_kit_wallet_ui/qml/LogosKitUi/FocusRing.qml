import QtQuick

// The keyboard focus ring every focusable control shows (2 px action blue,
// 3 px outside the control). Put it inside the control with
// `anchors.fill: parent`; it follows `target.activeFocus`.
Rectangle {
    property Item target: parent
    property real ringRadius: target && target.radius !== undefined ? target.radius + 3 : 12
    anchors.margins: -3
    radius: ringRadius
    color: "transparent"
    border.width: 2
    border.color: Theme.soft(Theme.action, 0.8)
    visible: target ? target.activeFocus : false
    z: 100
}
