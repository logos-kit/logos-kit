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
    property string value: "0"         // base units: lepta for LGO
    property string symbol: "LGO"
    property int decimals: Units.DECIMALS   // LGO's 9; a token's own (0 if none)
    property string privateLine: ""
    // Private buckets as three figures (base units; empty hides the row).
    property string privSpendable: ""
    property string privPending: ""
    property string privLocked: ""
    property bool hidden: false
    property bool loading: false
    property string tickerName: ""     // objectName for the figure (tests read its `text`)
    property string note: ""           // one line under the figure
    default property alias actions: act.data
    signal hideToggled(bool hidden)
    spacing: 8

    // The figure, Fuse-style (Refero: Fuse wallet home): the whole part in
    // ink, the decimals and the unit quieter, so "20.25 LGO" reads as 20.
    readonly property string full: Units.token(bc.value, bc.decimals)
    readonly property int dot: full.indexOf(".")
    readonly property string whole: dot < 0 ? full : full.substring(0, dot)
    readonly property string frac: dot < 0 ? "" : full.substring(dot)
    // As large as Fuse's figure, shrinking so long amounts (9 decimals) fit.
    readonly property int chars: full.length + bc.symbol.length + 2
    readonly property int figure: Math.max(30, Math.min(bc.width < 380 ? 48 : 64, Math.floor(bc.width / (chars * 0.6))))

    RowLayout {
        spacing: 6
        Txt { text: bc.label; tone: "text2"; font.pixelSize: 14; font.weight: Font.Medium }
        IconButton { glyph: bc.hidden ? "eyeOff" : "eye"; size: 28; color: Theme.text3; label: bc.hidden ? "Show balance" : "Hide balance"; onClicked: { bc.hidden = !bc.hidden; bc.hideToggled(bc.hidden) } }
    }
    Item {
        Layout.fillWidth: true
        implicitHeight: bc.figure + 8
        Skeleton { visible: bc.loading; width: 220; height: bc.figure - 8; radius: 14; anchors.verticalCenter: parent.verticalCenter }
        RowLayout {
            visible: !bc.loading
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            NumberTicker { objectName: bc.tickerName; value: bc.whole; masked: bc.hidden; pixelSize: bc.figure; weight: Font.Bold }
            Txt { visible: !bc.hidden && bc.frac !== ""; text: bc.frac; tone: "text3"; num: true; font.pixelSize: bc.figure; font.weight: Font.Bold; Layout.alignment: Qt.AlignBaseline }
            Txt { text: " " + bc.symbol; tone: "text3"; font.pixelSize: Math.round(bc.figure * 0.42); font.weight: Font.DemiBold; Layout.alignment: Qt.AlignBaseline; Layout.leftMargin: 6 }
        }
    }
    Txt {
        visible: bc.note !== ""
        text: bc.note
        tone: "text2"
        font.pixelSize: 13
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        Layout.fillWidth: true
    }
    RowLayout {
        visible: bc.privateLine !== ""
        spacing: 6
        Glyph { name: "lock"; color: Theme.privText; width: 13; height: 13 }
        Txt { text: bc.hidden ? "Private ••••" : bc.privateLine; tone: "priv"; num: true; font.pixelSize: 13 }
    }
    // Private funds in three states, as one line (spendable · arriving · in a proof).
    RowLayout {
        visible: bc.privSpendable !== ""
        spacing: 6
        Glyph { name: "lock"; color: Theme.text3; width: 13; height: 13 }
        Txt {
            num: true
            tone: "text2"
            font.pixelSize: 13
            text: bc.hidden ? "Private · ••••"
                : "Spendable " + Units.token(bc.privSpendable || "0", bc.decimals)
                  + (bc.privPending !== "" && bc.privPending !== "0" ? " · arriving " + Units.token(bc.privPending, bc.decimals) : "")
                  + (bc.privLocked !== "" && bc.privLocked !== "0" ? " · in a proof " + Units.token(bc.privLocked, bc.decimals) : "")
        }
    }
    RowLayout { id: act; Layout.fillWidth: true; Layout.topMargin: 14; spacing: 10 }
}
