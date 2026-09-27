import QtQuick
import QtQuick.Layouts
import "Fmt.js" as Fmt

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
    readonly property string balance: {
        if (!from) return ""
        if (token === "") return from.native === null || from.native === undefined ? "" : String(from.native)
        var ts = from.tokens || []
        for (var i = 0; i < ts.length; i++) if (ts[i].definition === token) return String(ts[i].amount)
        return "0"
    }
    readonly property string base: Fmt.toBase(amountText, 0)
    readonly property bool tooMuch: base !== "" && balance !== "" && Fmt.cmp(base, balance) > 0
    readonly property bool isCode: to.trim().indexOf("lezpriv1:") === 0
    readonly property bool toValid: isCode || /^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(to.trim())
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
    function reset() { step = "to"; to = ""; token = ""; amountText = ""; ticket = null; handle = ""; problem = ""; busy = false }

    function key(k) {
        var a = amountText
        if (k === "del") a = a.slice(0, -1)
        else if (k === ".") return
        else if (a === "0") a = k
        else a = (a + k).substring(0, 20)
        amountText = a
    }
    Keys.onPressed: function (e) {
        if (step !== "amount") return
        if (e.text >= "0" && e.text <= "9" && e.text.length === 1) { key(e.text); e.accepted = true }
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
            text: sf.from ? "From " + Fmt.accountName(sf.from) + " · " + Fmt.amount(sf.from.native, 0) + " LEZ" : ""
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
            invalid: text.trim() !== "" && !sf.toValid
        }
        Txt { visible: sf.isCode; text: "Private payment: only you and the recipient will see it."; tone: "priv"; font.pixelSize: 12 }
        Txt { text: "Your accounts"; tone: "text3"; font.pixelSize: 12; Layout.topMargin: 4 }
        Repeater {
            model: sf.store.accounts
            Rectangle {
                visible: !sf.from || modelData.accountId !== sf.from.accountId
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.rRow
                color: sf.to === modelData.accountId ? Theme.surface2 : "transparent"
                border.width: 1
                border.color: sf.to === modelData.accountId ? Theme.action : Theme.line
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    Identicon { seed: modelData.accountId; size: 30 }
                    Txt { Layout.fillWidth: true; text: Fmt.accountName(modelData); font.weight: Font.DemiBold }
                    Tag { text: modelData.kind === "private" ? "Private" : "Public"; tone: modelData.kind === "private" ? "private" : "pending" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { toField.text = modelData.accountId } }
            }
        }
        // Asset: native, or a token this account holds.
        Flow {
            visible: sf.from && (sf.from.tokens || []).length > 0
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [{ definition: "", name: "LEZ" }].concat(sf.from ? (sf.from.tokens || []) : [])
                Rectangle {
                    implicitHeight: 30
                    implicitWidth: at.implicitWidth + 22
                    radius: 15
                    color: sf.token === modelData.definition ? Theme.text : Theme.surface2
                    Txt { id: at; anchors.centerIn: parent; text: modelData.name || Fmt.short(modelData.definition); font.pixelSize: 12; font.weight: Font.DemiBold; color: sf.token === modelData.definition ? Theme.bg : Theme.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sf.token = modelData.definition }
                }
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
        Txt { text: "From " + (sf.from ? Fmt.accountName(sf.from) : "") + " · " + Fmt.amount(sf.balance, 0) + " spendable"; tone: "text2"; font.pixelSize: 13 }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Theme.rRow
            color: Theme.surface2
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                Txt { text: "To"; tone: "text2"; font.pixelSize: 13 }
                Txt { Layout.fillWidth: true; text: sf.toLabel; font.weight: Font.DemiBold; font.pixelSize: 13 }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            spacing: 6
            Txt {
                id: amt
                objectName: "sendAmount"
                text: sf.amountText === "" ? "0" : Fmt.amount(sf.amountText, 0)
                font.pixelSize: 50; font.weight: Font.DemiBold; font.letterSpacing: -1.5; num: true
                tone: sf.amountText === "" ? "text3" : "text"
                onTextChanged: if (!Theme.reducedMotion) bump.restart()
                SequentialAnimation {
                    id: bump
                    NumberAnimation { target: amt; property: "scale"; to: 1.06; duration: 60 }
                    NumberAnimation { target: amt; property: "scale"; to: 1; duration: 160; easing.type: Easing.OutBack }
                }
            }
            Txt { text: sf.token === "" ? "LEZ" : "tokens"; tone: "text2"; font.pixelSize: 20; Layout.alignment: Qt.AlignBaseline }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 4
            columnSpacing: 4
            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "max", "0", "del"]
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
                        onClicked: modelData === "max" ? (sf.amountText = sf.balance) : sf.key(modelData)
                    }
                }
            }
        }
        Btn { id: reviewBtn; objectName: "sendReview"; Layout.fillWidth: true; large: true; tone: "ink"; text: "Review"; busy: sf.busy; enabled: sf.base !== "" && !sf.tooMuch; onClicked: sf.prepare() }
        Txt {
            visible: sf.tooMuch
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            tone: "danger"; font.pixelSize: 12
            text: "You have " + Fmt.amount(sf.balance, 0) + " spendable. Lower the amount" + (sf.fromPrivate ? "." : ", or add funds first.")
        }
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

    Txt { visible: sf.problem !== "" && sf.step !== "review"; objectName: "sendProblem"; Layout.fillWidth: true; text: sf.problem; tone: "danger"; font.pixelSize: 13; wrapMode: Text.Wrap }
}
