import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt
import "../LogosKitUi/Units.js" as Units

// Following one request after approval (ux-spec §7), after Phantom's
// "Sending…" (Refero flow 3718, step 9): a centred ring with the elapsed time,
// the title and what is being sent, the phases under it, then the honest
// outcome with a green check.
ColumnLayout {
    id: pv
    property var store
    property string handle: ""
    signal close()

    width: parent ? parent.width : 400
    spacing: 12

    readonly property var s: store.statusOf(handle) || ({ lifecycle: "building" })
    readonly property bool priv: !!s.route && s.route !== "public"
    readonly property bool final_: Fmt.isFinal(s)
    readonly property bool failed: s.lifecycle === "dropped" || s.lifecycle === "expired" || s.lifecycle === "rejected"
                                   || (s.lifecycle === "included" && s.outcome === "failure")
    readonly property var phases: pv.priv ? ["building", "proving", "signing", "submitted"] : ["signing", "submitted"]
    readonly property var labels: ({ "building": "Preparing", "proving": "Proving on this device", "signing": "Signing and sending", "submitted": "Waiting for a block" })

    // -- in progress -------------------------------------------------------------
    ColumnLayout {
        id: running
        visible: !pv.final_
        Layout.fillWidth: true
        spacing: 12
        // The ring: elapsed time in the middle; a proof shows its estimate.
        readonly property real elapsedS: Math.max(0, ((pv.s.nowMs || Date.now()) - (pv.s.phaseStartedMs || Date.now())) / 1000)
        ProgressRing {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            size: 96
            thickness: 6
            color: Theme.text
            track: Theme.surface2
            indeterminate: !(pv.s.lifecycle === "proving" && pv.s.etaSeconds > 0)
            value: pv.s.etaSeconds > 0 ? Math.min(0.95, running.elapsedS / (running.elapsedS + pv.s.etaSeconds)) : 0
            Txt { text: Fmt.mmss(running.elapsedS); num: true; font.pixelSize: 16; font.weight: Font.DemiBold }
        }
        Txt {
            Layout.fillWidth: true
            Layout.topMargin: 6
            horizontalAlignment: Text.AlignHCenter
            text: pv.s.lifecycle === "proving" ? "Proving privately…" : pv.priv ? "Sending privately…" : "Sending…"
            font.pixelSize: 22; font.weight: Font.Bold
        }
        Txt { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: pv.s.title || ""; tone: "text2"; font.pixelSize: 14; wrapMode: Text.Wrap; elide: Text.ElideNone }

        Pipeline {
            Layout.fillWidth: true
            Layout.topMargin: 4
            accent: Theme.text
            stages: {
                var at = pv.phases.indexOf(pv.s.lifecycle)
                var out = [{ label: "Approved", status: "done" }]
                for (var i = 0; i < pv.phases.length; i++) {
                    var ph = pv.phases[i]
                    var st = at > i ? "done" : at === i ? "active" : "pending"
                    var o = { label: pv.labels[ph], status: st }
                    if (st === "active") {
                        o.elapsed = Fmt.mmss(Math.max(0, ((pv.s.nowMs || Date.now()) - pv.s.phaseStartedMs) / 1000))
                        o.progress = -1
                        if (ph === "proving") {
                            o.detail = "Keeps the amount and recipient private. You can close this."
                            o.estimate = pv.s.etaSeconds > 0 ? "About " + Fmt.mmss(pv.s.etaSeconds) + " left" : "Taking longer than usual"
                        }
                    }
                    out.push(o)
                }
                out.push({ label: "Included in a block", status: "pending" })
                return out
            }
        }
        Txt {
            visible: pv.priv
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            tone: "text3"
            font.pixelSize: 12
            text: "Normal for private sends: your keys never leave this device. You can close this; the proof keeps running."
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Btn {
                visible: pv.s.lifecycle === "proving"
                objectName: "cancelProof"
                Layout.fillWidth: true
                tone: "ghost"
                text: "Cancel"
                onClicked: pv.store.call("cancel", { handle: pv.handle }, null)
            }
            Btn { objectName: "keepRunning"; Layout.fillWidth: true; text: "Keep running in background"; onClicked: pv.close() }
        }
    }

    // -- done ---------------------------------------------------------------------
    ColumnLayout {
        visible: pv.final_
        Layout.fillWidth: true
        spacing: 10
        SuccessCheck { visible: pv.final_ && !pv.failed && pv.s.outcome === "success"; Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 12; size: 80; color: Theme.ok }
        Rectangle {
            visible: !(pv.final_ && !pv.failed && pv.s.outcome === "success")
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            implicitWidth: 64; implicitHeight: 64; radius: 32
            readonly property color c: pv.failed ? Theme.danger : pv.s.outcome === "success" ? Theme.ok : Theme.warn
            color: Theme.soft(c, 0.16)
            Glyph { anchors.centerIn: parent; name: pv.failed ? "x" : pv.s.outcome === "success" ? "check" : "info"; color: parent.c; width: 30; height: 30; stroke: 2.4 }
            scale: pv.final_ ? 1 : 0.4
            Behavior on scale { enabled: !Theme.reducedMotion; NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
        }
        Txt {
            objectName: "outcomeTitle"
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: 24; font.weight: Font.Bold
            text: pv.s.lifecycle === "dropped" && pv.s.errorCode === 6102 ? "Proof failed"
                : pv.failed ? (Fmt.LIFECYCLE[pv.s.lifecycle] || "Failed")
                : pv.s.incoming ? (pv.priv ? "Received privately" : "Received")
                : pv.s.outcome === "success" ? (pv.priv ? "Sent privately" : "Sent!")
                : "Not confirmed yet"
        }
        Txt {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            tone: "text2"
            font.pixelSize: 13
            text: pv.s.lifecycle === "dropped" ? (pv.s.errorCode === 6102 ? "The transaction wasn't sent. Nothing was spent." : (pv.s.error || "The transaction wasn't sent."))
                : pv.s.lifecycle === "included" && pv.s.outcome !== "success" && pv.s.outcome !== "failure"
                  ? "Included in block " + Fmt.amount(String(pv.s.block || ""), 0) + " but not confirmed. Logos Kit couldn't verify the result."
                : pv.s.lifecycle === "included" ? (pv.s.block ? "In block " + Fmt.amount(String(pv.s.block), 0) + "." : "Included in a block.")
                : (pv.s.error || "")
        }
        // What the network charged (public sends; private ones are fee-exempt).
        Txt {
            objectName: "feePaid"
            visible: !!pv.s.feePaid && pv.s.outcome === "success"
            Layout.alignment: Qt.AlignHCenter
            tone: "text3"
            font.pixelSize: 13
            text: "Network fee paid " + Units.lgoLabel(pv.s.feePaid || "0")
        }
        Rectangle {
            visible: !!pv.s.txHash
            Layout.fillWidth: true
            implicitHeight: 42
            radius: Theme.rRow
            color: Theme.surface2
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 6
                Txt { Layout.fillWidth: true; text: Fmt.shortHash(pv.s.txHash); mono: true; font.pixelSize: 12; tone: "text2" }
                IconButton { glyph: "copy"; label: "Copy transaction hash"; onClicked: pv.store.copy(pv.s.txHash) }
            }
        }
        Btn {
            objectName: "openExplorer"
            visible: !!pv.s.txHash && !!pv.store.state.explorer
            Layout.fillWidth: true
            Layout.topMargin: 8
            icon: "external"
            text: "View in explorer"
            onClicked: pv.store.call("openExplorer", { chain: pv.s.chain, txHash: pv.s.txHash }, function (v, e) { if (e) pv.store.toast(Fmt.errorText(e), "danger") })
        }
        Btn { objectName: "proofDone"; Layout.fillWidth: true; Layout.topMargin: pv.s.txHash ? 0 : 8; large: true; tone: "ink"; text: "Done"; onClicked: pv.close() }
    }
}
