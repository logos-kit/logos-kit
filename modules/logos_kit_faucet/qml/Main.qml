import QtQuick
import QtQuick.Layouts
import "LogosKit"
import "LogosKitUi"

// Logos Kit Faucet: the LP-0021 faucet reference app for the Logos Kit SDK.
//
//   connect (the wallet asks which accounts to share) → pick one → request →
//   funded / rate-limited (countdown) / unconfirmed (we check the balance) /
//   declined. A private account is funded through a public one, then the
//   wallet asks the user to approve moving it in privately (a local proof);
//   the app follows that step too.
Item {
    id: root
    width: 520
    height: 820

    /** The wallet's network (the SDK follows it). */
    readonly property string chain: kit.chain

    property var session: null
    property var accounts: session ? session.accounts : []
    property string account: ""
    readonly property var selected: accountOf(account)
    property var balances: ({})
    property var limits: ({})          // address -> epoch ms when the next claim opens
    property real now: Date.now()

    property string phase: "idle"      // idle | requesting | checking | shielding | done | limited | unconfirmed | declined | failed
    property var result: null
    property string failure: ""
    property string note: ""
    property var shield: null          // { handle, status, startedAt }
    property var watcher: null
    // An unconfirmed claim: which account we watch (the one the faucet paid),
    // its balance before, when we started and how many reads we tried.
    property var claim: null
    property var history: []
    // Bumped when the network (and so `kit.api`) changes: late answers from
    // the old one are dropped.
    property int epoch: 0
    property int maxChecks: 30
    property int maxCheckMs: 120000

    LogosKit {
        id: kit
        visible: root.visible
        // Rebuilt when the wallet's network changes: start over on the new one.
        onApiChanged: if (api) { root.reset(); root.restore() }
    }

    function reset() {
        root.epoch++
        if (root.watcher) root.watcher.stop()
        root.watcher = null; root.claim = null
        checkTimer.stop()
        root.session = null; root.account = ""; root.balances = ({}); root.limits = ({})
        root.phase = "idle"; root.result = null; root.shield = null; root.note = ""; root.history = []
    }

    // ---- helpers --------------------------------------------------------------

    function shortId(a) { return a && a.length > 12 ? a.substring(0, 5) + "…" + a.substring(a.length - 4) : (a || "") }
    function accountOf(a) {
        for (var i = 0; i < accounts.length; i++) if (accounts[i].address === a) return accounts[i]
        return null
    }
    function nameOf(acc) {
        if (!acc) return ""
        if (acc.label) return acc.label
        return acc.kind === "private" ? "Private ··" + acc.address.substring(acc.address.length - 4) : shortId(acc.address)
    }
    function amount(raw) {
        if (raw === undefined || raw === null || raw === "") return "–"
        var s = String(raw), out = ""
        for (var i = 0; i < s.length; i++) {
            if (i > 0 && (s.length - i) % 3 === 0) out += ","
            out += s.charAt(i)
        }
        return out
    }
    function mmss(sec) {
        sec = Math.max(0, Math.ceil(sec))
        var m = Math.floor(sec / 60), s = sec % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }
    readonly property real waitLeft: limits[account] ? Math.max(0, (limits[account] - now) / 1000) : 0
    function errText(e) {
        if (!e) return "Something went wrong"
        if (e.code === 6109) return "This wallet has no faucet for " + root.chain + " yet. Set one in the wallet: Settings → Network."
        if (e.code === 4902) return "Your wallet is on another network. Switch it to " + root.chain + " in the wallet's settings."
        if (e.code === 4900 || e.code === 4901) return "Can't reach the network right now. Check your connection and try again."
        if (e.code === 4100) return "The wallet no longer shares this account with the app. Connect again."
        return e.message || ("Error " + e.code)
    }
    function isRejection(e) { return e && kit.sdk && kit.sdk.isUserRejection(e) }
    function log(entry) {
        entry.at = Date.now()
        entry.account = root.account
        entry.kind = root.selected ? root.selected.kind : ""
        root.history = [entry].concat(root.history).slice(0, 8)
    }

    // ---- flows ----------------------------------------------------------------

    // Wraps a callback so it runs only if the network hasn't changed since.
    function live(f) {
        var ep = root.epoch
        return function (v) { if (ep === root.epoch) return f(v) }
    }

    function restore() {
        kit.api.getSession().then(live(function (s) { if (s && s.accounts.length) useSession(s) }), function () {})
    }

    function connect() {
        root.note = ""
        kit.api.connect({ accountKinds: ["public", "private"] }).then(live(useSession), live(function (e) {
            root.note = isRejection(e) ? "" : errText(e)
        }))
    }

    function useSession(s) {
        root.session = s
        if (!accountOf(root.account)) root.account = s.accounts.length ? s.accounts[0].address : ""
        for (var i = 0; i < s.accounts.length; i++) refreshBalance(s.accounts[i].address)
    }

    function select(a) {
        if (root.phase === "requesting" || root.phase === "shielding" || root.phase === "checking" || root.phase === "unconfirmed") return
        root.account = a
        root.phase = root.limits[a] && root.limits[a] > Date.now() ? "limited" : "idle"
        refreshBalance(a)
    }

    // `then(amount)` on a read, `failed(error)` when it couldn't be read.
    function refreshBalance(a, then, failed) {
        return kit.api.getWalletBalance(a).then(live(function (b) {
            var m = {}
            for (var k in root.balances) m[k] = root.balances[k]
            m[a] = b.amount
            root.balances = m
            if (then) then(b.amount)
        }), live(function (e) { if (failed) failed(e) }))
    }

    function request() {
        var a = root.account, ep = root.epoch
        root.phase = "requesting"
        root.result = null
        root.failure = ""
        root.note = ""
        root.claim = null
        var before = {}
        for (var k in root.balances) before[k] = root.balances[k]
        kit.api.requestFunds(a).then(function (r) {
            if (ep !== root.epoch) return
            root.result = r
            // A private target is funded through a public account of yours.
            var paid = r.fundedAccount || a
            if (r.status === "funded") {
                if (r.shieldHandle) { startShield(r.shieldHandle); return }
                if (root.selected && root.selected.kind === "private") {
                    root.note = "The faucet paid your public account " + root.shortId(paid) + ", but the private move couldn't start. Move it from the wallet."
                }
                root.phase = "done"
                log({ status: "funded", amount: r.amount })
                settle(a)
            } else if (r.status === "rate_limited") {
                limit(a, r.retryAfterSeconds || 60)
            } else if (r.status === "outcome_unknown") {
                startChecking(paid, before[paid] || "0")
            } else {
                root.failure = r.reason || "The faucet declined this request."
                root.phase = "declined"
                log({ status: "declined" })
            }
        }, function (e) {
            if (ep !== root.epoch) return
            if (isRejection(e)) { root.phase = "idle"; root.note = "Cancelled in the wallet." }
            else { root.failure = errText(e); root.phase = "failed" }
        })
    }

    function limit(a, seconds) {
        var m = {}
        for (var k in root.limits) m[k] = root.limits[k]
        m[a] = Date.now() + seconds * 1000
        root.limits = m
        root.phase = "limited"
        log({ status: "rate_limited" })
    }

    // Balance moves a moment after the transfer lands.
    function settle(a) { settleTimer.target = a; settleTimer.restart() }
    Timer { id: settleTimer; property string target: ""; interval: 1500; onTriggered: root.refreshBalance(target) }

    // outcome_unknown: never ask again blindly (it could pay twice); watch the
    // balance of the account the faucet paid. Every tick counts, read or not,
    // so the watch always ends: after `maxChecks` reads or `maxCheckMs`.
    function startChecking(watch, before) {
        root.claim = { account: watch, before: before, startedAt: Date.now(), attempts: 0, epoch: root.epoch }
        root.phase = "checking"
        checkTimer.restart()
    }
    function checkOnce() {
        var c = root.claim
        if (!c || c.epoch !== root.epoch) { checkTimer.stop(); return }
        c.attempts++
        root.refreshBalance(c.account, function (bal) {
            if (root.claim !== c || (root.phase !== "checking" && root.phase !== "unconfirmed")) return
            if (bal !== c.before && bal !== "0") {
                checkTimer.stop()
                root.claim = null
                root.result = { status: "funded", amount: "" }
                if (root.selected && root.selected.kind === "private")
                    root.note = "It arrived in your public account " + root.shortId(c.account) + ". Move it in privately from the wallet."
                root.phase = "done"
                log({ status: "funded" })
            } else giveUp(c)
        }, function () { if (root.claim === c) giveUp(c) })
    }
    function giveUp(c) {
        if (root.phase !== "checking") return
        if (c.attempts < root.maxChecks && Date.now() - c.startedAt < root.maxCheckMs) return
        checkTimer.stop()
        root.phase = "unconfirmed"
        log({ status: "unknown" })
    }
    Timer { id: checkTimer; interval: 3000; repeat: true; onTriggered: root.checkOnce() }

    function startShield(handle) {
        var ep = root.epoch, target = root.account
        var paid = root.result && root.result.fundedAccount ? root.result.fundedAccount : ""
        var where = paid ? "your public account " + root.shortId(paid) : "your public account"
        var privBefore = root.balances[target] || "0"
        root.phase = "shielding"
        root.shield = { handle: handle, status: null, startedAt: 0 }
        if (root.watcher) root.watcher.stop()
        root.watcher = kit.api.watchTransaction(handle, function (s) {
            if (ep !== root.epoch) return
            var sh = { handle: handle, status: s, startedAt: root.shield.startedAt }
            if (!sh.startedAt && s.lifecycle !== "awaiting_approval") sh.startedAt = Date.now()
            root.shield = sh
            if (s.lifecycle === "included" || s.lifecycle === "finalized") {
                if (s.outcome === "failure") { root.failure = "The private move failed. The funds are still in " + where + "."; root.phase = "failed"; return }
                if (s.outcome === "success") { shielded(); return }
                // Included, outcome unknown: the private balance decides.
                root.refreshBalance(target, function (bal) {
                    if (bal !== privBefore && bal !== "0") shielded()
                    else { root.claim = { account: target, before: privBefore, startedAt: Date.now(), attempts: 0, epoch: ep, shield: true }; root.phase = "unconfirmed" }
                }, function () { root.claim = { account: target, before: privBefore, startedAt: Date.now(), attempts: 0, epoch: ep, shield: true }; root.phase = "unconfirmed" })
            } else if (s.lifecycle === "rejected" || s.lifecycle === "dropped" || s.lifecycle === "expired") {
                root.failure = s.lifecycle === "rejected" && s.outcome === "unknown"
                    ? "You didn't approve the private move. The funds are in " + where + "; move them from the wallet."
                    : ((s.error && s.error.message) || "The private move didn't go through.") + " The funds are in " + where + "."
                root.phase = "failed"
            }
        }, function (e) { if (ep === root.epoch) { root.failure = errText(e); root.phase = "failed" } })
    }
    function shielded() {
        root.phase = "done"
        log({ status: "funded", amount: root.result ? root.result.amount : "" })
        for (var i = 0; i < root.accounts.length; i++) root.refreshBalance(root.accounts[i].address)
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.phase === "limited" || root.phase === "shielding")
        onTriggered: {
            root.now = Date.now()
            if (root.phase === "limited" && root.waitLeft <= 0) root.phase = "idle"
        }
    }

    // ---- view -----------------------------------------------------------------

    Rectangle { anchors.fill: parent; color: Theme.bg }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: Math.min(flick.width - 32, 560)
            x: (flick.width - width) / 2
            y: 20
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                LogosMark { size: 22; white: Theme.dark }
                Txt { text: "Faucet"; font.pixelSize: 20; font.weight: Font.DemiBold }
                Tag { text: root.chain.replace("lez:", ""); tone: "pending" }
                Item { Layout.fillWidth: true }
                Btn {
                    objectName: "fcConnectTop"
                    visible: root.account === ""
                    text: "Connect"
                    tone: "action"
                    onClicked: root.connect()
                }
            }

            Card {
                Layout.fillWidth: true
                ColumnLayout {
                    width: parent.width
                    spacing: 6
                    Txt { text: "Test LEZ"; font.pixelSize: 26; font.weight: Font.DemiBold }
                    Txt {
                        Layout.fillWidth: true
                        text: "Free tokens for trying things on the testnet: sending, private payments, Basecamp apps. They have no value."
                        tone: "text2"
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                ColumnLayout {
                    width: parent.width
                    spacing: 12

                    // Disconnected
                    ColumnLayout {
                        visible: root.account === ""
                        Layout.fillWidth: true
                        spacing: 10
                        Txt { text: "Choose where it goes"; font.pixelSize: 18; font.weight: Font.DemiBold }
                        Txt {
                            Layout.fillWidth: true
                            text: "Your wallet asks which accounts to share. Public or private both work."
                            tone: "text2"
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                        }
                        Btn { objectName: "fcConnect"; Layout.fillWidth: true; large: true; text: "Connect wallet"; tone: "action"; onClicked: root.connect() }
                        Txt { visible: root.note !== ""; Layout.fillWidth: true; text: root.note; tone: "text2"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    }

                    // Account picker
                    ColumnLayout {
                        visible: root.account !== ""
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Txt { text: "To"; tone: "text2"; font.pixelSize: 13 }
                            Item { Layout.fillWidth: true }
                            Btn { objectName: "fcShareMore"; text: "Share more"; tone: "ghost"; icon: "plus"; onClicked: root.connect() }
                        }
                        Repeater {
                            model: root.accounts
                            Rectangle {
                                objectName: "fcAccount_" + index
                                Layout.fillWidth: true
                                implicitHeight: 56
                                radius: Theme.rRow
                                readonly property bool on: modelData.address === root.account
                                color: on ? Theme.surface2 : "transparent"
                                border.width: on ? 2 : 1
                                border.color: on ? Theme.text : Theme.line
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 14
                                    spacing: 10
                                    Identicon { seed: modelData.address; size: 30 }
                                    ColumnLayout {
                                        spacing: 1
                                        Layout.fillWidth: true
                                        RowLayout {
                                            spacing: 6
                                            Txt { text: root.nameOf(modelData); font.pixelSize: 14; font.weight: Font.DemiBold; Layout.maximumWidth: 200 }
                                            Tag { text: modelData.kind === "private" ? "Private" : "Public"; tone: modelData.kind === "private" ? "private" : "pending"; icon: modelData.kind === "private" ? "shield" : "" }
                                        }
                                        Txt { visible: !!modelData.label && modelData.kind !== "private"; text: root.shortId(modelData.address); tone: "text3"; mono: true; font.pixelSize: 11 }
                                    }
                                    Txt {
                                        objectName: "fcBalance_" + index
                                        text: root.amount(root.balances[modelData.address]) + " LEZ"
                                        tone: "text2"
                                        num: true
                                        font.pixelSize: 13
                                    }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.select(modelData.address) }
                            }
                        }
                    }

                    Rectangle { visible: root.account !== ""; Layout.fillWidth: true; implicitHeight: 1; color: Theme.line }

                    // Idle / requesting / limited
                    ColumnLayout {
                        visible: root.account !== "" && (root.phase === "idle" || root.phase === "requesting" || root.phase === "limited")
                        Layout.fillWidth: true
                        spacing: 10
                        Notice {
                            visible: !!root.selected && root.selected.kind === "private"
                            tone: "private"
                            text: "Private accounts are funded in two steps: the faucet pays one of your public accounts, then you approve moving it in privately. The proof takes a few minutes on this computer."
                        }
                        Btn {
                            objectName: "fcRequest"
                            Layout.fillWidth: true
                            large: true
                            tone: "ink"
                            icon: "droplet"
                            busy: root.phase === "requesting"
                            enabled: root.phase === "idle"
                            text: root.phase === "requesting" ? "Confirm in your wallet…"
                                : root.phase === "limited" ? "Try again in " + root.mmss(root.waitLeft)
                                : "Get test LEZ"
                            onClicked: root.request()
                        }
                        Txt {
                            objectName: "fcLimited"
                            visible: root.phase === "limited"
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: "The faucet pays each account once in a while, so there's enough for everyone."
                            tone: "text3"
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                        }
                        Txt { visible: root.note !== ""; Layout.fillWidth: true; text: root.note; tone: "text2"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    }

                    // Unconfirmed: checking the balance
                    RowLayout {
                        objectName: "fcChecking"
                        visible: root.phase === "checking"
                        spacing: 10
                        Spinner { size: 20 }
                        ColumnLayout {
                            spacing: 2
                            Txt { text: "Checking whether it arrived…"; font.weight: Font.DemiBold }
                            Txt { text: "The faucet didn't confirm yet. We watch your balance instead of asking twice."; tone: "text2"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.maximumWidth: 400 }
                        }
                    }

                    // Unconfirmed: the watch ended without seeing the funds
                    ColumnLayout {
                        objectName: "fcUnconfirmed"
                        visible: root.phase === "unconfirmed"
                        Layout.fillWidth: true
                        spacing: 10
                        Txt { text: "Not confirmed yet"; font.pixelSize: 18; font.weight: Font.DemiBold }
                        Notice {
                            tone: "warn"
                            text: root.claim && root.claim.shield
                                ? "The private move is in a block, but your private balance hasn't changed yet. Check again in a moment."
                                : "We couldn't see the funds arrive" + (root.claim && root.claim.account !== root.account
                                    ? " in your public account " + root.shortId(root.claim.account) + " (private funds go through it)" : "")
                                  + ". Don't ask again yet: it may still land. Check the balance in a minute."
                        }
                        RowLayout {
                            spacing: 8
                            Btn {
                                objectName: "fcCheckAgain"
                                text: "Check balance again"
                                tone: "ink"
                                onClicked: {
                                    var c = root.claim
                                    if (!c) return
                                    root.refreshBalance(c.account, function (bal) {
                                        if (root.claim !== c || bal === c.before || bal === "0") return
                                        root.claim = null
                                        if (c.shield) root.shielded()
                                        else { root.result = { status: "funded", amount: "" }; root.phase = "done"; log({ status: "funded" }) }
                                    }, function (e) { root.note = errText(e) })
                                }
                            }
                            Btn { text: "Back"; onClicked: { root.claim = null; root.phase = "idle"; root.refreshBalance(root.account) } }
                        }
                        Txt { visible: root.note !== ""; Layout.fillWidth: true; text: root.note; tone: "text2"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone }
                    }

                    // Private: shield steps
                    ColumnLayout {
                        objectName: "fcShielding"
                        visible: root.phase === "shielding"
                        Layout.fillWidth: true
                        spacing: 12
                        Txt { text: "Moving it in privately"; font.pixelSize: 18; font.weight: Font.DemiBold }
                        Repeater {
                            model: [
                                { label: "Faucet paid your public account", at: 0 },
                                { label: "Approve the private move in your wallet", at: 1 },
                                { label: "Proving on this computer", at: 2 },
                                { label: "Included in a block", at: 3 }
                            ]
                            RowLayout {
                                readonly property int reached: {
                                    var s = root.shield && root.shield.status
                                    var lc = s ? s.lifecycle : "awaiting_approval"
                                    return lc === "awaiting_approval" ? 1 : (lc === "building" || lc === "proving" || lc === "signing") ? 2 : lc === "submitted" ? 3 : 4
                                }
                                spacing: 10
                                Item {
                                    implicitWidth: 22; implicitHeight: 22
                                    Rectangle { anchors.fill: parent; radius: 11; visible: parent.parent.reached > modelData.at; color: Theme.soft(Theme.ok, 0.16) }
                                    Glyph { anchors.centerIn: parent; visible: parent.parent.reached > modelData.at; name: "check"; color: Theme.ok; width: 13; height: 13; stroke: 2.6 }
                                    Spinner { anchors.centerIn: parent; visible: parent.parent.reached === modelData.at; size: 18; color: modelData.at === 2 ? Theme.privText : Theme.text2 }
                                    Rectangle { anchors.centerIn: parent; visible: parent.parent.reached < modelData.at; width: 8; height: 8; radius: 4; color: Theme.text3 }
                                }
                                Txt { text: modelData.label; tone: parent.reached >= modelData.at ? "text" : "text3" }
                                Item { Layout.fillWidth: true }
                                Txt {
                                    visible: modelData.at === 2 && parent.reached === 2 && !!root.shield && root.shield.startedAt > 0
                                    text: root.shield && root.shield.startedAt ? root.mmss((root.now - root.shield.startedAt) / 1000) : ""
                                    tone: "priv"
                                    num: true
                                    font.pixelSize: 13
                                }
                            }
                        }
                        Txt { text: "You can leave this screen; the wallet keeps going."; tone: "text3"; font.pixelSize: 12 }
                    }

                    // Done
                    ColumnLayout {
                        objectName: "fcDone"
                        visible: root.phase === "done"
                        Layout.fillWidth: true
                        spacing: 10
                        RowLayout {
                            spacing: 12
                            Rectangle {
                                implicitWidth: 44; implicitHeight: 44; radius: 22
                                color: Theme.soft(Theme.ok, 0.16)
                                Glyph { anchors.centerIn: parent; name: "check"; color: Theme.ok; width: 22; height: 22; stroke: 2.6 }
                            }
                            ColumnLayout {
                                spacing: 2
                                Txt {
                                    objectName: "fcAmount"
                                    text: root.result && root.result.amount ? "+" + root.amount(root.result.amount) + " LEZ" : "Funds arrived"
                                    font.pixelSize: 22
                                    font.weight: Font.DemiBold
                                    num: true
                                }
                                Txt { text: "in " + root.nameOf(root.selected); tone: "text2"; font.pixelSize: 13 }
                            }
                        }
                        Txt { visible: root.note !== ""; Layout.fillWidth: true; text: root.note; tone: "warn"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone }
                        RowLayout {
                            spacing: 8
                            Btn {
                                visible: root.chain === "lez:testnet" && !!(root.result && root.result.txHash)
                                text: "View on explorer"
                                icon: "external"
                                tone: "action"
                                onClicked: kit.api.openExplorer({ txHash: root.result.txHash }).catch(function (e) { root.note = errText(e) })
                            }
                            Btn { objectName: "fcAgain"; text: "Done"; onClicked: root.phase = root.waitLeft > 0 ? "limited" : "idle" }
                        }
                    }

                    // Declined / failed
                    ColumnLayout {
                        objectName: "fcFailed"
                        visible: root.phase === "declined" || root.phase === "failed"
                        Layout.fillWidth: true
                        spacing: 10
                        Notice { tone: root.phase === "declined" ? "warn" : "danger"; text: root.failure }
                        Btn { objectName: "fcRetry"; text: "Back"; onClicked: { root.phase = "idle"; root.refreshBalance(root.account) } }
                    }
                }
            }

            // History
            Txt { visible: root.history.length > 0; text: "This session"; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.topMargin: 6 }
            Card {
                visible: root.history.length > 0
                Layout.fillWidth: true
                pad: 8
                ColumnLayout {
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: root.history
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            Layout.leftMargin: 8
                            Layout.rightMargin: 8
                            spacing: 10
                            Identicon { seed: modelData.account; size: 22 }
                            Txt { text: root.nameOf(root.accountOf(modelData.account)) || root.shortId(modelData.account); font.pixelSize: 13; Layout.fillWidth: true }
                            Tag {
                                text: modelData.status === "funded" ? (modelData.amount ? "+" + root.amount(modelData.amount) : "Funded")
                                    : modelData.status === "rate_limited" ? "Wait" : modelData.status === "unknown" ? "Unconfirmed" : "Declined"
                                tone: modelData.status === "funded" ? "ok" : modelData.status === "rate_limited" ? "pending" : "unconfirmed"
                            }
                        }
                    }
                }
            }
        }
    }
}
