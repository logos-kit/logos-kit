import QtQuick
import QtQuick.Layouts
import "LogosKit"      // the SDK: kit.api.connect(), .transfer(), .watchTransaction(), …
import "LogosKitUi"    // optional: the wallet's look (Theme, Btn, Card, Field, Notice, …)

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

    // The wallet must be on the same network. "lez:local" for a local sequencer.
    property string chain: "lez:testnet"

    property var session: null
    readonly property string account: session && session.accounts.length ? session.accounts[0].address : ""
    property string balance: ""
    property string phase: "idle"     // idle | funding | approving | sending | done | failed
    property var receipt: null        // the latest TransactionStatus
    property string message: ""

    LogosKit {
        id: kit
        chain: root.chain
        visible: root.visible         // status polling pauses while the app is hidden
        // Restore an earlier connection silently (no prompt).
        onApiChanged: if (api) api.getSession().then(function (s) { if (s) root.use(s) }, function () {})
    }

    function use(s) { root.session = s; refresh() }

    function refresh() {
        if (!root.account) return
        kit.api.getWalletBalance(root.account).then(function (b) { root.balance = b.amount }, show)
    }

    // Errors are LezError { code, message }. A user saying no is not an error.
    function show(e) {
        root.phase = "idle"
        root.message = kit.sdk.isUserRejection(e) ? "" : (e && e.message) || "Something went wrong"
    }

    function connect() {
        root.message = ""
        kit.api.connect({ accountKinds: ["public"] }).then(use, show)
    }

    function getFunds() {
        root.phase = "funding"
        kit.api.requestFunds(root.account).then(function (r) {
            root.phase = "idle"
            root.message = r.status === "funded" ? "" : r.status === "rate_limited"
                ? "The faucet is busy; try again in " + Math.ceil((r.retryAfterSeconds || 60) / 60) + " min."
                : r.reason || "No funds this time."
            refreshLater.restart()
        }, show)
    }

    function send() {
        root.phase = "approving"
        root.message = ""
        // Resolves once the user approved in the wallet; the handle follows it from there.
        kit.api.transfer(root.account, to.text.trim(), amount.text.trim()).then(function (r) {
            root.phase = "sending"
            kit.api.watchTransaction(r.handle, function (s) {
                root.receipt = s
                if (s.lifecycle === "included" || s.lifecycle === "finalized") {
                    root.phase = s.outcome === "failure" ? "failed" : "done"
                    refresh()
                } else if (s.lifecycle === "rejected" || s.lifecycle === "dropped" || s.lifecycle === "expired") {
                    root.phase = "failed"
                }
            }, show)
        }, show)
    }

    Timer { id: refreshLater; interval: 2000; onTriggered: root.refresh() }

    readonly property bool validSend: kit.sdk !== undefined && kit.sdk.isAccountId(to.text.trim())
        && /^[1-9][0-9]*$/.test(amount.text.trim())

    Rectangle { anchors.fill: parent; color: Theme.bg }

    ColumnLayout {
        width: Math.min(parent.width - 32, 520)
        x: (parent.width - width) / 2
        y: 24
        spacing: 14

        RowLayout {
            spacing: 10
            LogosMark { size: 22 }
            Txt { text: "My LEZ dApp"; font.pixelSize: 20; font.weight: Font.DemiBold }
            Tag { text: root.chain.replace("lez:", "") }
        }

        // 1. Connect
        Btn {
            objectName: "connect"
            visible: !root.session
            Layout.fillWidth: true
            large: true
            tone: "action"
            text: "Connect wallet"
            onClicked: root.connect()
        }

        // 2. Account and balance
        Card {
            visible: !!root.session
            Layout.fillWidth: true
            RowLayout {
                width: parent.width
                spacing: 12
                Identicon { seed: root.account; size: 36 }
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Txt { text: root.account; mono: true; font.pixelSize: 12; tone: "text2"; Layout.fillWidth: true }
                    Txt { objectName: "balance"; text: (root.balance || "–") + " LEZ"; font.pixelSize: 22; font.weight: Font.DemiBold; num: true }
                }
            }
        }

        // 3. Funds in the flow
        Btn {
            objectName: "funds"
            visible: !!root.session && root.balance === "0"
            text: root.phase === "funding" ? "Getting test LEZ…" : "Get test LEZ"
            icon: "droplet"
            busy: root.phase === "funding"
            onClicked: root.getFunds()
        }

        // 4. Propose a transfer
        Card {
            visible: !!root.session
            Layout.fillWidth: true
            ColumnLayout {
                width: parent.width
                spacing: 10
                Txt { text: "Send LEZ"; font.pixelSize: 16; font.weight: Font.DemiBold }
                Field { id: to; objectName: "to"; Layout.fillWidth: true; mono: true; placeholderText: "Recipient account" }
                Field { id: amount; objectName: "amount"; Layout.fillWidth: true; placeholderText: "Amount"; inputMethodHints: Qt.ImhDigitsOnly }
                Btn {
                    objectName: "send"
                    Layout.fillWidth: true
                    large: true
                    tone: "ink"
                    enabled: root.validSend && root.phase !== "approving" && root.phase !== "sending"
                    busy: root.phase === "approving" || root.phase === "sending"
                    text: root.phase === "approving" ? "Approve in your wallet…" : root.phase === "sending" ? "Sending…" : "Send"
                    onClicked: root.send()
                }
            }
        }

        // 5. Receipt
        Card {
            objectName: "receipt"
            visible: !!root.receipt
            Layout.fillWidth: true
            ColumnLayout {
                width: parent.width
                spacing: 4
                RowLayout {
                    Txt { text: "Transaction"; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    Tag {
                        objectName: "lifecycle"
                        text: root.receipt ? root.receipt.lifecycle : ""
                        tone: root.phase === "done" ? "ok" : root.phase === "failed" ? "danger" : "pending"
                    }
                }
                Txt { visible: !!(root.receipt && root.receipt.txHash); text: root.receipt && root.receipt.txHash ? root.receipt.txHash : ""; mono: true; tone: "text2"; font.pixelSize: 11; Layout.fillWidth: true }
                Txt { visible: !!(root.receipt && root.receipt.block); text: root.receipt && root.receipt.block ? "Block #" + root.receipt.block.id : ""; tone: "text2"; font.pixelSize: 12 }
            }
        }

        Notice { visible: root.message !== ""; tone: "warn"; text: root.message }
    }
}
