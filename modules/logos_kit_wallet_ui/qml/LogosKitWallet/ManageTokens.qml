import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt

// Manage tokens (docs/design/ux-tokens-nfts.md §2.3; layout: Phantom's
// "Manage token list" with Family's dimmed hidden rows, lp0001-screens.md §2).
// Search by name, symbol or Token ID; a visibility toggle and a pin per
// token; changes apply at once. A Token ID nobody listed opens the add tray.
ColumnLayout {
    id: mt
    property var store
    property string query: ""
    signal addToken(string prefill)
    signal createToken()
    signal openToken(string definition)

    width: parent ? parent.width : 400
    spacing: 12

    readonly property var rows: store.tokenRows(store.current).filter(function (t) {
        var q = mt.query.trim().toLowerCase()
        return q === "" || (t.name || "").toLowerCase().indexOf(q) >= 0 || (t.symbol || "").toLowerCase().indexOf(q) >= 0 || t.definition.toLowerCase() === q
    })
    readonly property bool looksLikeId: /^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(query.trim())
    function section(tier) { return rows.filter(function (t) { return t.tier === tier }) }

    function set(method, def, on) {
        store.call(method, { definition: def, on: on }, function (v, e) {
            if (e) store.toast(Fmt.errorText(e), "danger")
            else store.refreshAll()
        })
    }

    Txt { text: "Manage tokens"; font.pixelSize: 20; font.weight: Font.Bold }
    Field {
        objectName: "manageSearch"
        Layout.fillWidth: true
        placeholderText: "Search name, symbol or Token ID"
        text: mt.query
        onTextChanged: mt.query = text
    }
    Btn {
        objectName: "manageLookUp"
        visible: mt.looksLikeId && mt.rows.length === 0
        Layout.fillWidth: true
        text: "Look up this Token ID"
        onClicked: mt.addToken(mt.query.trim())
    }

    Repeater {
        model: [["verified", "On the Logos Kit list"], ["added", "Added by you"], ["unknown", "Unknown"], ["spam", "Hidden as spam"], ["hidden", "Hidden by you"]]
        ColumnLayout {
            readonly property var items: mt.section(modelData[0])
            visible: items.length > 0
            Layout.fillWidth: true
            spacing: 0
            SectionTitle { text: modelData[1]; Layout.topMargin: 6 }
            Repeater {
                model: parent.items
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    opacity: modelData.tier === "hidden" || modelData.tier === "spam" ? 0.6 : 1
                    TokenRow {
                        Layout.fillWidth: true
                        Layout.leftMargin: -12
                        name: modelData.name || Fmt.short(modelData.definition)
                        symbol: modelData.symbol || ""
                        definition: modelData.definition
                        iconSource: mt.store.tokenLogo(modelData)
                        verified: modelData.tier === "verified"
                        warn: modelData.tier === "unknown" || modelData.tier === "spam"
                        sub: modelData.tier === "spam" && modelData.spamReason ? modelData.spamReason : Fmt.short(modelData.definition)
                        amount: mt.store.tokenAmount(modelData)
                        onClicked: mt.openToken(modelData.definition)
                    }
                    IconButton {
                        objectName: "managePin_" + modelData.definition
                        visible: modelData.tier === "verified" || modelData.tier === "added"
                        glyph: "chevronUp"
                        color: modelData.pinned ? Theme.action : Theme.text3
                        label: modelData.pinned ? "Unpin" : "Pin to the top"
                        onClicked: mt.set("setTokenPinned", modelData.definition, !modelData.pinned)
                    }
                    Toggle {
                        objectName: "manageShow_" + modelData.definition
                        checked: modelData.tier !== "hidden" && modelData.tier !== "spam" && modelData.tier !== "unknown"
                        onToggled: function (on) {
                            // Showing an unknown or spam token adds it; it never becomes Verified.
                            if (on && (modelData.tier === "unknown" || modelData.tier === "spam")) {
                                mt.store.call("addToken", { definition: modelData.definition }, function () { mt.store.refreshAll() })
                                mt.store.toast("Showing this token doesn't mean it's safe.", "info")
                            } else mt.set("setTokenHidden", modelData.definition, !on)
                        }
                    }
                }
            }
        }
    }
    EmptyState {
        visible: mt.rows.length === 0 && !mt.looksLikeId
        Layout.fillWidth: true
        glyph: "search"
        title: mt.query === "" ? "No tokens yet" : "No match"
        body: mt.query === "" ? "Tokens you receive show up here. Add one by its ID below." : "Try another name, or paste the Token ID."
    }

    Btn { objectName: "manageAdd"; Layout.fillWidth: true; Layout.topMargin: 8; large: true; tone: "ink"; icon: "plus"; text: "Add a token"; onClicked: mt.addToken("") }
    Btn { objectName: "manageCreate"; Layout.fillWidth: true; text: "Create a test token"; onClicked: mt.createToken() }
}
