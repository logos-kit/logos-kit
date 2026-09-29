import QtQuick
import QtQuick.Layouts
import "Units.js" as Units

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
    // Private buckets as three figures (raw integers; empty hides the row).
    property string privSpendable: ""
    property string privPending: ""
    property string privLocked: ""
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
            NumberTicker { value: Units.group(bc.value); masked: bc.hidden; pixelSize: 44; weight: Font.Bold }
            Txt { text: bc.symbol; tone: "text2"; font.pixelSize: 20; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignBaseline }
        }
    }
    RowLayout {
        visible: bc.privateLine !== ""
        spacing: 6
        Glyph { name: "lock"; color: Theme.privText; width: 13; height: 13 }
        Txt { text: bc.hidden ? "Private ••••" : bc.privateLine; tone: "priv"; num: true; font.pixelSize: 13 }
    }
    RowLayout {
        visible: bc.privSpendable !== ""
        Layout.topMargin: 4
        spacing: 8
        Repeater {
            model: [["Private spendable", bc.privSpendable], ["Pending", bc.privPending], ["Locked in proofs", bc.privLocked]]
            Rectangle {
                implicitWidth: col.implicitWidth + 24
                implicitHeight: col.implicitHeight + 16
                radius: 14
                color: index === 0 ? Theme.privSoft : Theme.surface2
                ColumnLayout {
                    id: col
                    anchors.centerIn: parent
                    spacing: 1
                    Txt { text: modelData[0]; tone: index === 0 ? "priv" : "text2"; font.pixelSize: 11; font.weight: Font.DemiBold }
                    Txt { text: bc.hidden ? "••••" : Units.group(modelData[1] || "0"); num: true; tone: index === 0 ? "priv" : "text"; font.pixelSize: 15; font.weight: Font.DemiBold }
                }
            }
        }
    }
    RowLayout { id: act; Layout.topMargin: 10; spacing: 12 }
}
