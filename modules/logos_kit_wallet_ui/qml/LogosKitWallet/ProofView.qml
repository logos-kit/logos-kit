import QtQuick
import QtQuick.Layouts
import "Fmt.js" as Fmt

// Following one request after approval (ux-spec §7): the ring and phases for
// a private route, a short wait for a public one, then the honest outcome.
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
    readonly property int pct: Math.round(Fmt.proofProgress(s) * 100)
    readonly property var phases: pv.priv ? ["building", "proving", "signing", "submitted"] : ["signing", "submitted"]
    readonly property var labels: ({ "building": "Preparing", "proving": "Generating proof", "signing": "Submitting", "submitted": "Waiting for block" })

    // -- in progress -------------------------------------------------------------
    ColumnLayout {
        visible: !pv.final_
        Layout.fillWidth: true
        spacing: 12
        Txt { Layout.fillWidth: true; text: pv.priv ? "Sending privately" : "Sending"; font.pixelSize: 20; font.weight: Font.DemiBold }
        Txt { Layout.fillWidth: true; text: pv.s.title || ""; tone: "text2"; font.pixelSize: 13; wrapMode: Text.Wrap }

        Item {
            visible: pv.priv
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 150; implicitHeight: 150
            Ring { anchors.centerIn: parent; value: pv.pct / 100; size: 148; thickness: 10 }
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                Txt { Layout.alignment: Qt.AlignHCenter; text: pv.pct + "%"; font.pixelSize: 30; font.weight: Font.Bold; num: true }
                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    tone: "text2"; font.pixelSize: 12
                    text: pv.s.lifecycle === "proving" ? (pv.s.etaSeconds > 0 ? "about " + Fmt.mmss(pv.s.etaSeconds) + " left" : "Taking longer than usual…") : ""
                }
            }
        }
        Spinner { visible: !pv.priv; Layout.alignment: Qt.AlignHCenter; size: 36; color: Theme.action }

        Repeater {
            model: pv.phases
            RowLayout {
                spacing: 10
                readonly property int at: pv.phases.indexOf(pv.s.lifecycle)
                readonly property string st: at > index ? "done" : at === index ? "now" : "todo"
                Rectangle {
                    implicitWidth: 20; implicitHeight: 20; radius: 10
                    color: parent.st === "done" ? Theme.soft(Theme.ok, 0.18) : parent.st === "now" ? Theme.priv : Theme.surface2
                    Glyph { anchors.centerIn: parent; visible: parent.parent.st === "done"; name: "check"; color: Theme.ok; width: 12; height: 12; stroke: 2.6 }
                    Rectangle { anchors.centerIn: parent; visible: parent.parent.st === "now"; width: 6; height: 6; radius: 3; color: "#ffffff" }
                }
                Txt {
                    text: pv.labels[modelData]
                    tone: parent.st === "todo" ? "text3" : "text"
                    font.pixelSize: 13
                    font.weight: parent.st === "now" ? Font.DemiBold : Font.Normal
                }
            }
        }
        Notice {
            visible: pv.priv
            text: "This is normal for private transactions. Your keys never leave this device. You can close this: the proof keeps running and the balance updates when it's sent."
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
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            implicitWidth: 64; implicitHeight: 64; radius: 32
            readonly property color c: pv.failed ? Theme.danger : pv.s.outcome === "success" ? Theme.ok : Theme.warn
            color: Theme.soft(c, 0.16)
            Glyph { anchors.centerIn: parent; name: pv.failed ? "x" : pv.s.outcome === "success" ? "check" : "info"; color: parent.c; width: 30; height: 30; stroke: 2.4 }
            scale: pv.final_ ? 1 : 0.4
            Behavior on scale { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
        }
        Txt {
            objectName: "outcomeTitle"
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: 20; font.weight: Font.DemiBold
            text: pv.s.lifecycle === "dropped" && pv.s.errorCode === 6102 ? "Proof failed"
                : pv.failed ? (Fmt.LIFECYCLE[pv.s.lifecycle] || "Failed")
                : pv.s.outcome === "success" ? (pv.priv ? "Sent privately" : "Confirmed")
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
                : pv.s.lifecycle === "included" ? "In block " + Fmt.amount(String(pv.s.block || ""), 0) + "."
                : (pv.s.error || "")
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
                IconBtn { icon: "copy"; label: "Copy transaction hash"; onClicked: pv.store.copy(pv.s.txHash) }
            }
        }
        Btn { objectName: "proofDone"; Layout.fillWidth: true; large: true; text: "Done"; onClicked: pv.close() }
    }
}
