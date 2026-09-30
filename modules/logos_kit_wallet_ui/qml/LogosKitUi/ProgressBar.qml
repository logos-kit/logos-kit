import QtQuick

// From 21st.dev edwinvakayil/progress (id 26542): a 6 px bar whose fill
// eases to `value` (0..1, 300 ms ease-out). `indeterminate` slides a 35%
// segment back and forth instead.
Rectangle {
    id: bar
    property real value: 0
    property bool indeterminate: false
    property color fillColor: Theme.action
    implicitHeight: 6
    radius: height / 2
    color: Theme.surface2
    clip: true
    Rectangle {
        id: fill
        height: parent.height
        radius: parent.radius
        color: bar.fillColor
        width: bar.indeterminate ? bar.width * 0.35 : bar.width * Math.max(0, Math.min(1, bar.value))
        Behavior on width { enabled: !bar.indeterminate && !Theme.reducedMotion; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        SequentialAnimation on x {
            running: bar.indeterminate && bar.visible && !Theme.reducedMotion
            loops: Animation.Infinite
            NumberAnimation { from: -bar.width * 0.35; to: bar.width; duration: 1100; easing.type: Easing.InOutCubic }
        }
    }
}
