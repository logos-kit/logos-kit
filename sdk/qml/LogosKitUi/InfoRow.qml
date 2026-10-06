import QtQuick
import QtQuick.Layouts

// Label / value row with a hairline above (review and approval sheets).
Item {
    id: row
    property string label: ""
    property string value: ""
    property string tone: "text"
    property bool mono: false
    default property alias extra: slot.data
    Layout.fillWidth: true
    implicitHeight: Math.max(40, lay.implicitHeight + 18)
    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.line }
    RowLayout {
        id: lay
        anchors.fill: parent
        anchors.topMargin: 9
        anchors.bottomMargin: 9
        spacing: 16
        Txt { text: row.label; tone: "text2"; font.pixelSize: 13; Layout.alignment: Qt.AlignTop }
        Item { Layout.fillWidth: true }
        Txt {
            visible: row.value !== ""
            text: row.value
            tone: row.tone
            mono: row.mono
            font.pixelSize: 13
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            Layout.maximumWidth: row.width * 0.64
        }
        Item { id: slot; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height; visible: children.length > 0 }
    }
}
