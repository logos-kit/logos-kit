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
// outflow:  { amount: "1500000000", symbol: "LGO", definition: "" }   (base units:
//            lepta for the native token, shown in LGO; a token's own, with
//            its `decimals` if it declares any)
// to:       { name?: "Savings", address: "3ksne…", kind: "public"|"private"|"program" }
// effects:  ["Posts a testimonial record owned by …", …]
// authority:["Mint authority used", …]          (warnings)
// fee:      { cap: "134400000", payer?: "Main" }   (lepta)
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
    readonly property string outFigure: !outflow ? ""
        : outflow.definition ? Units.token(outflow.amount, outflow.decimals || 0) : Units.lgo(outflow.amount)
    spacing: 12

    // 1. What leaves, and where it goes.
    // Flat, Fuse-style (Refero: Fuse swap confirm): icon, a quiet label, the
    // figure large with its unit quieter; a hairline closes the block.
    Rectangle {
        visible: !!tx.outflow
        Layout.fillWidth: true
        implicitHeight: top.implicitHeight + 18
        color: "transparent"
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: Theme.line }
        ColumnLayout {
            id: top
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            spacing: 16
            RowLayout {
                spacing: 14
                TokenIcon { definition: tx.outflow ? (tx.outflow.definition || "") : ""; size: 48; isPrivate: tx.isPrivate }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    Txt { text: "You send"; tone: "text3"; font.pixelSize: 13 }
                    RowLayout {
                        spacing: 6
                        Txt {
                            text: tx.outFigure
                            num: true; font.pixelSize: 30; font.weight: Font.Bold
                            Accessible.name: tx.outflow ? tx.outFigure + " " + tx.outflow.symbol : ""
                        }
                        Txt { text: tx.outflow ? tx.outflow.symbol : ""; tone: "text3"; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignBaseline }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.line; visible: !!tx.to }
            // To (Family confirm): the name large, the FULL destination under
            // it, wrapped, never shortened.
            ColumnLayout {
                visible: !!tx.to
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                spacing: 4
                RowLayout {
                    spacing: 8
                    Txt { text: "To"; tone: "text3"; font.pixelSize: 13 }
                    Txt { visible: !!(tx.to && tx.to.name); text: tx.to ? (tx.to.name || "") : ""; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Badge {
                        visible: !!tx.to
                        text: tx.to && tx.to.kind === "private" ? "Private" : tx.to && tx.to.kind === "program" ? "Program" : "Public"
                        tone: tx.to && tx.to.kind === "private" ? "private" : "neutral"
                        dot: false
                    }
                }
                Txt {
                    Layout.fillWidth: true
                    text: tx.to ? tx.to.address : ""
                    mono: true
                    tone: "text2"
                    font.pixelSize: 12
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
        Txt { text: "What else it does"; tone: "text3"; font.pixelSize: 13 }
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
            label: "Network fee"
            value: tx.fee ? "≤ " + Units.lgoLabel(tx.fee.cap) + (tx.fee.payer ? " · paid by " + tx.fee.payer : "") : ""
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
                Txt { text: "Program"; tone: "text2"; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
                Txt { text: tx.program ? tx.program.name : ""; font.pixelSize: 14; font.weight: Font.Medium; elide: Text.ElideMiddle; Layout.maximumWidth: 150 }
                Badge {
                    text: !tx.program ? "" : tx.program.status === "builtin" ? "Built into LEZ"
                        : tx.program.status === "verified" ? "Verified source"
                        : tx.program.status === "claimed" ? "Source claimed"
                        : tx.program.status === "mismatch" ? "Source mismatch" : "Unverified"
                    tone: !tx.program ? "neutral" : (tx.program.status === "verified" || tx.program.status === "builtin") ? "ok" : tx.program.status === "claimed" ? "warn" : "danger"
                    dot: false
                }
                Badge {
                    visible: !!tx.program && tx.program.status !== "builtin"
                    text: tx.program && tx.program.immutable ? "Immutable" : "Upgradeable"
                    tone: tx.program && tx.program.immutable ? "neutral" : "warn"
                    dot: false
                }
            }
        }
    }
}
