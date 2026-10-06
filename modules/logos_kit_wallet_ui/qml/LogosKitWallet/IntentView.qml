import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt

// What an app asked for through a Basecamp intent (ux-spec §5, §6, §8):
// connect, transaction, message signature, sign-in, test funds. The
// requester name is the shell-attested one. Every path answers the intent
// exactly once (Store.answer); a closed sheet answers `cancelled`.
ColumnLayout {
    id: iv
    property var store
    property var req: store.intent
    property var ticket: null        // lez.transaction.send
    property string handle: ""       // after approval
    property bool busy: false
    property string problem: ""
    property bool blocked: false     // can't be served; only Close
    property var picked: []          // connect: account ids
    property bool privConsent: false
    property string job: ""          // request_funds
    property var fundResult: null
    property var grants: []
    signal finished()

    width: parent ? parent.width : 400
    spacing: 10

    // The request on screen: an answered one (req → null) stays until the
    // sheet closes, so its result (faucet outcome, proof) keeps its Done.
    property var shown: null
    readonly property var cur: req || shown
    // An answered request still on screen (its result, its Done) holds the
    // sheet: the Store refuses new ones until it closes.
    Binding { target: iv.store; property: "sheetBusy"; value: iv.visible && iv.req === null && iv.shown !== null }
    onFinished: shown = null
    readonly property string kind: cur ? cur.intent : ""
    readonly property var p: cur ? cur.params || ({}) : ({})
    readonly property string requester: cur ? cur.requester : ""
    readonly property var publicAccounts: store.accounts.filter(function (a) { return a.kind === "public" })
    readonly property var privateAccounts: store.accounts.filter(function (a) { return a.kind === "private" })
    readonly property bool wantsPrivate: (p.accountKinds || []).indexOf("private") >= 0
    readonly property bool pickedPrivate: {
        for (var i = 0; i < picked.length; i++)
            for (var j = 0; j < privateAccounts.length; j++)
                if (privateAccounts[j].accountId === picked[i]) return true
        return false
    }

    function cancel() {
        if (ticket) store.call("reject", { handle: ticket.handle }, null)
        store.answer(false, {}, "cancelled")
        finished()
    }
    function fail(e, code) {
        busy = false
        problem = Fmt.errorText(e)
        blocked = true
        failCode = code || "failed"
    }
    property string failCode: "failed"
    function closeBlocked() { store.answer(false, {}, failCode); finished() }

    function start() {
        // An answered request (req → null) keeps its proof on screen.
        if (!req) return
        shown = req
        ticket = null; handle = ""; busy = false; problem = ""; blocked = false
        picked = []; privConsent = false; job = ""; fundResult = null
        // Read the request itself: sibling bindings (kind, p, requester) may
        // not have re-evaluated yet when this handler runs.
        var kind = req.intent, p = req.params || ({}), requester = req.requester || ""
        if (kind === "lez.wallet.connect" || kind === "lez.wallet.sign_in") {
            var chains = p.chains || [store.zone.chain]
            if (kind === "lez.wallet.connect" && chains.indexOf(store.zone.chain) < 0) {
                fail({ code: 4902, message: "the app wants " + chains.join(", ") + ", but the wallet is on " + store.zone.chain }, "bad_request")
                return
            }
            if (publicAccounts.length > 0) picked = [publicAccounts[0].accountId]
            store.call("grants", {}, function (v) { iv.grants = v || [] })
        } else if (kind === "lez.transaction.send") {
            busy = true
            store.call("requestTx", { requester: requester, proposal: p }, function (v, e) {
                iv.busy = false
                if (e) { iv.fail(e, e.code === -32602 || e.code === 6104 || e.code === 5740 || e.code === 4902 ? "bad_request" : "failed"); return }
                iv.ticket = v
            }, 20000)
        } else if (kind === "lez.message.sign") {
            var mine = publicAccounts.some(function (a) { return a.accountId === p.account })
            if (!mine) fail({ code: 6100, message: "only this wallet's public accounts sign messages" }, "bad_request")
        } else if (kind === "lez.wallet.request_funds") {
            if (p.chain && p.chain !== store.zone.chain) fail({ code: 4902, message: "the app wants " + p.chain }, "bad_request")
            else if (!store.state.faucet) fail({ code: 6109, message: "" })
        } else if (kind === "lez.wallet.open") {
            store.answer(true, {}, "")
            finished()
        } else {
            fail({ code: 4200, message: "this wallet doesn't handle " + kind }, "bad_request")
        }
    }
    onReqChanged: start()

    function toggle(id) {
        var out = picked.slice()
        var at = out.indexOf(id)
        if (at >= 0) out.splice(at, 1); else out.push(id)
        picked = out
    }

    function decodeMessage(b64) {
        try {
            var bin = Qt.atob(b64)
            var txt = decodeURIComponent(escape(bin))
            if (/^[\x20-\x7E -￿\n\r\t]*$/.test(txt)) return txt
            var hex = ""
            for (var i = 0; i < bin.length && i < 256; i++) hex += ("0" + bin.charCodeAt(i).toString(16)).slice(-2)
            return "0x" + hex + (bin.length > 256 ? "…" : "")
        } catch (e) { return "(unreadable message)" }
    }

    // -- connect ---------------------------------------------------------------------
    function connect(password) {
        busy = true
        problem = ""
        var caps = ["accounts", "read_public", "propose_tx"]
        if (pickedPrivate) caps.push("read_private")
        if ((p.capabilities || []).indexOf("sign_message") >= 0) caps.push("sign_message")
        store.call("requestConnect", { requester: requester, accounts: picked, capabilities: caps }, function (t, e) {
            if (e) { iv.busy = false; iv.problem = Fmt.errorText(e); return }
            store.call("approve", { handle: t.handle, requestHash: t.request.requestHash, password: password }, function (v, e2) {
                if (e2) {
                    iv.busy = false
                    iv.problem = Fmt.errorText(e2)
                    // Each attempt opens a fresh connect request: drop this one.
                    store.call("reject", { handle: t.handle }, null)
                    return
                }
                store.call("sessionFor", { requester: requester }, function (session, e3) {
                    if (e3 || !session) { iv.busy = false; iv.problem = Fmt.errorText(e3 || { message: "connected, but the session is missing" }); return }
                    if (!p.signIn) { iv.busy = false; store.answer(true, session, ""); iv.finished(); return }
                    var acct = null
                    for (var i = 0; i < picked.length; i++)
                        for (var j = 0; j < publicAccounts.length; j++)
                            if (publicAccounts[j].accountId === picked[i]) { acct = picked[i]; break }
                    if (!acct) { iv.busy = false; store.answer(true, session, ""); iv.finished(); return }
                    // Connect answers without the sign-in when the user didn't
                    // confirm the site (Basecamp can't bind a site to an app).
                    if (!connectSiteAck.checked) { iv.busy = false; store.answer(true, session, ""); iv.finished(); return }
                    store.call("signIn", { requester: requester, account: acct, request: p.signIn, acknowledged: true }, function (si, e4) {
                        iv.busy = false
                        if (!e4) session.signIn = si
                        store.answer(true, session, "")
                        iv.finished()
                    })
                })
            }, 20000)
        }, 20000)
    }

    // -- transaction -----------------------------------------------------------------
    function approveTx(password, ack) {
        busy = true
        problem = ""
        store.call("approve", { handle: ticket.handle, requestHash: ticket.request.requestHash, password: password || null, acknowledged: ack }, function (v, e) {
            iv.busy = false
            if (e) { iv.problem = Fmt.errorText(e); return }
            iv.handle = iv.ticket.handle
            var out = { handle: iv.handle }
            if (v && v.status && v.status.txHash) out.txHash = v.status.txHash
            store.watching = iv.handle
            iv.ticket = null
            store.answer(true, out, "")
            store.refreshAll()
        }, 20000)
    }

    // -- funds -------------------------------------------------------------------------
    property Timer fundPoll: Timer {
        interval: 1500
        repeat: true
        running: iv.job !== "" && iv.fundResult === null
        onTriggered: iv.store.call("fundStatus", { job: iv.job }, function (v, e) {
            if (e || !v || v.state === "running") return
            iv.fundResult = v
            iv.busy = false
            if (v.state === "error") { iv.problem = Fmt.errorText(v.error); iv.store.answer(false, {}, "failed"); return }
            var r = v.result, out = { status: r.status }
            if (r.amount) out.amount = r.amount
            if (r.txHash) out.txHash = r.txHash
            if (r.retryAfterSeconds !== undefined) out.retryAfterSeconds = r.retryAfterSeconds
            if (r.reason) out.reason = r.reason
            if (r.shield) out.shieldHandle = r.shield.handle
            // A private target was funded through this public account.
            if (r.fundedAccount && r.fundedAccount !== iv.p.account) out.fundedAccount = r.fundedAccount
            iv.store.answer(true, out, "")
            iv.store.refreshAll()
        })
    }

    Notice {
        objectName: "intentQueued"
        visible: !!iv.store.queued && iv.req === null
        Layout.fillWidth: true
        text: (iv.store.queued ? iv.store.appName(iv.store.queued.requester) : "") + " is waiting with another request. Close this to see it."
    }

    // == header (all kinds) ================================================================
    RowLayout {
        // Transactions show the requester inside the approval sheet itself.
        visible: !!iv.cur && iv.requester !== "" && !iv.handle && iv.kind !== "lez.transaction.send"
        Layout.fillWidth: true
        spacing: 12
        AppAvatar { store: iv.store; requester: iv.requester; size: 52 }
        Row {
            spacing: 4
            Layout.alignment: Qt.AlignVCenter
            Repeater { model: 3; Rectangle { width: 6; height: 6; radius: 3; color: Theme.text3 } }
        }
        Rectangle { implicitWidth: 52; implicitHeight: 52; radius: 16; color: "#000000"; LogosMark { anchors.centerIn: parent; size: 26 } }
        Item { Layout.fillWidth: true }
    }
    Txt {
        visible: !!iv.cur && (iv.kind !== "lez.transaction.send" || iv.blocked)
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        font.pixelSize: 20
        font.weight: Font.DemiBold
        text: iv.kind === "lez.wallet.connect" ? iv.store.appName(iv.requester) + " wants to connect"
            : iv.kind === "lez.message.sign" ? iv.store.appName(iv.requester) + " asks you to sign a message"
            : iv.kind === "lez.wallet.sign_in" ? "Sign in to " + (iv.p.domain || iv.requester)
            : iv.kind === "lez.wallet.request_funds" ? "Get test funds"
            : iv.kind === "lez.transaction.send" ? "Can't review this request"
            : "Request"
    }
    Txt {
        visible: iv.requester !== "" && iv.kind !== "lez.transaction.send"
        Layout.fillWidth: true
        text: "Module " + iv.requester + " · name checked by Basecamp"
        mono: true; tone: "text3"; font.pixelSize: 12
        wrapMode: Text.WrapAnywhere; elide: Text.ElideNone
    }
    Notice { visible: iv.requester !== "" && iv.kind === "lez.wallet.connect"; tone: "warn"; text: "Unsigned app: Basecamp can't confirm who published it." }

    // == blocked =============================================================================
    ColumnLayout {
        visible: iv.blocked
        Layout.fillWidth: true
        spacing: 10
        Notice { tone: "danger"; text: iv.problem }
        Btn { objectName: "requestClose"; Layout.fillWidth: true; large: true; text: "Close"; onClicked: iv.closeBlocked() }
    }

    // == connect ===============================================================================
    ColumnLayout {
        visible: iv.kind === "lez.wallet.connect" && !iv.blocked
        Layout.fillWidth: true
        spacing: 8
        Permissions { Layout.fillWidth: true; privateRead: iv.wantsPrivate }
        Txt { text: "Share which accounts?"; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.topMargin: 8 }
        Repeater {
            model: iv.wantsPrivate ? iv.publicAccounts.concat(iv.privateAccounts) : iv.publicAccounts
            AccountCard {
                controlled: true
                accountId: modelData.accountId
                name: Fmt.accountName(modelData)
                kind: modelData.kind
                balance: modelData.kind === "private" || modelData.native === null || modelData.native === undefined ? "" : String(modelData.native)
                checked: iv.picked.indexOf(modelData.accountId) >= 0
                onToggled: iv.toggle(modelData.accountId)
            }
        }
        CheckRow {
            visible: iv.pickedPrivate
            controlled: true
            checked: iv.privConsent
            accent: Theme.priv
            text: "Let this app read the balance of the private accounts I ticked. It still can't spend from them."
            onToggled: function (c) { iv.privConsent = c }
        }
        CheckRow {
            id: connectSiteAck
            visible: !!iv.p.signIn
            text: "Also sign in to " + (iv.p.signIn ? iv.p.signIn.domain : "") + ": I started this from that site."
        }
        Field { id: cpw; objectName: "connectPassword"; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Your wallet password"; onAccepted: connectBtn.clicked() }
        Notice { visible: iv.problem !== ""; Layout.fillWidth: true; text: iv.problem; tone: "danger" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Btn { objectName: "connectCancel"; Layout.fillWidth: true; large: true; text: "Cancel"; enabled: !iv.busy; onClicked: iv.cancel() }
            Btn {
                id: connectBtn
                objectName: "connectApprove"
                Layout.fillWidth: true; large: true; tone: "action"
                text: "Connect " + iv.picked.length + " account" + (iv.picked.length === 1 ? "" : "s")
                armDelay: 500
                busy: iv.busy
                enabled: iv.picked.length > 0 && cpw.text.length > 0 && (!iv.pickedPrivate || iv.privConsent)
                onClicked: { iv.connect(cpw.text); cpw.text = "" }
            }
        }
    }

    // == transaction ===========================================================================
    Spinner { visible: iv.kind === "lez.transaction.send" && !iv.ticket && !iv.blocked && !iv.handle; Layout.alignment: Qt.AlignHCenter; size: 28 }
    ApprovalView {
        visible: iv.kind === "lez.transaction.send" && !!iv.ticket && !iv.blocked
        Layout.fillWidth: true
        store: iv.store
        ticket: iv.ticket
        busy: iv.busy
        problem: iv.problem
        onApprove: function (password, ack) { iv.approveTx(password, ack) }
        onReject: iv.cancel()
    }
    ProofView {
        visible: iv.handle !== ""
        Layout.fillWidth: true
        store: iv.store
        handle: iv.handle
        onClose: iv.finished()
    }

    // == sign message ==========================================================================
    ColumnLayout {
        visible: iv.kind === "lez.message.sign" && !iv.blocked
        Layout.fillWidth: true
        spacing: 8
        InfoRow { label: "Account"; value: Fmt.short(iv.p.account || ""); mono: true }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.min(msg.implicitHeight + 24, 220)
            radius: Theme.rRow
            color: Theme.surface2
            clip: true
            Txt { id: msg; x: 12; y: 12; width: parent.width - 24; text: iv.kind === "lez.message.sign" ? iv.decodeMessage(iv.p.message || "") : ""; font.pixelSize: 13; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
        }
        Notice { text: "Signing proves you own this account. It can't move funds or approve a transaction." }
        Notice { visible: iv.problem !== ""; Layout.fillWidth: true; text: iv.problem; tone: "danger" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Btn { Layout.fillWidth: true; large: true; text: "Reject"; enabled: !iv.busy; onClicked: iv.cancel() }
            Btn {
                objectName: "signApprove"
                Layout.fillWidth: true; large: true; tone: "ink"; text: "Sign"; armDelay: 500; busy: iv.busy
                onClicked: {
                    iv.busy = true
                    iv.store.call("signMessage", { account: iv.p.account, message: iv.p.message }, function (v, e) {
                        iv.busy = false
                        if (e) { iv.problem = Fmt.errorText(e); return }
                        iv.store.answer(true, v, "")
                        iv.finished()
                    })
                }
            }
        }
    }

    // == sign in ===============================================================================
    ColumnLayout {
        visible: iv.kind === "lez.wallet.sign_in" && !iv.blocked
        Layout.fillWidth: true
        spacing: 8
        InfoRow { label: "Site"; value: iv.p.domain || ""; mono: true }
        InfoRow { label: "URI"; value: iv.p.uri || ""; mono: true }
        Txt { visible: !!iv.p.statement; Layout.fillWidth: true; text: iv.p.statement || ""; tone: "text2"; wrapMode: Text.Wrap; font.pixelSize: 13 }
        Txt { text: "Sign in with"; tone: "text2"; font.pixelSize: 13 }
        Repeater {
            model: iv.publicAccounts
            AccountCard {
                multi: false
                controlled: true
                accountId: modelData.accountId
                name: Fmt.accountName(modelData)
                kind: modelData.kind
                checked: iv.picked.indexOf(modelData.accountId) >= 0
                onToggled: iv.picked = [modelData.accountId]
            }
        }
        Notice { tone: "warn"; text: "Basecamp can't verify the site name an app gives. Sign in only if you started this from that site." }
        CheckRow {
            id: siteAck
            objectName: "signInAck"
            text: "I started this sign-in from " + (iv.p.domain || "that site") + "."
        }
        Notice { visible: iv.problem !== ""; Layout.fillWidth: true; text: iv.problem; tone: "danger" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Btn { Layout.fillWidth: true; large: true; text: "Cancel"; enabled: !iv.busy; onClicked: iv.cancel() }
            Btn {
                Layout.fillWidth: true; large: true; tone: "action"; text: "Sign in"; armDelay: 500; busy: iv.busy
                enabled: iv.picked.length === 1 && siteAck.checked
                onClicked: {
                    iv.busy = true
                    iv.store.call("signIn", { requester: iv.requester, account: iv.picked[0], request: iv.p, acknowledged: true }, function (v, e) {
                        iv.busy = false
                        if (e) { iv.problem = Fmt.errorText(e); return }
                        iv.store.answer(true, v, "")
                        iv.finished()
                    })
                }
            }
        }
    }

    // == request funds =========================================================================
    ColumnLayout {
        visible: iv.kind === "lez.wallet.request_funds" && !iv.blocked
        Layout.fillWidth: true
        spacing: 8
        Txt {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            tone: "text2"; font.pixelSize: 13
            text: (String(iv.p.account || "").indexOf("pvt_") === 0 ? "Into your private account (funded publicly, then moved in with a proof). " : "Into " + Fmt.short(iv.p.account || "") + ". ")
                  + "From: " + (iv.store.state.faucet || "")
        }
        RowLayout {
            visible: iv.job !== "" && iv.fundResult === null
            spacing: 10
            Dots { color: Theme.action }
            ShimmerText { text: "Asking the faucet and waiting for the block"; pixelSize: 13 }
        }
        Notice {
            visible: iv.fundResult !== null && iv.fundResult.state === "done"
            tone: iv.fundResult && iv.fundResult.result && iv.fundResult.result.status === "funded" ? "info" : "warn"
            text: {
                var r = iv.fundResult && iv.fundResult.result
                if (!r) return ""
                if (r.status === "funded") return "+" + Fmt.lgo(r.amount) + " arrived" + (r.shield ? ". Approve moving it into your private account next." : ".")
                if (r.status === "rate_limited") return "You can claim again in " + Fmt.mmss(r.retryAfterSeconds) + "."
                if (r.status === "outcome_unknown") return "Checking whether funds arrived… " + (r.reason || "")
                return r.reason || "The faucet declined."
            }
        }
        Notice { visible: iv.problem !== ""; Layout.fillWidth: true; text: iv.problem; tone: "danger" }
        RowLayout {
            visible: iv.fundResult === null
            Layout.fillWidth: true
            spacing: 8
            Btn { Layout.fillWidth: true; large: true; text: "Cancel"; enabled: iv.job === ""; onClicked: iv.cancel() }
            Btn {
                objectName: "fundsApprove"
                Layout.fillWidth: true; large: true; tone: "ink"; icon: "droplet"; text: "Get test LGO"; busy: iv.job !== ""
                onClicked: {
                    iv.busy = true
                    iv.store.call("requestFunds", { account: iv.p.account, requester: iv.requester }, function (v, e) {
                        if (e) { iv.busy = false; iv.problem = Fmt.errorText(e); return }
                        iv.job = v.job
                    })
                }
            }
        }
        Btn { objectName: "fundsDone"; visible: iv.fundResult !== null; Layout.fillWidth: true; large: true; text: "Done"; onClicked: iv.finished() }
    }
}
