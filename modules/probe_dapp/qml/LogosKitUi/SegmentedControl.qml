import QtQuick
import QtQuick.Layouts

// From 21st.dev ddoemonn/segmented-control (id 23552, sliding pill on a
// stiff spring: 520 / 34 / 0.45) and micka_design/segmented-tabs (id 26923):
// https://21st.dev/@ddoemonn/components/segmented-control
// options: ["Public", "Private"] or [{label, glyph?}]. Arrow keys move.
Rectangle {
    id: seg
    property var options: []
    property int currentIndex: 0
    property color pillColor: Theme.dark ? Qt.lighter(Theme.surface2, 1.55) : Theme.surface
    signal activated(int index)
    implicitHeight: 38
    implicitWidth: row.implicitWidth + 8
    radius: height / 2
    color: Theme.surface2
    activeFocusOnTab: true

    function labelOf(o) { return typeof o === "string" ? o : o.label }
    function glyphOf(o) { return typeof o === "string" ? "" : (o.glyph || "") }

    Rectangle {
        id: pill
        readonly property Item target: rep.count > seg.currentIndex ? rep.itemAt(seg.currentIndex) : null
        y: 4
        height: seg.height - 8
        radius: height / 2
        color: seg.pillColor
        border.width: Theme.dark ? 0 : 1
        border.color: Theme.line
        x: target ? target.x + row.x : 4
        width: target ? target.width : 0
        Behavior on x { enabled: !Theme.reducedMotion; SpringAnimation { spring: 6; damping: 0.42; epsilon: 0.25 } }
        Behavior on width { enabled: !Theme.reducedMotion; SpringAnimation { spring: 6; damping: 0.42; epsilon: 0.25 } }
        Shadow { anchors.fill: parent; radius: parent.radius; level: 1; visible: !Theme.dark }
    }
    RowLayout {
        id: row
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Repeater {
            id: rep
            model: seg.options
            Item {
                implicitWidth: lab.implicitWidth + 30
                implicitHeight: seg.height - 8
                RowLayout {
                    id: lab
                    anchors.centerIn: parent
                    spacing: 6
                    Glyph { visible: seg.glyphOf(modelData) !== ""; name: seg.glyphOf(modelData); width: 14; height: 14
                            color: index === seg.currentIndex ? Theme.text : Theme.text2 }
                    Txt {
                        text: seg.labelOf(modelData)
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        tone: index === seg.currentIndex ? "text" : "text2"
                        Behavior on color { ColorAnimation { duration: Theme.dFast } }
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { seg.currentIndex = index; seg.activated(index) } }
            }
        }
    }
    Keys.onLeftPressed: if (currentIndex > 0) { currentIndex--; activated(currentIndex) }
    Keys.onRightPressed: if (currentIndex < options.length - 1) { currentIndex++; activated(currentIndex) }
}
