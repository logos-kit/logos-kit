import QtQuick
import QtQuick.Layouts

// From 21st.dev beratberkayg/wallet-card-2 (id 5214, balance + hide toggle +
// actions): https://21st.dev/@beratberkayg/components/wallet-card-2
// The home hero: a label, the balance rolling in a NumberTicker, a hide
// toggle, an optional private line, and a row of round actions (slot).
ColumnLayout {
    id: bc
    property string label: "Total balance"
    property string value: "0"
    property string symbol: "LEZ"
    property string privateLine: ""
    property bool hidden: false
    property bool loading: false
    default property alias actions: act.data
    signal hideToggled(bool hidden)
    spacing: 8

    RowLayout {
        spacing: 6
        Txt { text: bc.label; tone: "text2"; font.pixelSize: 13 }
        IconButton { glyph: "eye"; size: 26; color: Theme.text3; onClicked: { bc.hidden = !bc.hidden; bc.hideToggled(bc.hidden) } }
    }
    Item {
        Layout.fillWidth: true
        implicitHeight: 52
        Skeleton { visible: bc.loading; width: 200; height: 40; radius: 12; anchors.verticalCenter: parent.verticalCenter }
        RowLayout {
            visible: !bc.loading
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            NumberTicker { value: bc.value; masked: bc.hidden; pixelSize: 44; weight: Font.Bold }
            Txt { text: bc.symbol; tone: "text2"; font.pixelSize: 20; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignBaseline }
        }
    }
    RowLayout {
        visible: bc.privateLine !== ""
        spacing: 6
        Glyph { name: "lock"; color: Theme.privText; width: 13; height: 13 }
        Txt { text: bc.hidden ? "Private ••••" : bc.privateLine; tone: "priv"; num: true; font.pixelSize: 13 }
    }
    RowLayout { id: act; Layout.topMargin: 10; spacing: 12 }
}
