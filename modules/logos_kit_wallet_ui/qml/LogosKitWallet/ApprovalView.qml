import QtQuick
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
        Rectangle {
            implicitWidth: 44; implicitHeight: 44; radius: 14; color: "#232329"
            border.width: 1; border.color: "#1affffff"
            Txt { anchors.centerIn: parent; color: "#ffffff"; font.pixelSize: 15; font.weight: Font.DemiBold; text: av.requester.substring(0, 2).toUpperCase() }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { text: "Requested by"; tone: "text2"; font.pixelSize: 12 }
            Txt { objectName: "requesterName"; Layout.fillWidth: true; text: av.requester; mono: true; font.pixelSize: 14; font.weight: Font.DemiBold }
        }
    }
    Notice { visible: av.requester !== ""; tone: "warn"; text: "Unsigned app: Basecamp can't confirm who published it. It can never move funds without your approval." }

    Txt { Layout.fillWidth: true; text: av.summary.title || "Review"; font.pixelSize: 20; font.weight: Font.DemiBold; wrapMode: Text.Wrap }

    // -- balance change first ------------------------------------------------------
    Rectangle {
        visible: av.outNative !== "" || av.outToken !== ""
        Layout.fillWidth: true
        implicitHeight: 70
        radius: Theme.rCard
        color: Theme.surface2
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            LezToken { size: 38; visible: av.outToken === "" }
            Identicon { visible: av.outToken !== ""; seed: av.intent.token || ""; size: 38; square: true }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Txt {
                    text: (av.fromAccount && av.fromAccount.kind === "private" ? "Your private balance changes" : "Your balance changes")
                    tone: "text2"; font.pixelSize: 12
                }
                Txt {
                    text: "− " + Fmt.amount(av.outToken !== "" ? av.outToken : av.outNative, 0) + (av.outToken !== "" ? "" : " LEZ")
                    color: Theme.danger; font.pixelSize: 22; font.weight: Font.DemiBold; num: true
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        InfoRow { label: "From"; value: av.fromAccount ? Fmt.accountName(av.fromAccount) : Fmt.short(av.intent.from) }
        InfoRow {
            visible: !!av.review.recipient
            readonly property var own: {
                for (var i = 0; i < av.store.accounts.length; i++)
                    if (av.store.accounts[i].accountId === av.review.recipient) return av.store.accounts[i]
                return null
            }
            label: "To"
            value: own ? Fmt.accountName(own) : Fmt.short(av.review.recipient)
            mono: !own
        }
        InfoRow {
            visible: av.route !== ""
            label: "Visibility"
            value: av.route === "public" ? "Visible on-chain: amount and both accounts"
                 : av.route === "shield" ? "Into your private account; the amount is visible"
                 : av.route === "unshield" ? "Leaves your private account publicly"
                 : "Private: nothing about this transfer is visible"
            tone: av.isPrivate ? "priv" : "text"
        }
        InfoRow {
            visible: av.program !== null
            label: "Program"
            value: av.program ? (av.program.name || "Unknown program") + " · " + Fmt.short(av.program.account) : ""
        }
        InfoRow {
            visible: av.program !== null
            label: "Source"
            Tag { text: av.badge(av.program)[0]; tone: av.badge(av.program)[1] }
        }
        InfoRow {
            visible: av.program !== null && !av.program.builtin
            label: "Upgrades"
            value: av.program && av.program.immutable ? "Immutable" : "Upgradeable by its owner"
            tone: av.program && av.program.immutable ? "text" : "warn"
        }
        InfoRow { visible: av.isPrivate; label: "Proof"; value: "Runs on this device · about " + (av.route === "shield" ? "5–6" : "6–8") + " min" }
        InfoRow {
            label: "Network fee"
            value: av.review.fee && av.review.fee.maxFee ? "≤ " + Fmt.amount(av.review.fee.maxFee, 0) + " LEZ"
                 : av.isPrivate ? "None: private transactions are fee-exempt"
                 : "Fee estimate unavailable"
        }
    }

    Repeater {
        model: av.summary.lines || []
        Txt { Layout.fillWidth: true; text: "· " + modelData; tone: "text2"; font.pixelSize: 13; wrapMode: Text.Wrap }
    }
    Repeater {
        model: av.summary.authorities || []
        Notice { tone: "warn"; icon: "warning"; text: "Authority change: " + modelData }
    }

    // -- details ---------------------------------------------------------------------
    Txt {
        text: details.visible ? "Hide details" : "Details"
        tone: "action"
        font.pixelSize: 13
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: details.visible = !details.visible }
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
    RowLayout {
        visible: !!av.summary.unknown
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            id: ack
            objectName: "ackUnknown"
            property bool checked: false
            implicitWidth: 22; implicitHeight: 22; radius: 7
            color: checked ? Theme.danger : "transparent"
            border.width: checked ? 0 : 2
            border.color: Theme.text3
            Glyph { anchors.centerIn: parent; visible: ack.checked; name: "check"; color: "#ffffff"; width: 14; height: 14; stroke: 2.6 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ack.checked = !ack.checked }
        }
        Txt { Layout.fillWidth: true; text: "I understand Logos Kit can't describe what this does."; font.pixelSize: 13; wrapMode: Text.Wrap }
    }

    Field {
        id: pw
        objectName: "approvePassword"
        visible: !!av.ticket && av.ticket.needsPassword
        Layout.fillWidth: true
        echoMode: TextInput.Password
        placeholderText: "Password"
        onAccepted: approveBtn.clicked()
    }

    Txt { visible: av.problem !== ""; objectName: "approvalProblem"; Layout.fillWidth: true; text: av.problem; tone: "danger"; font.pixelSize: 13; wrapMode: Text.Wrap }

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
