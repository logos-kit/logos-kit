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
    // Trust (docs/design/ux-tokens-nfts.md §2.1): a check after a verified
    // token's name, a quiet chip ("Added"), the warning tone for unknown.
    property bool verified: false
    property string chip: ""
    property bool warn: false
    signal clicked()
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: tr.name + " " + tr.amount + " " + tr.symbol
    Keys.onReturnPressed: if (!tr.loading) tr.clicked()
    Keys.onSpacePressed: if (!tr.loading) tr.clicked()

    Layout.fillWidth: true
    implicitHeight: 68

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
        TokenIcon { definition: tr.definition; source: tr.iconSource; label: tr.symbol !== "" ? tr.symbol : tr.name; warn: tr.warn; size: 44; isPrivate: tr.isPrivate }
        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true
            RowLayout {
                spacing: 6
                Layout.fillWidth: true
                Txt { text: tr.name; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: false; Layout.maximumWidth: tr.width * 0.45 }
                Glyph { visible: tr.verified; name: "check"; color: Theme.action; width: 14; height: 14; stroke: 2.6 }
                Tag { visible: tr.chip !== ""; text: tr.chip; tone: tr.warn ? "unconfirmed" : "pending" }
                Item { Layout.fillWidth: true }
            }
            Txt { text: tr.sub !== "" ? tr.sub : tr.symbol; tone: tr.isPrivate ? "priv" : "text2"; font.pixelSize: 12; Layout.fillWidth: true }
        }
        ColumnLayout {
            spacing: 2
            Txt { Layout.alignment: Qt.AlignRight; text: tr.amount; num: true; font.pixelSize: 16; font.weight: Font.DemiBold }
            Txt { Layout.alignment: Qt.AlignRight; visible: tr.amountSub !== ""; text: tr.amountSub; num: true; tone: "text2"; font.pixelSize: 12 }
        }
        Glyph { visible: tr.chevron; name: "chevronRight"; color: Theme.text3; width: 16; height: 16 }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; enabled: !tr.loading; cursorShape: Qt.PointingHandCursor; onClicked: tr.clicked() }
    FocusRing { anchors.fill: parent; ringRadius: Theme.rRow + 3 }
}
