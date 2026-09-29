import QtQuick
import QtQuick.Layouts

// An acknowledgement ("I understand this can't be undone"): a real check box
// with a wrapped label, focusable, Space/Enter toggles.
Item {
    id: cr
    property string text: ""
    property bool checked: false
    property color accent: Theme.action
    signal toggled(bool checked)
    Layout.fillWidth: true
    implicitHeight: Math.max(28, lab.implicitHeight + 8)
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.name: text
    function flip() { checked = !checked; toggled(checked) }
    Keys.onSpacePressed: flip()
    Keys.onReturnPressed: flip()
    RowLayout {
        anchors.fill: parent
        spacing: 10
        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            implicitWidth: 20; implicitHeight: 20; radius: 6
            color: cr.checked ? cr.accent : "transparent"
            border.width: cr.checked ? 0 : 1.5
            border.color: Theme.text3
            Behavior on color { ColorAnimation { duration: Theme.dFast } }
            Glyph { anchors.centerIn: parent; name: "check"; color: "#ffffff"; width: 12; height: 12; stroke: 3; visible: cr.checked }
        }
        Txt { id: lab; text: cr.text; font.pixelSize: 13; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { cr.forceActiveFocus(); cr.flip() } }
    FocusRing { anchors.fill: parent; ringRadius: 8 }
}
