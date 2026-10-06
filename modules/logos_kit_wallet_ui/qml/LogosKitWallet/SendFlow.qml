import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt
import "../LogosKitUi/Units.js" as Units

// Send (ux-spec §3; design-lab keypad send): to → amount → review → proof.
// The route (public, shield, unshield, private) follows from the accounts;
// the review is the engine's own decode of what will be signed.
ColumnLayout {
    id: sf
    property var store
    property string step: "to"
    property int dir: 1
    property string to: ""
    property string token: ""
    property string amountText: ""
    property var ticket: null
    property string handle: ""
    property bool busy: false
    property string problem: ""
    readonly property bool first: step === "to" || step === "proof"
    signal finished()

    width: parent ? parent.width : 400
    spacing: 12
    focus: step === "amount"

    readonly property var from: store.current
    readonly property bool fromPrivate: !!from && from.kind === "private"
    // This account's tokens, one row each (own slot and token account added up).
    readonly property var tokens: store.tokenRows(from)
    readonly property var tokenRow: {
        for (var i = 0; i < tokens.length; i++) if (tokens[i].definition === token) return tokens[i]
        return null
    }
    readonly property string balance: {
        if (!from) return ""
        if (token === "") return from.native === null || from.native === undefined ? "" : String(from.native)
        // One transaction sends from one place (the account's own slot or its
        // token account), so the most that can go is the larger of the two.
        var best = "0", hs = tokenRow ? tokenRow.holders : []
        for (var i = 0; i < hs.length; i++) if (Units.cmp(hs[i].amount, best) > 0) best = hs[i].amount
        return best
    }
    // LGO is typed in LGO and sent in lepta; a token uses its decimals
    // (from the list or set by the user), whole units when unknown.
    readonly property int decimals: token === "" ? Units.DECIMALS
        : tokenRow && tokenRow.decimals !== undefined && tokenRow.decimals !== null ? tokenRow.decimals : 0
    readonly property bool tokenUnverified: !!tokenRow && (tokenRow.tier === "unknown" || tokenRow.tier === "spam")
    // What is sent, in base units ("" while there's nothing to send).
    readonly property string base: {
        var b = Units.parse(amountText, decimals)
        return /^0*$/.test(b) ? "" : b
    }
    readonly property string tokenName: tokenRow ? store.tokenLabel(tokenRow) : ""
    readonly property bool tooMuch: base !== "" && balance !== "" && Units.cmp(reservesFee ? Units.add(base, feeCap) : base, balance) > 0
    readonly property bool isCode: to.trim().indexOf("lezpriv1:") === 0
    readonly property bool toFormat: isCode || /^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(to.trim())
    // The engine's read of the recipient (checkRecipient): a code's
    // fingerprint, a token ID pasted by mistake, a lookalike of an address
    // we've paid, or a first-time address.
    property var check: null
    property bool lookalikeOk: false
    readonly property bool checkFits: !!check && check.to === to.trim()
    readonly property bool toBlocked: checkFits && (check.kind === "token" || check.kind === "invalid")
    readonly property bool needsLookalikeOk: checkFits && ((check.kind === "address" && !!check.lookalike) || check.kind === "holder")
    readonly property bool toValid: toFormat && !toBlocked && (!needsLookalikeOk || lookalikeOk)
    onToChanged: { lookalikeOk = false; checkTimer.restart() }
    property Timer checkTimer: Timer {
        interval: 250
        onTriggered: {
            var t = sf.to.trim()
            if (!sf.toFormat) { sf.check = null; return }
            sf.store.call("checkRecipient", { to: t }, function (v, e) {
                if (e || !v || t !== sf.to.trim()) return
                v.to = t
                sf.check = v
            })
        }
    }
    readonly property var toOwn: {
        for (var i = 0; i < store.accounts.length; i++) if (store.accounts[i].accountId === to.trim()) return store.accounts[i]
        return null
    }
    readonly property string toLabel: toOwn ? Fmt.accountName(toOwn) : isCode ? "Private receive code" : Fmt.short(to.trim())
    readonly property string routeWord: {
        var toPriv = isCode || (toOwn && toOwn.kind === "private")
        if (!fromPrivate && !toPriv) return "publicly"
        if (!fromPrivate && toPriv) return "into a private account"
        if (fromPrivate && !toPriv) return "from private to public"
        return "privately"
    }

    function go(s, d) { problem = ""; dir = d || 1; step = s }
    function reset() { step = "to"; to = ""; token = ""; amountText = ""; ticket = null; handle = ""; problem = ""; busy = false; check = null; lookalikeOk = false }

    function key(k) {
        var a = amountText
        if (k === "del") a = a.slice(0, -1)
        else if (k === ".") {
            if (decimals === 0 || a.indexOf(".") >= 0) return
            a = (a === "" ? "0" : a) + "."
        }
        else if (a === "0") a = k
        else a = a + k
        // Past the asset's decimals (or 30 characters): refused, not rounded.
        if (a.length > 30 || (a !== "" && Units.parse(a, decimals) === "")) return
        amountText = a
    }
    // A public LGO send pays its fee from the same balance, and the
    // transaction reserves the whole fee cap up front; private sends and
    // tokens don't.
    readonly property string feeCap: store.state.feeCap || "0"
    readonly property bool reservesFee: token === "" && !fromPrivate
    // Max: everything that can go, as the field shows it (LGO for native).
    function useMax() {
        amountText = Units.plain(reservesFee ? Units.sub(balance, feeCap) : balance, decimals)
    }
    Keys.onPressed: function (e) {
        if (step !== "amount") return
        if (e.text >= "0" && e.text <= "9" && e.text.length === 1) { key(e.text); e.accepted = true }
        else if (e.text === ".") { key("."); e.accepted = true }
        else if (e.key === Qt.Key_Backspace) { key("del"); e.accepted = true }
        else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && reviewBtn.enabled) { reviewBtn.clicked(); e.accepted = true }
    }

    function back() {
        if (step === "amount") go("to", -1)
        else if (step === "review") {
            if (ticket) store.call("reject", { handle: ticket.handle }, null)
            ticket = null
            go("amount", -1)
        }
    }

    function prepare() {
        busy = true
        problem = ""
        var p = { kind: "transfer", from: from.accountId, amount: base }
        if (isCode) p.toCode = to.trim(); else p.to = to.trim()
        if (token !== "") p.token = token
        store.call("prepareSend", p, function (v, e) {
            sf.busy = false
            if (e) { sf.problem = Fmt.errorText(e); return }
            sf.ticket = v
            sf.go("review")
        }, 20000)
    }

    function approve(password, ack) {
        busy = true
        problem = ""
        store.call("approve", { handle: ticket.handle, requestHash: ticket.request.requestHash, password: password || null, acknowledged: ack }, function (v, e) {
            sf.busy = false
            if (e) { sf.problem = Fmt.errorText(e); return }
            sf.handle = sf.ticket.handle
            sf.store.watching = sf.handle
            sf.ticket = null
            sf.store.refreshAll()
            sf.go("proof")
        }, 20000)
    }

    // -- to ---------------------------------------------------------------------------
    ColumnLayout {
        visible: sf.step === "to"
        Layout.fillWidth: true
        spacing: 10
        Txt { text: "Send"; font.pixelSize: 20; font.weight: Font.DemiBold }
        Txt {
            Layout.fillWidth: true
            text: sf.from ? "From " + Fmt.accountName(sf.from) + " · " + Fmt.lgo(sf.from.native) : ""
            tone: "text2"; font.pixelSize: 13
        }
        Field {
            id: toField
            objectName: "sendTo"
            Layout.fillWidth: true
            mono: true
            placeholderText: "Account address or private receive code"
            text: sf.to
            onTextChanged: sf.to = text
            invalid: text.trim() !== "" && (!sf.toFormat || sf.toBlocked)
        }
        Txt {
            objectName: "sendCodeFingerprint"
            Layout.fillWidth: true
            visible: sf.isCode && sf.checkFits && sf.check.kind === "code"
            text: sf.checkFits && sf.check.fingerprint ? "Code ends " + sf.check.fingerprint + ". Check it matches the receiver's screen. Only you and the recipient will see this payment." : ""
            tone: "priv"; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        Notice {
            objectName: "sendToProblem"
            Layout.fillWidth: true
            visible: sf.toBlocked
            tone: "danger"
            text: sf.toBlocked ? sf.check.message : ""
        }
        Notice {
            objectName: "sendLookalike"
            Layout.fillWidth: true
            visible: sf.needsLookalikeOk
            tone: "warn"
            text: !sf.needsLookalikeOk ? "" : sf.check.kind === "holder" ? sf.check.message
                  : "This looks like " + Fmt.short(sf.check.lookalike) + ", which you've sent to before, but it's a different address. Scammers send tiny payments from lookalike addresses so you copy the wrong one."
        }
        CheckRow {
            objectName: "sendLookalikeOk"
            controlled: true
            Layout.fillWidth: true
            visible: sf.needsLookalikeOk
            text: sf.checkFits && sf.check.kind === "holder" ? "I'm sure this is their wallet address" : "I checked every character of the address"
            checked: sf.lookalikeOk
            onToggled: function (c) { sf.lookalikeOk = c }
        }
        Txt {
            Layout.fillWidth: true
            visible: sf.checkFits && sf.check.kind === "address" && sf.check.firstTime && !sf.needsLookalikeOk
            text: "First time sending to this address."
            tone: "text3"; font.pixelSize: 12
        }
        Txt { text: "Or one of your accounts"; tone: "text2"; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.topMargin: 6 }
        Repeater {
            model: sf.store.userAccounts
            AccountCard {
                visible: !sf.from || modelData.accountId !== sf.from.accountId
                multi: false
                accountId: modelData.accountId
                name: Fmt.accountName(modelData)
                kind: modelData.kind
                balance: modelData.native === null || modelData.native === undefined ? "" : String(modelData.native)
                checked: sf.to === modelData.accountId
                onToggled: toField.text = modelData.accountId
            }
        }
        // Asset: native, or a token this account holds.
        ColumnLayout {
            visible: !!sf.from && sf.tokens.length > 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 6
            Txt { text: "Asset"; tone: "text2"; font.pixelSize: 12; font.weight: Font.DemiBold }
            SegmentedControl {
                // Listed and added tokens first; unverified ones say so.
                readonly property var assets: [{ definition: "", name: Units.SYMBOL }].concat(
                    sf.tokens.filter(function (t) { return t.tier === "verified" || t.tier === "added" }),
                    sf.tokens.filter(function (t) { return t.tier === "unknown" || t.tier === "spam" }))
                options: assets.map(function (t) {
                    var label = t.definition === "" ? t.name : sf.store.tokenLabel(t)
                    return t.tier === "unknown" || t.tier === "spam" ? label + " (unverified)" : label
                })
                currentIndex: {
                    for (var i = 0; i < assets.length; i++) if (assets[i].definition === sf.token) return i
                    return 0
                }
                onActivated: function (i) { sf.token = assets[i].definition }
            }
        }
        Btn { objectName: "sendNext"; Layout.fillWidth: true; large: true; tone: "ink"; text: "Continue"; enabled: sf.toValid; onClicked: sf.go("amount") }
    }

    // -- amount (keypad) -----------------------------------------------------------------
    ColumnLayout {
        visible: sf.step === "amount"
        Layout.fillWidth: true
        spacing: 8
        Txt { text: "Send " + sf.routeWord; font.pixelSize: 20; font.weight: Font.DemiBold }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            radius: Theme.rRow
            color: Theme.surface2
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8
                Txt { text: "To"; tone: "text2"; font.pixelSize: 13 }
                Txt { Layout.fillWidth: true; text: sf.toLabel; font.weight: Font.DemiBold; font.pixelSize: 13 }
                Badge { visible: sf.routeWord !== "publicly"; text: "Private"; tone: "private"; dot: false }
            }
        }
        AmountField {
            id: amtField
            objectName: "sendAmount"
            Layout.fillWidth: true
            Layout.topMargin: 6
            symbol: sf.token === "" ? Units.SYMBOL : (sf.tokenName || "tokens")
            decimals: sf.decimals
            tokenSelectable: false
            tokenIcon: Component { TokenIcon { size: 24; definition: sf.token; source: sf.store.tokenLogo(sf.tokenRow); label: sf.tokenName; warn: sf.tokenUnverified; isPrivate: sf.fromPrivate } }
            balance: sf.balance
            text: sf.amountText
            onTextChanged: if (text !== sf.amountText) sf.amountText = text
            onMaxClicked: sf.useMax()
            onSubmitted: if (reviewBtn.enabled) reviewBtn.clicked()
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 4
            columnSpacing: 4
            Repeater {
                // A decimal point for LGO; Max (also under the figure) for a token.
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", sf.decimals > 0 ? "." : "max", "0", "del"]
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: Theme.rRow
                    color: km.pressed ? Theme.surface2 : "transparent"
                    scale: km.pressed ? 0.92 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.dPress } }
                    Txt { visible: modelData !== "del"; anchors.centerIn: parent; text: modelData === "max" ? "Max" : modelData; font.pixelSize: modelData === "max" ? 14 : 20; font.weight: Font.Medium; tone: modelData === "max" ? "action" : "text" }
                    Glyph { visible: modelData === "del"; anchors.centerIn: parent; name: "backspace"; width: 20; height: 20; color: Theme.text }
                    MouseArea {
                        id: km
                        anchors.fill: parent
                        onClicked: modelData === "max" ? sf.useMax() : sf.key(modelData)
                    }
                }
            }
        }
        Txt {
            objectName: "sendFeeNote"
            Layout.fillWidth: true
            visible: sf.reservesFee && sf.feeCap !== "0"
            text: sf.tooMuch && sf.base !== "" && Units.cmp(sf.base, sf.balance) <= 0
                ? "That leaves too little for the fee. Keep at least " + Units.lgoLabel(sf.feeCap) + "."
                : "Max leaves up to " + Units.lgoLabel(sf.feeCap) + " for the fee. You keep whatever isn't used."
            tone: sf.tooMuch && sf.base !== "" ? "warn" : "text3"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        Notice {
            objectName: "sendUnverifiedToken"
            visible: sf.tokenUnverified
            Layout.fillWidth: true
            tone: "warn"
            text: "You're sending a token that isn't on the Logos Kit list."
        }
        Txt {
            visible: !!sf.tokenRow && (sf.tokenRow.decimals === undefined || sf.tokenRow.decimals === null)
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            tone: "text3"; font.pixelSize: 12
            text: "This token's decimals are unknown, so amounts are whole units."
        }
        Btn { id: reviewBtn; objectName: "sendReview"; Layout.fillWidth: true; large: true; tone: "ink"; text: "Review"; busy: sf.busy; enabled: sf.base !== "" && !sf.tooMuch; onClicked: sf.prepare() }
    }

    // -- review ------------------------------------------------------------------------------
    ApprovalView {
        visible: sf.step === "review"
        Layout.fillWidth: true
        store: sf.store
        ticket: sf.ticket
        busy: sf.busy
        problem: sf.step === "review" ? sf.problem : ""
        onApprove: function (password, ack) { sf.approve(password, ack) }
        onReject: sf.back()
    }

    // -- proof -------------------------------------------------------------------------------
    ProofView {
        visible: sf.step === "proof"
        Layout.fillWidth: true
        store: sf.store
        handle: sf.handle
        onClose: sf.finished()
    }

    Notice { visible: sf.problem !== "" && sf.step !== "review"; objectName: "sendProblem"; Layout.fillWidth: true; text: sf.problem; tone: "danger" }
}
