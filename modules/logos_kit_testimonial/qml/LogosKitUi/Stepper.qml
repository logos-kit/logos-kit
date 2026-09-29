import QtQuick
import QtQuick.Layouts

// From 21st.dev corr/stepper (id 28565):
// https://21st.dev/@corr/components/stepper
// Horizontal numbered steps (onboarding, multi-step forms). Done steps show a
// check, the current one is filled, connectors fill left to right (500 ms).
RowLayout {
    id: sp
    property var steps: []          // labels
    property int current: 0
    property color accent: Theme.text
    spacing: 8
    Repeater {
        model: sp.steps
        RowLayout {
            spacing: 8
            Layout.fillWidth: index < sp.steps.length - 1
            Rectangle {
                readonly property bool done: index < sp.current
                readonly property bool here: index === sp.current
                implicitWidth: 26; implicitHeight: 26; radius: 13
                color: done || here ? sp.accent : "transparent"
                border.width: done || here ? 0 : 1.5
                border.color: Theme.text3
                Behavior on color { ColorAnimation { duration: Theme.dBase } }
                Txt {
                    anchors.centerIn: parent
                    visible: !parent.done
                    text: index + 1
                    num: true
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: parent.here ? Theme.bg : Theme.text2
                }
                Glyph { anchors.centerIn: parent; visible: parent.done; name: "check"; color: Theme.bg; width: 13; height: 13; stroke: 3 }
            }
            Txt {
                text: modelData
                font.pixelSize: 13
                font.weight: index === sp.current ? Font.DemiBold : Font.Normal
                tone: index <= sp.current ? "text" : "text3"
            }
            Rectangle {
                visible: index < sp.steps.length - 1
                Layout.fillWidth: true
                Layout.minimumWidth: 16
                implicitHeight: 2
                radius: 1
                color: Theme.line
                Rectangle {
                    height: parent.height; radius: 1
                    color: sp.accent
                    width: index < sp.current ? parent.width : 0
                    Behavior on width { NumberAnimation { duration: Theme.dSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emph } }
                }
            }
        }
    }
}
