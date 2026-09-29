import QtQuick
import QtQuick.Layouts

// From 21st.dev rmahammad/processing-timeline (id 29371):
// https://21st.dev/@rmahammad/components/processing-timeline
// One item moving through ordered stages: approve → prove → sign → submit →
// included. Presentation only: the host owns every status; nothing here
// advances by itself or claims a stage finished.
//
// stages: [{ label, detail?, status: pending|active|done|failed|skipped,
//            progress?: 0..1, elapsed?: "1:24" }]
// Rail 2 px, travelled in `accent`; the active node pulses (scale 1→1.7,
// 1.4 s); rows enter with a 260 ms rise on the emphasized curve.
ColumnLayout {
    id: pl
    property var stages: []
    property color accent: Theme.action
    property bool compact: false
    spacing: 0

    function tone(s) {
        return s === "done" ? Theme.ok : s === "active" ? pl.accent
             : s === "failed" ? Theme.danger : Theme.text3
    }

    Repeater {
        model: pl.stages
        Item {
            id: row
            readonly property var st: modelData
            readonly property bool last: index === pl.stages.length - 1
            readonly property bool travelled: st.status === "done" || st.status === "skipped"
            Layout.fillWidth: true
            implicitHeight: body.implicitHeight + (last ? 0 : (pl.compact ? 12 : 18))

            opacity: 0
            transform: Translate { id: rise; y: 8 }
            Component.onCompleted: enter.start()
            ParallelAnimation {
                id: enter
                PauseAnimation { duration: Theme.reducedMotion ? 0 : index * 40 }
                NumberAnimation { target: row; property: "opacity"; to: 1; duration: Theme.dBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emph }
                NumberAnimation { target: rise; property: "y"; to: 0; duration: Theme.dBase; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emph }
            }

            // rail
            Rectangle {
                visible: !row.last
                x: node.width / 2 - 1
                y: node.height + 3
                width: 2
                height: row.height - node.height
                radius: 1
                color: Theme.line
                Rectangle {
                    width: parent.width
                    radius: 1
                    color: pl.accent
                    height: row.travelled ? parent.height : 0
                    Behavior on height { NumberAnimation { duration: Theme.dSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emph } }
                }
            }

            // node
            Item {
                id: node
                width: pl.compact ? 20 : 24
                height: width
                Rectangle {
                    // pulse ring on the active stage
                    anchors.centerIn: parent
                    width: parent.width; height: width; radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: pl.accent
                    visible: row.st.status === "active" && !Theme.reducedMotion
                    SequentialAnimation on scale { loops: Animation.Infinite; running: parent.visible
                        NumberAnimation { from: 1; to: 1.7; duration: 1400; easing.type: Easing.OutCubic } }
                    SequentialAnimation on opacity { loops: Animation.Infinite; running: parent.visible
                        NumberAnimation { from: 0.5; to: 0; duration: 1400; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: row.st.status === "done" ? Theme.ok : row.st.status === "failed" ? Theme.danger
                         : row.st.status === "active" ? Theme.soft(pl.accent, 0.14) : "transparent"
                    border.width: row.st.status === "done" || row.st.status === "failed" ? 0 : 2
                    border.color: pl.tone(row.st.status)
                    Behavior on color { ColorAnimation { duration: Theme.dBase } }
                    Glyph {
                        anchors.centerIn: parent
                        visible: row.st.status === "done" || row.st.status === "failed" || row.st.status === "skipped"
                        name: row.st.status === "failed" ? "x" : row.st.status === "skipped" ? "chevronRight" : "check"
                        color: row.st.status === "skipped" ? Theme.text3 : "#ffffff"
                        width: parent.width * 0.55; height: width; stroke: 3
                        scale: visible ? 1 : 0.4
                        Behavior on scale { NumberAnimation { duration: Theme.dBase; easing.type: Easing.OutBack } }
                    }
                    Rectangle {
                        visible: row.st.status === "active"
                        anchors.centerIn: parent
                        width: parent.width * 0.34; height: width; radius: width / 2
                        color: pl.accent
                    }
                }
            }

            ColumnLayout {
                id: body
                x: node.width + 14
                width: row.width - x
                spacing: 3
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Txt {
                        text: row.st.label || ""
                        font.pixelSize: pl.compact ? 13 : 14
                        font.weight: row.st.status === "active" ? Font.DemiBold : Font.Medium
                        tone: row.st.status === "pending" ? "text3" : row.st.status === "failed" ? "danger" : "text"
                        Layout.fillWidth: true
                    }
                    Txt {
                        visible: !!row.st.elapsed
                        text: row.st.elapsed || ""
                        num: true
                        tone: row.st.status === "active" ? "text" : "text3"
                        font.pixelSize: 12
                    }
                }
                Txt {
                    visible: !!row.st.detail
                    text: row.st.detail || ""
                    tone: row.st.status === "failed" ? "danger" : "text2"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                    Layout.fillWidth: true
                }
                ProgressBar {
                    visible: row.st.status === "active" && row.st.progress !== undefined
                    value: row.st.progress || 0
                    indeterminate: row.st.progress === -1
                    fillColor: pl.accent
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                }
            }
        }
    }
}
