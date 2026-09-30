import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt
import "../LogosKitUi/Units.js" as Units

// One transaction/request (ux-spec §7) as the kit's ActivityRow. Outcomes
// are honest: "included" only with outcome success; included without proof
// of the outcome is "not confirmed yet"; dropped or failed is "failed".
// A proving row shows the phase and an estimate, never a percent.
ActivityRow {
    id: row
    property var tx: ({})

    readonly property bool priv: !!tx.route && tx.route !== "public"
    readonly property bool final_: Fmt.isFinal(status)
    readonly property string t: (tx.title || "").toLowerCase()

    kind: t.indexOf("connect") === 0 ? "call"
        : t.indexOf("testimonial") >= 0 ? "testimonial"
        : tx.route === "shield" ? "shield"
        : tx.route === "unshield" ? "unshield" : "send"
    title: tx.title || "Transaction"
    isPrivate: priv
    amount: tx.amount ? Units.group(tx.amount) : ""
    symbol: tx.token ? Fmt.short(tx.token) : "LEZ"
    status: tx.lifecycle === "rejected" || tx.lifecycle === "expired" ? "declined"
          : tx.lifecycle === "dropped" || tx.outcome === "failure" ? "failed"
          : tx.lifecycle === "included" ? (tx.outcome === "success" ? "included" : "unconfirmed")
          : "pending"
    sub: tx.lifecycle === "rejected" ? "Declined" + (tx.requester ? " · asked by " + tx.requester : "")
       : tx.lifecycle === "expired" ? "Expired"
       : tx.lifecycle === "proving" ? "Proving on this device · about " + Fmt.mmss(tx.etaSeconds) + " left"
       : tx.lifecycle === "signing" ? "Signing"
       : tx.lifecycle === "submitted" ? "Waiting for a block"
       : (tx.requester ? "Asked by " + tx.requester + " · " : "") + Fmt.ago(tx.phaseStartedMs, tx.nowMs)
}
