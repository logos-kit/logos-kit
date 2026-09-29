import QtQuick
import QtQuick.Layouts

// From 21st.dev sean0205/item-action-list (id 28284, row anatomy) and the
// asset rows of Rabby / Family: icon, name, a quiet second line, the amount
// right-aligned in tabular figures with its secondary value underneath.
// `loading` swaps in a matching skeleton so nothing jumps.
Item {
    id: tr
    property string name: ""
    property string symbol: ""
    property string definition: ""
    property url iconSource: ""
    property string amount: ""
    property string sub: ""              // e.g. "Private · 3 notes"
    property string amountSub: ""
    property bool isPrivate: false
    property bool loading: false
    property bool chevron: false
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 64

    Rectangle {
        anchors.fill: parent
        radius: Theme.rRow
        color: mouse.pressed ? Theme.soft(Theme.text, 0.07) : mouse.containsMouse ? Theme.soft(Theme.text, 0.04) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.dFast } }
    }
    SkeletonCard { visible: tr.loading; anchors.fill: parent; anchors.margins: 12; variant: "row" }
    RowLayout {
        visible: !tr.loading
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12
        TokenIcon { definition: tr.definition; source: tr.iconSource; size: 40; isPrivate: tr.isPrivate }
        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true
            Txt { text: tr.name; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
            Txt { text: tr.sub !== "" ? tr.sub : tr.symbol; tone: tr.isPrivate ? "priv" : "text2"; font.pixelSize: 12; Layout.fillWidth: true }
        }
        ColumnLayout {
            spacing: 2
            Txt { Layout.alignment: Qt.AlignRight; text: tr.amount; num: true; font.pixelSize: 15; font.weight: Font.DemiBold }
            Txt { Layout.alignment: Qt.AlignRight; visible: tr.amountSub !== ""; text: tr.amountSub; num: true; tone: "text2"; font.pixelSize: 12 }
        }
        Glyph { visible: tr.chevron; name: "chevronRight"; color: Theme.text3; width: 16; height: 16 }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: !tr.loading; cursorShape: Qt.PointingHandCursor; onClicked: tr.clicked() }
}
