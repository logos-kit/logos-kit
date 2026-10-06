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
    property var store: null

    readonly property bool priv: !!tx.route && tx.route !== "public"
    readonly property bool final_: Fmt.isFinal(status)
    readonly property string t: (tx.title || "").toLowerCase()

    kind: tx.incoming ? (t.indexOf("test lgo") === 0 ? "faucet" : "receive")
        : t.indexOf("connect") === 0 ? "call"
        : t.indexOf("testimonial") >= 0 ? "testimonial"
        : tx.route === "shield" ? "shield"
        : tx.route === "unshield" ? "unshield" : "send"
    title: tx.title || "Transaction"
    isPrivate: priv
    // Native amounts are lepta, shown in LGO; tokens have no decimals.
    amount: !tx.amount ? "" : tx.token ? Units.group(tx.amount) : Units.lgo(tx.amount)
    symbol: !tx.token ? Units.SYMBOL : store ? store.tokenName(tx.token) : Fmt.short(tx.token)
    status: tx.lifecycle === "rejected" || tx.lifecycle === "expired" ? "declined"
          : tx.lifecycle === "dropped" || tx.outcome === "failure" ? "failed"
          : tx.lifecycle === "included" ? (tx.outcome === "success" ? "included" : "unconfirmed")
          : "pending"
    // Apps by their own display name (Store.appInfo), never the module id.
    readonly property string asker: !tx.requester ? "" : store ? store.appName(tx.requester) : tx.requester
    sub: tx.incoming ? (tx.from ? "From " + Fmt.short(tx.from) + " · " : tx.route === "private" ? "From a private account · " : "") + Fmt.ago(tx.phaseStartedMs, tx.nowMs)
       : tx.lifecycle === "rejected" ? "Declined" + (asker ? " · asked by " + asker : "")
       : tx.lifecycle === "expired" ? "Expired"
       : tx.lifecycle === "proving" ? "Proving on this device · about " + Fmt.mmss(tx.etaSeconds) + " left"
       : tx.lifecycle === "signing" ? "Signing"
       : tx.lifecycle === "submitted" ? "Waiting for a block"
       : (asker ? "Asked by " + asker + " · " : "") + Fmt.ago(tx.phaseStartedMs, tx.nowMs)
    Component.onCompleted: if (store && tx.requester) store.loadApp(tx.requester)
}
