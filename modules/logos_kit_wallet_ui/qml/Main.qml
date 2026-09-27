import QtQuick
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
    property string proofHandle: ""
    // Tickets our own flows opened: never shown again as "pending".
    property var ownTickets: ({})
    readonly property bool showOnboarding: !store.unlocked || onboarding.inFlow

    function openSheet(k) { root.sheet = k; store.touch() }
    function closeSheet() {
        if (root.sheet === "intent" && store.intent !== null) intentView.cancel()
        if (root.sheet === "send") sendFlow.back()
        root.sheet = ""
        sendFlow.reset()
    }

    Rectangle { anchors.fill: parent; color: Theme.bg }

    // -- intents and direct requests --------------------------------------------------
    Connections {
        target: store
        function onIntentArrived() { if (store.unlocked) root.sheet = "intent" }
        function onUnlockedChanged() {
            if (store.unlocked && store.intent !== null) root.sheet = "intent"
            if (!store.unlocked && root.sheet !== "") root.sheet = ""
        }
        function onPendingChanged() {
            var p = store.pending
            if (p && root.sheet === "" && store.intent === null && !root.ownTickets[p.handle]) root.sheet = "pending"
        }
        function onToast(text, tone) { toast.show(text) }
    }

    // -- screens -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: !store.loaded && store.unreachable === ""
        Spinner { anchors.centerIn: parent; size: 28 }
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
            store.requestFunds(acct.accountId, function (v, e) { if (e) toast.show(Fmt.errorText(e)) })
        }
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
    Sheet {
        id: sheetLayer
        open: root.sheet !== "" && store.unlocked
        stepKey: root.sheet + ":" + sendFlow.step
        dir: sendFlow.dir
        first: root.sheet !== "send" || sendFlow.first
        busy: sendFlow.busy || intentView.busy || pendingView.busy
        onCloseRequested: root.closeSheet()
        onBackRequested: if (root.sheet === "send") sendFlow.back()

        Item {
            width: sheetLayer.innerWidth
            implicitHeight: {
                switch (root.sheet) {
                case "send": return sendFlow.implicitHeight
                case "receive": return receiveView.implicitHeight
                case "accounts": return accountsView.implicitHeight
                case "settings": return settingsView.implicitHeight
                case "proof": return proofView.implicitHeight
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

    // -- toast ------------------------------------------------------------------------------
    Rectangle {
        id: toast
        property string text: ""
        function show(t) { text = t; opacity = 1; hide.restart() }
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - 24
        z: 60
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        implicitHeight: 36
        width: tt.implicitWidth + 32
        radius: 18
        color: Theme.text
        Txt { id: tt; anchors.centerIn: parent; text: toast.text; color: Theme.bg; font.pixelSize: 13; font.weight: Font.DemiBold }
        Timer { id: hide; interval: 2400; onTriggered: toast.opacity = 0 }
    }
}
