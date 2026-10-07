import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt
import "../LogosKitUi/Units.js" as Units

// Create a test token (docs/design/ux-tokens-nfts.md §2.6): name, supply,
// decimals (kept in this wallet; LEZ stores none), and the public account
// that receives the whole supply. Then the same review and result screens as
// Send. Afterwards the token is added and pinned, and its ID is labelled and
// kept out of the account switcher.
ColumnLayout {
    id: ct
    property var store
    property string step: "form"
    property var ticket: null
    property string handle: ""
    property string definition: ""
    property bool busy: false
    property string problem: ""
    property string holder: ""
    readonly property bool first: step === "form" || step === "proof"
    signal finished(string definition)

    width: parent ? parent.width : 400
    spacing: 12

    // A token's whole supply lands in the holder's own token slot, which
    // holds one token: offer public accounts whose slot is free.
    readonly property var holders: store.userAccounts.filter(function (a) {
        if (a.kind !== "public") return false
        var ts = a.tokens || []
        for (var i = 0; i < ts.length; i++) if (ts[i].via === "account") return false
        return true
    })
    readonly property bool nameOk: nameIn.text.trim() !== "" && utf8Len(nameIn.text.trim()) <= 32
    readonly property string decimalsText: decimalsIn.text.trim()
    readonly property bool decimalsOk: decimalsText === "" || (/^[0-9]{1,2}$/.test(decimalsText) && parseInt(decimalsText) <= 36)
    readonly property int decimals: decimalsText === "" ? 0 : parseInt(decimalsText)
    readonly property string supplyBase: Units.parse(supplyIn.text.trim(), decimalsOk ? decimals : 0)
    readonly property bool supplyOk: supplyBase !== "" && !/^0*$/.test(supplyBase)
    readonly property bool canNext: nameOk && supplyOk && decimalsOk && holder !== "" && !busy

    function utf8Len(s) { return unescape(encodeURIComponent(s)).length }
    function reset() { step = "form"; ticket = null; handle = ""; definition = ""; problem = ""; busy = false; nameIn.text = ""; supplyIn.text = ""; decimalsIn.text = ""; holder = "" }
    function back() {
        if (step === "review") {
            if (ticket) store.call("reject", { handle: ticket.handle }, null)
            ticket = null
            step = "form"
        }
    }
    function prepare() {
        busy = true; problem = ""
        store.call("createToken", { holder: holder, name: nameIn.text.trim(), supply: supplyBase }, function (v, e) {
            ct.busy = false
            if (e) { ct.problem = Fmt.errorText(e); return }
            ct.ticket = v
            ct.definition = v.definition
            ct.step = "review"
        }, 30000)
    }
    function approve(password, ack) {
        busy = true; problem = ""
        store.call("approve", { handle: ticket.handle, requestHash: ticket.request.requestHash, password: password || null, acknowledged: ack }, function (v, e) {
            ct.busy = false
            if (e) { ct.problem = Fmt.errorText(e); return }
            ct.handle = ct.ticket.handle
            ct.ticket = null
            // Added and pinned now; decimals kept in this wallet.
            var p = { definition: ct.definition }
            if (ct.decimals > 0) p.decimals = ct.decimals
            ct.store.call("addToken", p, function () {
                ct.store.call("setTokenPinned", { definition: ct.definition, on: true }, function () { ct.store.refreshAll() })
            })
            ct.step = "proof"
        }, 20000)
    }

    // -- form ------------------------------------------------------------------------------
    ColumnLayout {
        visible: ct.step === "form"
        Layout.fillWidth: true
        spacing: 10
        Txt { text: "Create a test token"; font.pixelSize: 20; font.weight: Font.Bold }
        Txt { Layout.fillWidth: true; wrapMode: Text.Wrap; tone: "text2"; font.pixelSize: 13; text: "A token on the LEZ testnet with your name and supply. Its name can't be changed later." }
        Field { id: nameIn; objectName: "createName"; Layout.fillWidth: true; placeholderText: "Name, e.g. Logos Club Points"; invalid: nameIn.text !== "" && !ct.nameOk }
        Txt { text: ct.utf8Len(nameIn.text.trim()) + " / 32"; tone: ct.nameOk || nameIn.text === "" ? "text3" : "danger"; font.pixelSize: 11; Layout.alignment: Qt.AlignRight }
        Field { id: supplyIn; objectName: "createSupply"; Layout.fillWidth: true; placeholderText: "Supply, e.g. 1000000"; invalid: supplyIn.text !== "" && !ct.supplyOk }
        Field { id: decimalsIn; objectName: "createDecimals"; Layout.fillWidth: true; placeholderText: "Decimals (optional, 0–36)"; invalid: !ct.decimalsOk }
        Txt {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            tone: "text3"; font.pixelSize: 12
            text: "Decimals aren't stored on chain: this wallet remembers them, and people you send it to set them when they add it."
                  + (ct.supplyOk && ct.decimals > 0 ? " The chain stores " + Units.group(ct.supplyBase) + " units." : "")
        }
        Txt { text: "Who receives the supply"; tone: "text2"; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.topMargin: 4 }
        Repeater {
            model: ct.holders
            AccountCard {
                multi: false
                accountId: modelData.accountId
                name: Fmt.accountName(modelData)
                kind: modelData.kind
                balance: modelData.native === null || modelData.native === undefined ? "" : String(modelData.native)
                checked: ct.holder === modelData.accountId
                onToggled: ct.holder = modelData.accountId
            }
        }
        Notice {
            visible: ct.holders.length === 0
            Layout.fillWidth: true
            tone: "info"
            text: "Each of your public accounts already holds a token in its own slot, and a slot holds one token. Add a public account first."
        }
        Btn { objectName: "createNext"; Layout.fillWidth: true; large: true; tone: "ink"; text: "Review"; busy: ct.busy; enabled: ct.canNext; onClicked: ct.prepare() }
    }

    // -- review ---------------------------------------------------------------------------------
    ApprovalView {
        visible: ct.step === "review"
        Layout.fillWidth: true
        store: ct.store
        ticket: ct.ticket
        busy: ct.busy
        problem: ct.step === "review" ? ct.problem : ""
        onApprove: function (password, ack) { ct.approve(password, ack) }
        onReject: ct.back()
    }

    // -- result ----------------------------------------------------------------------------------
    ProofView {
        visible: ct.step === "proof"
        Layout.fillWidth: true
        store: ct.store
        handle: ct.handle
        onClose: { var d = ct.definition; ct.reset(); ct.finished(d) }
    }

    Notice { visible: ct.problem !== "" && ct.step === "form"; Layout.fillWidth: true; text: ct.problem; tone: "danger" }
}
