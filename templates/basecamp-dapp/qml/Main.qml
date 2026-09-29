import QtQuick
import QtQuick.Layouts
import "LogosKit"      // the SDK: kit.api.connect(), .transfer(), .watchTransaction(), …
import "LogosKitUi"    // optional: the wallet's look (Theme, Btn, Card, Pipeline, AddressChip, …)
import "LogosKitUi/Units.js" as Units   // integer-string amounts (native LEZ has no decimals)

// A Basecamp app on the Logos Execution Zone, built with Logos Kit.
//
// What it shows, in order:
//   1. connect: the wallet asks the user which account to share
//   2. read: the shared account's balance
//   3. funds in the flow: an empty account gets test LEZ without leaving the app
//   4. propose: a transfer the user approves in the wallet (fee shown there)
//   5. receipt: follow the transaction until it is final
//
// Keys never leave the wallet. The app proposes; the user decides.
Item {
    id: root
    width: 480
    height: 720

    // The wallet's network: the SDK follows it (testnet, or lez:local while you develop).
    readonly property string chain: kit.chain

    property var session: null
    readonly property string account: session && session.accounts.length ? session.accounts[0].address : ""
    property string balance: ""
    property string phase: "idle"     // idle | funding | approving | waiting | sending | done | unconfirmed | failed
    property var receipt: null        // the latest TransactionStatus
    property string message: ""
    property var watcher: null
    property var sent: null           // { amount, before }: what the receipt should show
    // Bumped when the wallet switches network (kit.api is rebuilt): answers
    // that arrive later from the old network are ignored.
    property int epoch: 0

    LogosKit {
        id: kit
        visible: root.visible         // status polling pauses while the app is hidden
        // Ready, or rebuilt for another network: start over, then restore a
        // connection silently (no prompt).
        onApiChanged: if (api) {
            root.reset()
            api.getSession().then(root.live(function (s) { if (s) root.use(s) }), function () {})
        }
        // The user took longer than 45 s to approve: the wallet's answer comes here.
        onLateResult: function (intent, ok, data) {
            if (intent !== kit.sdk.INTENTS.sendTransaction || root.phase !== "waiting") return
            if (ok) root.follow(data.handle)
            else root.show(data)
        }
    }

    function reset() {
        root.epoch++
        if (root.watcher) root.watcher.stop()
        root.watcher = null
        root.session = null; root.balance = ""; root.receipt = null; root.sent = null
        root.phase = "idle"; root.message = ""
    }

    // Runs `f` only if the network hasn't changed since this was called.
    function live(f) {
        var ep = root.epoch
        return function (v) { if (ep === root.epoch) return f(v) }
    }

    function use(s) { root.session = s; refresh() }

    function refresh(then) {
        if (!root.account) return
        kit.api.getWalletBalance(root.account).then(live(function (b) {
            root.balance = b.amount
            if (then) then(b.amount)
        }), live(show))
    }

    // Errors are LezError { code, message }. A user saying no is not an error.
    function show(e) {
        root.phase = "idle"
        root.message = kit.sdk.isUserRejection(e) ? "" : (e && e.message) || "Something went wrong"
    }

    function connect() {
        root.message = ""
        kit.api.connect({ accountKinds: ["public"] }).then(live(use), live(show))
    }

    function getFunds() {
        root.phase = "funding"
        kit.api.requestFunds(root.account).then(live(function (r) {
            root.phase = "idle"
            root.message = r.status === "funded" ? ""
                : r.status === "rate_limited" ? "The faucet is busy; try again in " + Math.ceil((r.retryAfterSeconds || 60) / 60) + " min."
                : r.status === "outcome_unknown" ? "The faucet hasn't confirmed yet; your balance updates when it lands. Don't ask again yet."
                : r.reason || "No funds this time."
            refreshLater.restart()
        }), live(show))
    }

    function send() {
        root.phase = "approving"
        root.message = ""
        root.sent = { amount: amount.text.trim(), before: root.balance }
        // Resolves once the user approved in the wallet; the handle follows it from there.
        kit.api.transfer(root.account, to.text.trim(), root.sent.amount).then(live(function (r) {
            root.follow(r.handle)
        }), live(function (e) {
            // No answer in 45 s: the wallet may still be open. Keep waiting;
            // its answer arrives in onLateResult.
            if (e && e.code === kit.sdk.ErrorCode.Timeout) { root.phase = "waiting"; return }
            show(e)
        }))
    }

    // Follow a transaction to the end. `outcome` says whether it worked:
    // "included" alone can also be a failed or unconfirmed transaction.
    function follow(handle) {
        root.phase = "sending"
        if (root.watcher) root.watcher.stop()
        root.watcher = kit.api.watchTransaction(handle, live(function (s) {
            root.receipt = s
            if (s.lifecycle === "included" || s.lifecycle === "finalized") {
                if (s.outcome === "success") { root.phase = "done"; refresh() }
                else if (s.outcome === "failure") { root.phase = "failed"; refresh() }
                else confirm()
            } else if (s.lifecycle === "rejected" || s.lifecycle === "dropped" || s.lifecycle === "expired") {
                root.phase = "failed"
            }
        }), live(show))
    }

    // Outcome unknown: prove it from our own balance, or say "unconfirmed".
    // Done only when the sender went down by the amount plus a fee within the
    // cap you approved: now + amount <= before <= now + amount + maxFee.
    // Anything else (an incoming payment meanwhile, no fee cap to check
    // against) proves nothing. Amounts are digit strings: u128 never becomes a
    // JS number.
    function confirm() {
        refresh(function (now) {
            var s = root.sent
            var cap = root.receipt && root.receipt.fee ? root.receipt.fee.estimatedMax : undefined
            if (!s || s.before === "" || cap === undefined) { root.phase = "unconfirmed"; return }
            var spent = Units.add(now, s.amount)
            var ok = Units.cmp(spent, s.before) <= 0 && Units.cmp(s.before, Units.add(spent, cap)) <= 0
            root.phase = ok ? "done" : "unconfirmed"
        })
    }

    Timer { id: refreshLater; interval: 2000; onTriggered: root.refresh() }

    readonly property bool validSend: kit.sdk !== undefined && kit.sdk.isAccountId(to.text.trim())
        && /^[1-9][0-9]*$/.test(amount.text.trim())

    Rectangle { anchors.fill: parent; color: Theme.bg }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: Math.min(parent.width - 32, 520)
        x: (parent.width - width) / 2
        y: 24
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            LogosMark { size: 22; white: Theme.dark }
            Txt { text: "My LEZ dApp"; font.pixelSize: 20; font.weight: Font.Bold }
            Item { Layout.fillWidth: true }
            Badge { text: root.chain === "lez:preview" ? "LEZ preview" : root.chain === "lez:testnet" ? "LEZ testnet" : root.chain.replace("lez:", "LEZ "); tone: "ok"; live: true }
        }

        // Start: what this app does, then connect.
        Card {
            visible: !root.session
            Layout.fillWidth: true
            pad: 22
            ColumnLayout {
                width: parent.width
                spacing: 14
                Txt { text: "Send LEZ from Basecamp"; font.pixelSize: 24; font.weight: Font.Bold; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
                Txt {
                    Layout.fillWidth: true
                    text: "A starter app for the Logos Kit SDK. Your keys stay in the wallet: this app only proposes, and you approve every transaction there."
                    tone: "text2"; wrapMode: Text.Wrap; elide: Text.ElideNone; lineHeight: 1.2
                }
                Pipeline {
                    Layout.fillWidth: true
                    compact: true
                    stages: [
                        { label: "Connect", detail: "The wallet asks which account to share", status: "active" },
                        { label: "Get test LEZ", detail: "Right here, if the account is empty", status: "pending" },
                        { label: "Send", detail: "You approve it in the wallet, fee shown first", status: "pending" },
                        { label: "Receipt", detail: "Followed until the block, outcome checked", status: "pending" }
                    ]
                }
                Btn {
                    objectName: "connect"
                    Layout.fillWidth: true
                    large: true
                    tone: "action"
                    text: "Connect wallet"
                    onClicked: root.connect()
                }
            }
        }

        // Account and balance
        Card {
            visible: !!root.session
            Layout.fillWidth: true
            pad: 20
            ColumnLayout {
                width: parent.width
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Txt { text: "Balance"; tone: "text2"; font.pixelSize: 13 }
                    Item { Layout.fillWidth: true }
                    AddressChip { address: root.account }
                }
                RowLayout {
                    spacing: 8
                    Txt { objectName: "balance"; text: root.balance === "" ? "–" : Units.group(root.balance); font.pixelSize: 34; font.weight: Font.Bold; num: true }
                    Txt { text: "LEZ"; tone: "text2"; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignBaseline }
                }
                Btn {
                    objectName: "funds"
                    visible: root.balance === "0"
                    text: root.phase === "funding" ? "Getting test LEZ…" : "Get test LEZ"
                    icon: "droplet"
                    tone: "ink"
                    busy: root.phase === "funding"
                    onClicked: root.getFunds()
                }
            }
        }

        // Propose a transfer
        Card {
            visible: !!root.session
            Layout.fillWidth: true
            pad: 20
            ColumnLayout {
                width: parent.width
                spacing: 10
                Txt { text: "Send LEZ"; font.pixelSize: 17; font.weight: Font.DemiBold }
                Txt { text: "Recipient"; tone: "text2"; font.pixelSize: 12; font.weight: Font.DemiBold }
                Field { id: to; objectName: "to"; Layout.fillWidth: true; mono: true; placeholderText: "Public account address" }
                Txt { text: "Amount (whole LEZ: native LEZ has no decimals)"; tone: "text2"; font.pixelSize: 12; font.weight: Font.DemiBold }
                Field { id: amount; objectName: "amount"; Layout.fillWidth: true; placeholderText: "e.g. 42"; inputMethodHints: Qt.ImhDigitsOnly }
                Btn {
                    objectName: "send"
                    Layout.fillWidth: true
                    large: true
                    tone: "ink"
                    enabled: root.validSend && root.phase !== "approving" && root.phase !== "waiting" && root.phase !== "sending"
                    busy: root.phase === "approving" || root.phase === "waiting" || root.phase === "sending"
                    text: root.phase === "approving" || root.phase === "waiting" ? "Approve in your wallet…" : root.phase === "sending" ? "Sending…" : "Send"
                    onClicked: root.send()
                }
            }
        }

        // Receipt
        Card {
            objectName: "receipt"
            visible: !!root.receipt || root.phase === "waiting"
            Layout.fillWidth: true
            pad: 20
            ColumnLayout {
                width: parent.width
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    SuccessCheck { visible: root.phase === "done"; size: 40 }
                    Txt { text: root.phase === "done" ? "Sent " + (root.sent ? Units.group(root.sent.amount) : "") + " LEZ" : "Transaction"; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Badge {
                        objectName: "lifecycle"
                        text: root.phase === "done" ? "Confirmed" : root.phase === "failed" ? "Failed" : root.phase === "unconfirmed" ? "Not confirmed" : root.receipt ? root.receipt.lifecycle : "Waiting"
                        tone: root.phase === "done" ? "ok" : root.phase === "failed" ? "danger" : root.phase === "unconfirmed" ? "warn" : "action"
                        live: root.phase === "sending" || root.phase === "waiting"
                    }
                }
                Pipeline {
                    visible: root.phase !== "done"
                    Layout.fillWidth: true
                    compact: true
                    stages: {
                        var lc = root.receipt ? root.receipt.lifecycle : ""
                        var failed = root.phase === "failed"
                        var reached = root.phase === "waiting" ? 0 : lc === "submitted" ? 2 : (lc === "included" || lc === "finalized") ? 3 : 1
                        function st(i) { return failed && i === reached ? "failed" : reached > i ? "done" : reached === i ? "active" : "pending" }
                        return [
                            { label: "Approved in your wallet", status: st(0), progress: reached === 0 ? -1 : undefined },
                            { label: "Signed and sent", status: st(1), progress: reached === 1 ? -1 : undefined },
                            { label: "Included in a block", status: st(2), progress: reached === 2 ? -1 : undefined },
                            { label: root.phase === "unconfirmed" ? "Outcome not confirmed" : "Outcome checked", status: root.phase === "unconfirmed" ? "failed" : st(3),
                              detail: root.phase === "unconfirmed" ? "In a block, but neither the wallet nor your balance proves it worked. Check your balance before sending again." : "" }
                        ]
                    }
                }
                Btn { visible: root.phase === "unconfirmed"; text: "Check again"; icon: "refresh"; onClicked: root.confirm() }
                InfoRow { visible: !!(root.receipt && root.receipt.block); label: "Block"; value: root.receipt && root.receipt.block ? Units.group(root.receipt.block.id) : "" }
                InfoRow { visible: !!(root.receipt && root.receipt.txHash); label: "Transaction"; value: root.receipt && root.receipt.txHash ? root.receipt.txHash.slice(0, 10) + "…" + root.receipt.txHash.slice(-6) : ""; mono: true }
            }
        }

        Notice {
            visible: root.phase === "waiting"
            text: "Still waiting for your wallet. Finish or cancel the request there."
        }
        Notice { visible: root.message !== ""; tone: "warn"; text: root.message }
    }
    }
}
