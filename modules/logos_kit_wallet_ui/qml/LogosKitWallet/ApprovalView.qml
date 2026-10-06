import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt
import "../LogosKitUi/Units.js" as Units

// The approval sheet body for a transaction ticket (ux-spec §6), after
// Family's send confirm (Refero flow 2707, step 10): who asks in one line, a
// big "Send X to Y" title, the amount and the full destination, short rows,
// a one-line warning, then the actions. Every string from an app or a
// program is plain text.
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

    // -- requested by (one line, Glow's connect header) -------------------------------
    RowLayout {
        visible: av.requester !== ""
        Layout.fillWidth: true
        spacing: 10
        AppAvatar { store: av.store; requester: av.requester; size: 32 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Txt { Layout.fillWidth: true; text: av.store.appName(av.requester) + " wants you to approve"; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Txt { objectName: "requesterName"; Layout.fillWidth: true; text: av.requester; mono: true; tone: "text3"; font.pixelSize: 11 }
        }
    }
    RowLayout {
        visible: av.requester !== ""
        Layout.fillWidth: true
        spacing: 6
        Glyph { name: "shield"; color: Theme.text3; width: 14; height: 14 }
        Txt {
            objectName: "requesterTrust"
            Layout.fillWidth: true
            text: av.store.appSigned(av.requester)
                ? "Installed from a signed package. It can't move funds without you."
                : "Unsigned app: Basecamp can't confirm its publisher. It can't move funds without you."
            tone: "text3"; font.pixelSize: 12; wrapMode: Text.Wrap; elide: Text.ElideNone
        }
    }

    // The big line (Family: "Confirm transaction to 0x1f05…").
    readonly property string toName: ownRecipient ? Fmt.accountName(ownRecipient) : recipient !== "" ? Fmt.short(recipient) : ""
    readonly property string figure: !outFlow ? "" : (outFlow.definition ? Units.group(outFlow.amount) + " " + outFlow.symbol : Units.lgoLabel(outFlow.amount))
    Txt {
        Layout.fillWidth: true
        Layout.topMargin: 6
        text: av.outFlow && av.toName !== ""
              ? (av.route === "shield" ? "Move " + av.figure + " into " + av.toName
                 : av.route === "unshield" ? "Move " + av.figure + " out to " + av.toName
                 : "Send " + av.figure + " to " + av.toName)
              : (av.summary.title || "Review")
        font.pixelSize: 24
        font.weight: Font.Bold
        lineHeight: 1.1
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    // -- who gets what, first (TxSummary: asset + amount + full destination,
    //    then effects and authority, then fee cap and source) ----------------
    // The recipient: the engine's own for transfers; for an app's call, the
    // account the decoded outflow lands in (shown in full, never shortened).
    readonly property string recipient: {
        if (review.recipient) return review.recipient
        var ins = summary.inflows || []
        for (var i = 0; i < ins.length; i++) if (ins[i].account !== intent.from) return ins[i].account
        return ""
    }
    readonly property var ownRecipient: {
        for (var i = 0; i < store.accounts.length; i++)
            if (store.accounts[i].accountId === recipient) return store.accounts[i]
        return null
    }
    readonly property var tokenInfo: {
        if (!intent.token || !fromAccount) return null
        var ts = fromAccount.tokens || []
        for (var i = 0; i < ts.length; i++) if (ts[i].definition === intent.token) return ts[i]
        return null
    }
    function tokenNamed(def) {
        var ts = fromAccount ? (fromAccount.tokens || []) : []
        for (var i = 0; i < ts.length; i++) if (ts[i].definition === def) return ts[i]
        return null
    }
    // What leaves the sending account, for any asset: a token transfer an app
    // proposes arrives as a call, and its decoded outflow is all there is.
    readonly property var outFlow: {
        var outs = summary.outflows || []
        for (var i = 0; i < outs.length; i++) {
            var o = outs[i]
            if (o.account !== intent.from || !o.asset) continue
            if (o.asset.kind === "native") return { amount: o.amount, symbol: Units.SYMBOL }
            var t = tokenNamed(o.asset.definition)
            return { amount: o.amount, symbol: t && t.name ? t.name : Fmt.short(o.asset.definition), definition: o.asset.definition }
        }
        if (outNative !== "") return { amount: outNative, symbol: Units.SYMBOL }
        if (outToken !== "") return { amount: outToken, symbol: tokenInfo && tokenInfo.name ? tokenInfo.name : Fmt.short(intent.token), definition: intent.token }
        return null
    }
    TxSummary {
        Layout.fillWidth: true
        isPrivate: av.isPrivate
        outflow: av.outFlow
        to: av.recipient === "" ? null : ({
            name: av.ownRecipient ? Fmt.accountName(av.ownRecipient) + " (yours)" : "",
            address: av.recipient,
            kind: (av.ownRecipient && av.ownRecipient.kind === "private") || (av.intent.toKeys && av.route !== "public") ? "private" : "public"
        })
        // A single transfer's decoded line ("5 to CQTd…") repeats the card
        // above. Only then is it dropped: with more than one outflow, or any
        // other line of that shape, every line stays. The engine writes a
        // native amount in lepta ("1500000000 to CQTd…"); it reads in LGO.
        effects: {
            var lines = av.summary.lines || []
            var plain = /^[0-9][0-9,]* (of token \S+ )?to \S+$/
            var hits = lines.filter(function (l) { return plain.test(l) })
            if (av.recipient !== "" && av.outFlow !== null && hits.length === 1 && (av.summary.outflows || []).length === 1)
                lines = lines.filter(function (l) { return l !== hits[0] })
            // With a single outflow the title and the card already say what
            // moves and where: drop lines that only repeat the amount or the
            // destination (the shield's "N into your private account", "to X").
            if (av.outFlow !== null && (av.summary.outflows || []).length <= 1)
                lines = lines.filter(function (l) {
                    return !(av.recipient !== "" && l === "to " + av.recipient) && !/^[0-9]+ (into|nothing|out of)/.test(l)
                })
            // A line led by a bare number is a native amount in lepta.
            return lines.map(function (l) {
                var m = /^([0-9]+)( .*)$/.exec(l)
                return m && l.indexOf(" of token ") < 0 ? Units.lgoLabel(m[1]) + m[2] : l
            })
        }
        authority: (av.summary.authorities || []).map(function (a) { return "Authority change: " + a })
        fee: av.review.fee && av.review.fee.maxFee ? ({ cap: av.review.fee.maxFee, now: av.review.fee.estimate || "", exact: !!av.review.fee.exact }) : null
        // A native transfer runs in the chain itself (no program header),
        // whether the wallet's Send built it or an app proposed it.
        program: !av.program ? (av.outFlow && !av.outFlow.definition
                                ? ({ name: "Native transfer · Built into LEZ", status: "builtin", immutable: true }) : null)
            : ({
            name: (av.program.name || "Unknown program") + " · " + Fmt.short(av.program.account),
            status: av.program.status === "verified_local" ? "verified" : av.program.status === "claimed" ? "claimed"
                  : av.program.status === "mismatch" ? "mismatch" : "unknown",
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
            value: av.route === "public" ? "Everyone"
                 : av.route === "shield" ? "The amount, not where it goes"
                 : av.route === "unshield" ? "The amount and the recipient"
                 : "Only you"
            tone: av.isPrivate ? "priv" : "text"
        }
        InfoRow { visible: av.isPrivate; label: "Proof"; value: "On this device · " + (av.store.state.proofTime || "a few minutes") }
        InfoRow { visible: !(av.review.fee && av.review.fee.maxFee); label: "Network fee"; value: av.isPrivate ? "None (private)" : "Not available yet" }
    }

    // Family's line above the button.
    Txt {
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: "Check the amount and where it goes. Once sent, it can't be undone."
        tone: "text3"
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    // -- details (a quiet disclosure row) ----------------------------------------------
    Item {
        Layout.fillWidth: true
        implicitHeight: 32
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: details.visible ? "Hide technical details" : "Technical details"
        Keys.onReturnPressed: details.visible = !details.visible
        Keys.onSpacePressed: details.visible = !details.visible
        RowLayout {
            anchors.fill: parent
            spacing: 6
            Txt { text: "Technical details"; tone: "text2"; font.pixelSize: 13; font.weight: Font.Medium }
            Glyph { name: details.visible ? "chevronUp" : "chevronDown"; color: Theme.text3; width: 14; height: 14 }
            Item { Layout.fillWidth: true }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: details.visible = !details.visible }
        FocusRing { anchors.fill: parent; ringRadius: 8 }
    }
    ColumnLayout {
        id: details
        objectName: "approvalDetails"
        visible: false
        Layout.fillWidth: true
        spacing: 4
        Txt { visible: !!av.program; Layout.fillWidth: true; text: "Image " + (av.program ? av.program.imageId : ""); mono: true; font.pixelSize: 11; tone: "text2"; wrapMode: Text.WrapAnywhere }
        Txt { visible: !!av.program && !!av.program.note; Layout.fillWidth: true; text: av.program ? av.program.note : ""; font.pixelSize: 12; tone: "text2"; wrapMode: Text.Wrap }
        Txt { visible: av.intent.kind === "call"; Layout.fillWidth: true; text: "Data " + (av.intent.data || ""); mono: true; font.pixelSize: 11; tone: "text2"; wrapMode: Text.WrapAnywhere; maximumLineCount: 4; elide: Text.ElideRight }
        Txt {
            visible: !!(av.review.fee && av.review.fee.maxFee)
            Layout.fillWidth: true
            text: av.review.fee ? "Fee cap " + Units.lgoLabel(av.review.fee.maxFee || "0") + " · gas limit " + (av.review.fee.gasLimit || "–")
                  + (av.review.fee.baseFeeExec ? " · base fee " + av.review.fee.baseFeeExec + " lepta/gas" : "") : ""
            font.pixelSize: 11; tone: "text2"; wrapMode: Text.Wrap
        }
        Txt {
            visible: (av.summary.signers || []).length > 0
            Layout.fillWidth: true
            text: "Signs with " + (av.summary.signers || []).map(function (s) { return Fmt.short(s) }).join(", ")
            mono: true; font.pixelSize: 11; tone: "text2"; wrapMode: Text.WrapAnywhere
        }
        Txt { Layout.fillWidth: true; text: "Request " + (av.review.requestHash || ""); mono: true; font.pixelSize: 11; tone: "text3"; wrapMode: Text.WrapAnywhere }
    }

    // Any public signer besides the sending account approves this too.
    readonly property var extraSigners: (summary.signers || []).filter(function (id) {
        return id !== av.intent.from && !(av.fromAccount && id === av.fromAccount.accountId)
    })
    Notice {
        visible: av.extraSigners.length > 0
        tone: "warn"; icon: "warning"
        text: "This also signs with " + av.extraSigners.map(function (id) { return Fmt.short(id) }).join(", ") + ". Those accounts approve it too."
    }

    // -- unknown effects -----------------------------------------------------------------
    Notice { visible: !!av.summary.unknown; tone: "danger"; icon: "warning"; text: "Logos Kit can't read what this program call does, and the program can move anything the signing accounts hold. Only approve it if you trust the app completely." }
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
