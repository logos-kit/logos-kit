import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt

// The approval sheet body for a transaction ticket (ux-spec §6): who asks,
// what is signed, what it means. Balance change first (Tray review). Every
// string from an app or a program is plain text.
ColumnLayout {
    id: av
    property var store
    property var ticket: null
    property bool busy: false
    property string problem: ""
    signal approve(string password, bool acknowledged)
    signal reject()

    width: parent ? parent.width : 400
    spacing: 10

    readonly property var review: ticket && ticket.request ? ticket.request : ({})
    readonly property var summary: review.summary || ({})
    readonly property var intent: review.intent || ({})
    readonly property var program: review.program || null
    readonly property string requester: review.requester || ""
    readonly property string route: review.route || ""
    readonly property bool isPrivate: route !== "" && route !== "public"
    readonly property var fromAccount: {
        for (var i = 0; i < store.accounts.length; i++)
            if (store.accounts[i].accountId === intent.from) return store.accounts[i]
        return null
    }
    // Native value leaving the sending account (the first number the user sees).
    readonly property string outNative: {
        var outs = summary.outflows || []
        for (var i = 0; i < outs.length; i++)
            if (outs[i].asset && outs[i].asset.kind === "native" && outs[i].account === intent.from) return outs[i].amount
        return intent.kind === "transfer" && !intent.token ? (intent.amount || "") : ""
    }
    readonly property string outToken: intent.kind === "transfer" && intent.token ? intent.amount : ""

    function badge(p) {
        if (!p) return ["", "pending"]
        if (p.status === "verified_local") return ["Verified source", "ok"]
        if (p.status === "claimed") return ["Claimed, not rebuilt", "unconfirmed"]
        if (p.status === "mismatch") return ["Mismatch", "danger"]
        return ["Unknown source", "pending"]
    }

    // -- requested by ------------------------------------------------------------
    RowLayout {
        visible: av.requester !== ""
        Layout.fillWidth: true
        spacing: 12
        AppAvatar { store: av.store; requester: av.requester; size: 44 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { text: "Requested by"; tone: "text2"; font.pixelSize: 12 }
            Txt { Layout.fillWidth: true; visible: av.store.appName(av.requester) !== av.requester; text: av.store.appName(av.requester); font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Txt { objectName: "requesterName"; Layout.fillWidth: true; text: av.requester; mono: true; tone: av.store.appName(av.requester) !== av.requester ? "text3" : "text"; font.pixelSize: av.store.appName(av.requester) !== av.requester ? 12 : 14; font.weight: av.store.appName(av.requester) !== av.requester ? Font.Normal : Font.DemiBold }
        }
    }
    Notice { visible: av.requester !== ""; tone: "warn"; text: "Unsigned app: Basecamp can't confirm who published it. It can never move funds without your approval." }

    Txt { Layout.fillWidth: true; text: av.summary.title || "Review"; font.pixelSize: 20; font.weight: Font.Bold; wrapMode: Text.Wrap; elide: Text.ElideNone }

    // -- who gets what, first (TxSummary: asset + amount + full destination,
    //    then effects and authority, then fee cap and source) ----------------
    readonly property var ownRecipient: {
        for (var i = 0; i < store.accounts.length; i++)
            if (store.accounts[i].accountId === review.recipient) return store.accounts[i]
        return null
    }
    readonly property var tokenInfo: {
        if (!intent.token || !fromAccount) return null
        var ts = fromAccount.tokens || []
        for (var i = 0; i < ts.length; i++) if (ts[i].definition === intent.token) return ts[i]
        return null
    }
    TxSummary {
        Layout.fillWidth: true
        isPrivate: av.isPrivate
        outflow: av.outNative !== "" ? ({ amount: av.outNative, symbol: "LEZ" })
               : av.outToken !== "" ? ({ amount: av.outToken, symbol: av.tokenInfo && av.tokenInfo.name ? av.tokenInfo.name : Fmt.short(av.intent.token), definition: av.intent.token })
               : null
        to: !av.review.recipient ? null : ({
            name: av.ownRecipient ? Fmt.accountName(av.ownRecipient) + " (yours)" : "",
            address: av.review.recipient,
            kind: (av.ownRecipient && av.ownRecipient.kind === "private") || (av.intent.toKeys && av.route !== "public") ? "private" : "public"
        })
        effects: av.summary.lines || []
        authority: (av.summary.authorities || []).map(function (a) { return "Authority change: " + a })
        fee: av.review.fee && av.review.fee.maxFee ? ({ cap: av.review.fee.maxFee }) : null
        program: !av.program ? null : ({
            name: (av.program.name || "Unknown program") + " · " + Fmt.short(av.program.account),
            status: av.program.status === "verified_local" ? "verified" : av.program.status === "claimed" ? "claimed" : "unknown",
            immutable: av.program.builtin || av.program.immutable
        })
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        InfoRow { label: "From"; value: av.fromAccount ? Fmt.accountName(av.fromAccount) + (av.fromAccount.kind === "private" ? " · private" : " · public") : Fmt.short(av.intent.from) }
        InfoRow {
            visible: av.route !== ""
            label: "Who can see it"
            value: av.route === "public" ? "Everyone: amount and both accounts"
                 : av.route === "shield" ? "The amount is public; it lands in your private account"
                 : av.route === "unshield" ? "Leaves your private account publicly"
                 : "Nobody: nothing about it is public"
            tone: av.isPrivate ? "priv" : "text"
        }
        InfoRow { visible: av.isPrivate; label: "Proof"; value: "Made on this device · usually " + (av.route === "shield" ? "5–6" : "6–8") + " min" }
        InfoRow { visible: !(av.review.fee && av.review.fee.maxFee); label: "Network fee"; value: av.isPrivate ? "None: private transactions are fee-exempt" : "Not available yet" }
    }

    // -- details ---------------------------------------------------------------------
    Txt {
        text: details.visible ? "Hide technical details" : "Technical details"
        tone: "action"
        font.pixelSize: 13
        font.weight: Font.DemiBold
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: text
        Keys.onReturnPressed: details.visible = !details.visible
        Keys.onSpacePressed: details.visible = !details.visible
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: details.visible = !details.visible }
        FocusRing { anchors.fill: parent; ringRadius: 6 }
    }
    ColumnLayout {
        id: details
        visible: false
        Layout.fillWidth: true
        spacing: 4
        Txt { visible: !!av.program; Layout.fillWidth: true; text: "Image " + (av.program ? av.program.imageId : ""); mono: true; font.pixelSize: 11; tone: "text2"; wrapMode: Text.WrapAnywhere }
        Txt { visible: !!av.program && !!av.program.note; Layout.fillWidth: true; text: av.program ? av.program.note : ""; font.pixelSize: 12; tone: "text2"; wrapMode: Text.Wrap }
        Txt { visible: av.intent.kind === "call"; Layout.fillWidth: true; text: "Data " + (av.intent.data || ""); mono: true; font.pixelSize: 11; tone: "text2"; wrapMode: Text.WrapAnywhere; maximumLineCount: 4; elide: Text.ElideRight }
        Txt { Layout.fillWidth: true; text: "Request " + (av.review.requestHash || ""); mono: true; font.pixelSize: 11; tone: "text3"; wrapMode: Text.WrapAnywhere }
    }

    // -- unknown effects -----------------------------------------------------------------
    Notice { visible: !!av.summary.unknown; tone: "danger"; icon: "warning"; text: "Logos Kit can't read what this program call does. Only approve it if you trust the app completely." }
    CheckRow {
        id: ack
        objectName: "ackUnknown"
        visible: !!av.summary.unknown
        accent: Theme.danger
        text: "I understand Logos Kit can't describe what this does."
    }

    Field {
        id: pw
        objectName: "approvePassword"
        visible: !!av.ticket && av.ticket.needsPassword
        Layout.fillWidth: true
        echoMode: TextInput.Password
        placeholderText: "Password to approve"
        onAccepted: approveBtn.clicked()
    }

    Notice { visible: av.problem !== ""; objectName: "approvalProblem"; Layout.fillWidth: true; text: av.problem; tone: "danger" }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8
        Btn { objectName: "reject"; Layout.fillWidth: true; large: true; text: "Reject"; enabled: !av.busy; onClicked: av.reject() }
        Btn {
            id: approveBtn
            objectName: "approve"
            Layout.fillWidth: true
            large: true
            tone: "ink"
            icon: av.isPrivate ? "lock" : ""
            text: av.isPrivate ? "Prove and send" : av.requester !== "" ? "Approve" : "Send"
            armDelay: 500
            busy: av.busy
            enabled: (!av.ticket || !av.ticket.needsPassword || pw.text.length > 0) && (!av.summary.unknown || ack.checked)
            onClicked: { av.approve(pw.text, ack.checked); pw.text = "" }
        }
    }
}
