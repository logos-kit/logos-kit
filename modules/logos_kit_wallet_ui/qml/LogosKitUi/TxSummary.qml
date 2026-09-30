import QtQuick
import QtQuick.Layouts
import "Units.js" as Units

// The approval sheet's first card (Codex review §4, P0): WHO RECEIVES WHAT
// comes first and largest: the asset and amount, then the full destination.
// Effects and authority changes follow, then the fee cap and the program's
// source verification. Bullet prose never carries the safety summary.
// Ported from 21st.dev cnippet-dev/incident-status (id 24943, stacked
// status sections) and Porto's action preview (ActionPreview.tsx).
//
// outflow:  { amount: "1000", symbol: "LEZ", definition: "" }   (raw integer)
// to:       { name?: "Savings", address: "3ksne…", kind: "public"|"private"|"program" }
// effects:  ["Posts a testimonial record owned by …", …]
// authority:["Mint authority used", …]          (warnings)
// fee:      { cap: "134400000", payer?: "Main" }
// program:  { name, status: "verified"|"claimed"|"unknown", immutable: bool }
ColumnLayout {
    id: tx
    property var outflow: null
    property var to: null
    property var effects: []
    property var authority: []
    property var fee: null
    property var program: null
    property bool isPrivate: false
    spacing: 12

    // 1. What leaves, and where it goes.
    Rectangle {
        visible: !!tx.outflow
        Layout.fillWidth: true
        implicitHeight: top.implicitHeight + 32
        radius: Theme.rCard
        color: Theme.surface2
        ColumnLayout {
            id: top
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 16
            spacing: 14
            RowLayout {
                spacing: 12
                TokenIcon { definition: tx.outflow ? (tx.outflow.definition || "") : ""; size: 42; isPrivate: tx.isPrivate }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Txt { text: "You send"; tone: "text2"; font.pixelSize: 12 }
                    RowLayout {
                        spacing: 6
                        Txt {
                            text: tx.outflow ? Units.group(tx.outflow.amount) : ""
                            num: true; font.pixelSize: 26; font.weight: Font.Bold
                            Accessible.name: tx.outflow ? Units.group(tx.outflow.amount) + " " + tx.outflow.symbol : ""
                        }
                        Txt { text: tx.outflow ? tx.outflow.symbol : ""; tone: "text2"; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignBaseline }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line; visible: !!tx.to }
            ColumnLayout {
                visible: !!tx.to
                Layout.fillWidth: true
                spacing: 6
                RowLayout {
                    spacing: 8
                    Txt { text: "To"; tone: "text2"; font.pixelSize: 12 }
                    Badge {
                        visible: !!tx.to
                        text: tx.to && tx.to.kind === "private" ? "Private account" : tx.to && tx.to.kind === "program" ? "Program" : "Public account"
                        tone: tx.to && tx.to.kind === "private" ? "private" : "neutral"
                        dot: false
                    }
                    Txt { visible: !!(tx.to && tx.to.name); text: tx.to ? (tx.to.name || "") : ""; font.pixelSize: 13; font.weight: Font.DemiBold }
                }
                // The FULL destination, wrapped, never shortened.
                Txt {
                    Layout.fillWidth: true
                    text: tx.to ? tx.to.address : ""
                    mono: true
                    font.pixelSize: 13
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideNone
                }
            }
        }
    }

    // 2. What else it does.
    ColumnLayout {
        visible: tx.effects.length > 0 || tx.authority.length > 0
        Layout.fillWidth: true
        spacing: 6
        Txt { text: "What this does"; tone: "text2"; font.pixelSize: 12; font.weight: Font.DemiBold }
        Repeater {
            model: tx.authority
            Notice { text: modelData; tone: "warn"; icon: "key" }
        }
        Repeater {
            model: tx.effects
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle { Layout.alignment: Qt.AlignTop; Layout.topMargin: 6; implicitWidth: 6; implicitHeight: 6; radius: 3; color: Theme.text3 }
                Txt { text: modelData; font.pixelSize: 13; wrapMode: Text.Wrap; elide: Text.ElideNone; Layout.fillWidth: true }
            }
        }
    }

    // 3. Fee cap and the program's source.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        InfoRow {
            visible: !!tx.fee
            label: "Network fee (max)"
            value: tx.fee ? "≤ " + Units.lez(tx.fee.cap) + (tx.fee.payer ? " · paid by " + tx.fee.payer : "") : ""
        }
        Item {
            visible: !!tx.program
            Layout.fillWidth: true
            implicitHeight: prow.implicitHeight + 18
            Rectangle { width: parent.width; height: 1; color: Theme.line }
            RowLayout {
                id: prow
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Txt { text: "Program"; tone: "text2"; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Txt { text: tx.program ? tx.program.name : ""; font.pixelSize: 13; font.weight: Font.DemiBold }
                Badge {
                    text: !tx.program ? "" : tx.program.status === "verified" ? "Verified source" : tx.program.status === "claimed" ? "Source claimed" : "Unverified"
                    tone: !tx.program ? "neutral" : tx.program.status === "verified" ? "ok" : tx.program.status === "claimed" ? "warn" : "danger"
                    dot: false
                }
                Badge {
                    text: tx.program && tx.program.immutable ? "Immutable" : "Upgradeable"
                    tone: tx.program && tx.program.immutable ? "neutral" : "warn"
                    dot: false
                }
            }
        }
    }
}
