import QtQuick
import "LogosKitUi"
import QtQuick.Layouts
import "LogosKitWallet"
import "LogosKitWallet/Fmt.js" as Fmt

// Logos Kit wallet (Basecamp ui_qml view). Paints its own background (the
// host widget behind a view is white), owns the Store, switches between
// onboarding/unlock and home, and hosts the one sheet layer: send, receive,
// accounts, settings, a proof, an app's intent, or a request an app made
// directly through the core module.
Item {
    id: root
    width: 480
    height: 780

    Store { id: store }

    // Sheet state: "" | send | receive | accounts | settings | proof | intent | pending
    property string sheet: ""
    // A request that arrived while another sheet was open (e.g. the private
    // move after a faucet claim) shows once that sheet closes.
    function showPending() {
        var p = store.pending
        if (p && root.sheet === "" && store.intent === null && !root.ownTickets[p.handle]) root.sheet = "pending"
    }
    onSheetChanged: if (sheet === "") Qt.callLater(showPending)
    property string proofHandle: ""
    // Tickets our own flows opened: never shown again as "pending".
    property var ownTickets: ({})
    readonly property bool showOnboarding: !store.unlocked || onboarding.inFlow

    function openSheet(k) { root.sheet = k; store.touch() }
    // Token sheets (ux-tokens-nfts §2.2–2.6).
    property string tokenFocus: ""
    function showToken(d) { root.tokenFocus = d; root.openSheet("tokenDetail") }
    function requestFunds() {
        var acct = store.current
        if (!acct) return
        store.requestFunds(acct.accountId, function (v, e) { if (e) toasts.show({ title: "Couldn't request test LGO", body: Fmt.errorText(e), tone: "danger" }) })
    }
    function closeSheet() {
        if (root.sheet === "intent" && store.intent !== null) intentView.cancel()
        if (root.sheet === "send") sendFlow.back()
        if (root.sheet === "tokenCreate") { createToken.back(); createToken.reset() }
        root.sheet = ""
        sendFlow.reset()
    }

    Rectangle { anchors.fill: parent; color: Theme.bg }

    // -- intents and direct requests --------------------------------------------------
    Connections {
        target: store
        function onIntentArrived() {
            if (!store.unlocked) return
            // An app's request replaces an unfinished send: drop its prepared request.
            if (root.sheet === "send") { sendFlow.back(); sendFlow.reset() }
            root.sheet = "intent"
        }
        function onUnlockedChanged() {
            if (store.unlocked && store.intent !== null) root.sheet = "intent"
            if (!store.unlocked && root.sheet !== "") root.sheet = ""
        }
        function onPendingChanged() { root.showPending() }
        function onSettled(s) {
            var ok = s.lifecycle === "included" && s.outcome === "success"
            toasts.show({
                title: ok ? (s.title || "Transaction") + " confirmed"
                     : s.lifecycle === "included" ? (s.title || "Transaction") + " not confirmed yet"
                     : (s.title || "Transaction") + (s.lifecycle === "rejected" ? " declined" : " not sent"),
                body: s.block ? "Block " + Fmt.amount(String(s.block), 0) : (s.error || ""),
                tone: ok ? "ok" : s.lifecycle === "included" ? "warn" : "danger"
            })
        }
        function onToast(text, tone) { toasts.show({ title: text, tone: tone === "ok" ? "ok" : tone === "danger" || tone === "error" ? "danger" : "info" }) }
    }

    // -- screens -------------------------------------------------------------------------
    // Cold start: Basecamp loads the wallet core and its dependencies first.
    ColumnLayout {
        objectName: "coldStart"
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 360)
        visible: !store.loaded && store.unreachable === ""
        spacing: 14
        LogosMark { Layout.alignment: Qt.AlignHCenter; size: 44 }
        Spinner { Layout.alignment: Qt.AlignHCenter; size: 22 }
        Txt { Layout.alignment: Qt.AlignHCenter; text: "Starting the wallet…"; font.pixelSize: 16; font.weight: Font.DemiBold }
        Txt {
            Layout.fillWidth: true
            visible: store.slowStart
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            tone: "text2"
            font.pixelSize: 13
            text: "Still starting. The first launch can take up to a minute while Basecamp fetches what Logos Kit needs."
        }
    }
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 380)
        visible: store.unreachable !== ""
        spacing: 12
        Glyph { Layout.alignment: Qt.AlignHCenter; name: "warning"; color: Theme.warn; implicitWidth: 32; implicitHeight: 32 }
        Txt { Layout.alignment: Qt.AlignHCenter; text: "The wallet core isn't answering"; font.pixelSize: 18; font.weight: Font.DemiBold }
        Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; tone: "text2"; text: store.unreachable + ". Make sure the Logos Kit Wallet core module is installed and loaded." }
        Btn { Layout.alignment: Qt.AlignHCenter; icon: "refresh"; text: "Try again"; onClicked: store.refreshAll() }
    }

    Onboarding {
        id: onboarding
        objectName: "onboarding"
        anchors.fill: parent
        visible: store.loaded && root.showOnboarding
        store: store
        onDone: store.refreshAll()
    }

    Home {
        anchors.fill: parent
        visible: store.loaded && !root.showOnboarding
        store: store
        onSend: root.openSheet("send")
        onReceive: root.openSheet("receive")
        onAccounts: root.openSheet("accounts")
        onSettings: root.openSheet("settings")
        onFunds: {
            var acct = store.current
            if (!acct) return
            // A private account is funded in two steps with a proof: say so first.
            if (acct.kind === "private") root.openSheet("privateFunds")
            else root.requestFunds()
        }
        onPrivateInfo: root.openSheet("privateAbout")
        onOpenToken: function (d) { root.showToken(d) }
        onTokensMore: root.openSheet("tokensMore")
        onTokensManage: root.openSheet("tokensManage")
        onOpenStatus: function (s) {
            if (s.lifecycle === "awaiting_approval") return
            root.proofHandle = s.handle
            root.openSheet("proof")
        }
    }

    Island {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        z: 40
        status: store.active
        visible: store.unlocked && root.sheet === "" && !root.showOnboarding && opacity > 0
        onClicked: { root.proofHandle = store.active.handle; root.openSheet("proof") }
    }

    // -- the sheet layer ---------------------------------------------------------------------
    TraySheet {
        id: sheetLayer
        open: root.sheet !== "" && store.unlocked
        stepKey: root.sheet + ":" + sendFlow.step + ":" + createToken.step + ":" + root.tokenFocus
        dir: sendFlow.dir
        first: root.sheet === "send" ? sendFlow.first : root.sheet === "tokenCreate" ? createToken.first : true
        busy: sendFlow.busy || intentView.busy || pendingView.busy || createToken.busy
        onCloseRequested: root.closeSheet()
        onBackRequested: {
            if (root.sheet === "send") sendFlow.back()
            else if (root.sheet === "tokenCreate") createToken.back()
        }

        Item {
            width: sheetLayer.innerWidth
            implicitHeight: {
                switch (root.sheet) {
                case "send": return sendFlow.implicitHeight
                case "receive": return receiveView.implicitHeight
                case "accounts": return accountsView.implicitHeight
                case "settings": return settingsView.implicitHeight
                case "proof": return proofView.implicitHeight
                case "privateAbout": case "privateFunds": return privateSheet.implicitHeight
                case "tokenDetail": return tokenDetail.implicitHeight
                case "tokensMore": return tokensMore.implicitHeight
                case "tokensManage": return manageTokens.implicitHeight
                case "tokenAdd": return addToken.implicitHeight
                case "tokenCreate": return createToken.implicitHeight
                case "intent": return intentView.implicitHeight
                case "pending": return pendingView.implicitHeight
                }
                return 0
            }
            SendFlow {
                id: sendFlow
                visible: root.sheet === "send"
                width: parent.width
                store: store
                onTicketChanged: if (ticket) { var o = root.ownTickets; o[ticket.handle] = true; root.ownTickets = o }
                onFinished: root.closeSheet()
            }
            ReceiveView { id: receiveView; visible: root.sheet === "receive"; width: parent.width; store: store }
            AccountsView { id: accountsView; visible: root.sheet === "accounts"; width: parent.width; store: store; onPicked: root.sheet = "" }
            SettingsView { id: settingsView; visible: root.sheet === "settings"; width: parent.width; store: store }
            TokenDetail {
                id: tokenDetail
                visible: root.sheet === "tokenDetail"
                width: parent.width
                store: store
                definition: root.tokenFocus
                onSend: function (d) { sendFlow.reset(); sendFlow.token = d; root.openSheet("send") }
                onReceive: root.openSheet("receive")
                onClose: root.sheet = ""
            }
            TokensMore {
                id: tokensMore
                visible: root.sheet === "tokensMore"
                width: parent.width
                store: store
                onOpenToken: function (d) { root.showToken(d) }
            }
            ManageTokens {
                id: manageTokens
                visible: root.sheet === "tokensManage"
                width: parent.width
                store: store
                onAddToken: function (prefill) { addToken.reset(); addToken.tokenId = prefill; root.openSheet("tokenAdd") }
                onCreateToken: { createToken.reset(); root.openSheet("tokenCreate") }
                onOpenToken: function (d) { root.showToken(d) }
            }
            AddToken {
                id: addToken
                visible: root.sheet === "tokenAdd"
                width: parent.width
                store: store
                onAdded: function (d) { root.showToken(d) }
                onOpenToken: function (d) { root.showToken(d) }
            }
            CreateToken {
                id: createToken
                visible: root.sheet === "tokenCreate"
                width: parent.width
                store: store
                onFinished: function (d) { root.showToken(d) }
            }
            PrivateInfo {
                id: privateSheet
                visible: root.sheet === "privateAbout" || root.sheet === "privateFunds"
                width: parent.width
                store: store
                funding: root.sheet === "privateFunds"
                onClose: root.sheet = ""
                onProceed: { root.sheet = ""; root.requestFunds() }
            }
            ProofView { id: proofView; visible: root.sheet === "proof"; width: parent.width; store: store; handle: root.proofHandle; onClose: root.sheet = "" }
            IntentView {
                id: intentView
                visible: root.sheet === "intent"
                width: parent.width
                store: store
                onTicketChanged: if (ticket) { var o = root.ownTickets; o[ticket.handle] = true; root.ownTickets = o }
                onFinished: root.sheet = ""
            }
            // A request an app made directly (lez_signAndSendTransaction), or
            // the shield after test funds for a private account.
            ColumnLayout {
                id: pendingView
                property bool busy: false
                property string problem: ""
                property string handle: ""
                visible: root.sheet === "pending"
                width: parent.width
                ApprovalView {
                    visible: pendingView.handle === ""
                    Layout.fillWidth: true
                    store: store
                    ticket: store.pending && store.pending.request && store.pending.request.type === "transaction" ? store.pending : null
                    busy: pendingView.busy
                    problem: pendingView.problem
                    onApprove: function (password, ack) {
                        var t = store.pending
                        pendingView.busy = true
                        pendingView.problem = ""
                        store.call("approve", { handle: t.handle, requestHash: t.request.requestHash, password: password || null, acknowledged: ack }, function (v, e) {
                            pendingView.busy = false
                            if (e) { pendingView.problem = Fmt.errorText(e); return }
                            pendingView.handle = t.handle
                            store.watching = t.handle
                            store.refreshAll()
                        }, 20000)
                    }
                    onReject: {
                        if (store.pending) store.call("reject", { handle: store.pending.handle }, function () { store.refreshAll() })
                        root.sheet = ""
                    }
                }
                ProofView {
                    visible: pendingView.handle !== ""
                    Layout.fillWidth: true
                    store: store
                    handle: pendingView.handle
                    onClose: { pendingView.handle = ""; root.sheet = "" }
                }
            }
        }
    }

    // -- toasts (kit ToastHost: Sonner-style stack) -----------------------------------------------
    ToastHost { id: toasts; anchors.fill: parent; z: 60 }
}
