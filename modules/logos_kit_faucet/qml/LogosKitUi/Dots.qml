import QtQuick

// From 21st.dev loading-ui/dots (id 19935):
// https://21st.dev/@loading-ui/components/dots
// Three dots rising and dimming in a staggered wave (1.2 s cycle, 160 ms
// stagger). For "waiting on someone else" states: the other app, the chain.
Row {
    id: d
    property color color: Theme.text2
    property real size: 6
    property bool running: visible && !Theme.reducedMotion
    spacing: size * 0.8
    Repeater {
        model: 3
        Rectangle {
            id: dot
            width: d.size; height: d.size; radius: d.size / 2
            color: d.color
            opacity: 0.35
            SequentialAnimation {
                running: d.running
                loops: Animation.Infinite
                PauseAnimation { duration: index * 160 }
                ParallelAnimation {
                    NumberAnimation { target: dot; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
                    NumberAnimation { target: dot; property: "y"; to: -d.size * 0.6; duration: 300; easing.type: Easing.OutCubic }
                }
                ParallelAnimation {
                    NumberAnimation { target: dot; property: "opacity"; to: 0.35; duration: 380; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: dot; property: "y"; to: 0; duration: 380; easing.type: Easing.InOutCubic }
                }
                PauseAnimation { duration: (2 - index) * 160 + 200 }
            }
        }
    }
}
