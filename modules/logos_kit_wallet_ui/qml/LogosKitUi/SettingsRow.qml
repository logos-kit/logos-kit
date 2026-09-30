import QtQuick
import QtQuick.Layouts

// From 21st.dev sean0205/item-action-list (id 28284) and shadcnspace/
// notification-settings-field (id 26523): an icon tile, a title and one line
// of description, and a trailing slot (a Toggle, a value, or a chevron).
Item {
    id: sr
    property string glyph: "sliders"
    property string title: ""
    property string description: ""
    property string value: ""
    property bool chevron: true
    property string tone: "text"
    default property alias trailing: slot.data
    signal clicked()
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: sr.title + (sr.value ? ", " + sr.value : "")
    Keys.onReturnPressed: if (sr.chevron) sr.clicked()
    Keys.onSpacePressed: if (sr.chevron) sr.clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(60, lay.implicitHeight + 20)

    Rectangle {
        anchors.fill: parent
        radius: Theme.rRow
        color: mouse.containsMouse && sr.chevron ? Theme.soft(Theme.text, 0.04) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
    }
    RowLayout {
        id: lay
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12
        Rectangle {
            implicitWidth: 36; implicitHeight: 36; radius: 11
            color: sr.tone === "danger" ? Theme.soft(Theme.danger, 0.12) : Theme.surface2
            Glyph { anchors.centerIn: parent; name: sr.glyph; color: sr.tone === "danger" ? Theme.danger : Theme.text2; width: 17; height: 17 }
        }
        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true
            Txt { text: sr.title; tone: sr.tone === "danger" ? "danger" : "text"; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.fillWidth: true }
            Txt { visible: sr.description !== ""; text: sr.description; tone: "text2"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
        }
        Txt { visible: sr.value !== ""; text: sr.value; tone: "text2"; font.pixelSize: 13 }
        Item { id: slot; implicitWidth: childrenRect.width; implicitHeight: childrenRect.height; visible: children.length > 0 }
        Glyph { visible: sr.chevron && slot.children.length === 0; name: "chevronRight"; color: Theme.text3; width: 16; height: 16 }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: sr.chevron; cursorShape: Qt.PointingHandCursor; onClicked: sr.clicked(); z: -1 }
    FocusRing { anchors.fill: parent; ringRadius: Theme.rRow + 3 }
}
