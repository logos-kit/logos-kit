import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt

// Unknown, spam and hidden tokens (docs/design/ux-tokens-nfts.md §2.2). Unknown
// and spam rows never show the token's own image (decision D6) and use the
// warning tone; spam rows say why. Opening one goes to its details, where
// it can be added, hidden or shown; nothing here makes a token trusted.
ColumnLayout {
    id: tm
    property var store
    property int tab: 0
    signal openToken(string definition)

    width: parent ? parent.width : 400
    spacing: 12

    readonly property var rows: store.tokenRows(store.current)
    readonly property var unknown: rows.filter(function (t) { return t.tier === "unknown" })
    readonly property var spam: rows.filter(function (t) { return t.tier === "spam" })
    readonly property var hidden: rows.filter(function (t) { return t.tier === "hidden" })
    readonly property var shown: tab === 0 ? unknown : tab === 1 ? spam : hidden

    Txt { text: "Hidden and unknown"; font.pixelSize: 20; font.weight: Font.Bold }
    Txt {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        tone: "text2"; font.pixelSize: 13
        text: "Anyone can send you a token. These aren't on the Logos Kit list, and they don't count in your total."
    }
    SegmentedControl {
        objectName: "tokensMoreTabs"
        Layout.fillWidth: true
        options: ["Unknown (" + tm.unknown.length + ")", "Spam (" + tm.spam.length + ")", "Hidden (" + tm.hidden.length + ")"]
        currentIndex: tm.tab
        onActivated: function (i) { tm.tab = i }
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: -12
        Layout.rightMargin: -12
        spacing: 0
        Repeater {
            model: tm.shown
            TokenRow {
                objectName: "moreRow_" + modelData.definition
                name: modelData.name || Fmt.short(modelData.definition)
                symbol: modelData.symbol || ""
                definition: modelData.definition
                warn: modelData.tier !== "hidden"
                chip: modelData.tier === "spam" ? "Spam" : modelData.tier === "unknown" ? "Unverified" : ""
                sub: modelData.tier === "spam" && modelData.spamReason ? modelData.spamReason : Fmt.short(modelData.definition)
                amount: tm.store.tokenAmount(modelData)
                chevron: true
                onClicked: tm.openToken(modelData.definition)
            }
        }
    }
    EmptyState {
        visible: tm.shown.length === 0
        Layout.fillWidth: true
        glyph: "inbox"
        title: "Nothing here"
        body: tm.tab === 0 ? "Tokens someone sends you that aren't on the list show up here."
            : tm.tab === 1 ? "Tokens whose names look like scams are hidden here automatically."
            : "Tokens you hide show up here. Hiding never deletes anything."
    }
}
