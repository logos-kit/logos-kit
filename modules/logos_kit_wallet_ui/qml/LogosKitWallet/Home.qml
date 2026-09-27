import QtQuick
import QtQuick.Layouts
import "Fmt.js" as Fmt

// Tray home (design-lab trayHome; ux-spec §2).
Item {
    id: home
    property var store
    signal send()
    signal receive()
    signal funds()
    signal accounts()
    signal settings()
    signal openStatus(var status)

    readonly property var acct: store.current
    readonly property bool priv: !!acct && acct.kind === "private"
    readonly property bool compact: width < 680
    readonly property bool narrow: width < 440
    readonly property var visibleActivity: {
        var out = []
        for (var i = 0; i < store.activity.length && out.length < 12; i++) {
            var s = store.activity[i]
            if (s.lifecycle === "awaiting_approval") continue
            out.push(s)
        }
        return out
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            objectName: "homeCol"
            width: Math.min(home.width - 32, 560)
            x: (home.width - width) / 2
            y: 56
            spacing: 12

            // -- top bar ----------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    objectName: "accountPill"
                    implicitHeight: 34
                    implicitWidth: pillRow.implicitWidth + 16
                    // The one item that gives way on narrow screens.
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    Layout.minimumWidth: 80
                    clip: true
                    radius: 17
                    color: Theme.surface2
                    RowLayout {
                        id: pillRow
                        anchors.verticalCenter: parent.verticalCenter
                        x: 5
                        spacing: 7
                        Identicon { seed: home.acct ? home.acct.accountId : ""; size: 24 }
                        Txt { text: home.acct ? Fmt.accountName(home.acct) : "No account"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.maximumWidth: Math.min(180, col.width - 230) }
                        Glyph { name: "chevronDown"; implicitWidth: 14; implicitHeight: 14; color: Theme.text3 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: home.accounts() }
                }
                Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }
                IconBtn {
                    icon: Theme.dark ? "sun" : "moon"
                    label: "Switch theme"
                    onClicked: {
                        Theme.dark = !Theme.dark
                        home.store.call("setPrefs", { theme: Theme.dark ? "dark" : "light" }, null)
                    }
                }
                Rectangle {
                    implicitHeight: 34
                    implicitWidth: netRow.implicitWidth + 16
                    radius: 17
                    color: Theme.surface2
                    RowLayout {
                        id: netRow
                        anchors.verticalCenter: parent.verticalCenter
                        x: 5
                        spacing: 6
                        Rectangle { implicitWidth: 22; implicitHeight: 22; radius: 11; color: "#000000"; LogosMark { anchors.centerIn: parent; size: 11 } }
                        Rectangle { implicitWidth: 6; implicitHeight: 6; radius: 3; color: home.store.offline ? Theme.warn : Theme.ok }
                        Txt { visible: !home.narrow; text: home.store.zone.chain === "lez:local" ? "LEZ local" : "LEZ testnet"; font.pixelSize: 13; font.weight: Font.DemiBold }
                    }
                }
                IconBtn { objectName: "openSettings"; icon: "sliders"; label: "Settings"; onClicked: home.settings() }
            }

            Notice {
                visible: home.store.offline
                tone: "warn"
                text: "Can't reach the sequencer (" + (home.store.zone.sequencer || "") + "). Retrying… "
                      + (home.store.snapshotMs ? "Balances last updated " + Fmt.ago(home.store.snapshotMs) + "." : "")
            }

            // -- balance card ---------------------------------------------------------
            Card {
                Layout.fillWidth: true
                pad: 20
                ColumnLayout {
                    width: parent.width
                    spacing: 14
                    RowLayout {
                        Layout.fillWidth: true
                        Txt { text: home.priv ? "Private balance" : "Public balance"; tone: "text2"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Item { Layout.fillWidth: true }
                        Tag { text: home.priv ? "Only you" : "Visible on-chain"; tone: home.priv ? "private" : "pending"; icon: home.priv ? "shield" : "eye" }
                    }
                    RowLayout {
                        spacing: 8
                        Txt {
                            objectName: "balance"
                            text: home.acct ? Fmt.amount(home.acct.native, 0) : "—"
                            font.pixelSize: home.compact ? 46 : 58
                            // Long balances shrink rather than overflow the card.
                            Layout.maximumWidth: col.width - 110
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: 24
                            font.weight: Font.Bold
                            font.letterSpacing: -1.5
                            num: true
                        }
                        Txt { text: "LEZ"; tone: "text2"; font.pixelSize: home.compact ? 20 : 24; font.weight: Font.Medium; Layout.alignment: Qt.AlignBaseline }
                    }
                    Txt {
                        Layout.fillWidth: true
                        tone: home.acct && home.acct.proofInProgress ? "warn" : "text2"
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        text: !home.acct || home.acct.native === null || home.acct.native === undefined
                              ? (home.store.tip ? "Syncing… block " + Fmt.amount(String(home.store.tip), 0) : "Syncing…")
                              : home.acct.proofInProgress ? "Part of this is locked by a proof in progress."
                              : home.priv ? "Only you can see this. Not even the network."
                              : "Anyone can see this account's balance and history."
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 8
                        Btn { objectName: "homeSend"; Layout.fillWidth: true; Layout.preferredWidth: 1; tone: "ink"; icon: "arrowUp"; text: "Send"; onClicked: home.send() }
                        Btn { objectName: "homeReceive"; Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "arrowDown"; text: "Receive"; onClicked: home.receive() }
                        Btn { objectName: "homeFunds"; Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "droplet"; text: "Add"; enabled: !!home.store.state.faucet; onClicked: home.funds() }
                    }
                }
            }

            // Tokens held by this account.
            Repeater {
                model: home.acct ? (home.acct.tokens || []) : []
                Card {
                    Layout.fillWidth: true
                    pad: 14
                    RowLayout {
                        width: parent.width
                        spacing: 12
                        Identicon { seed: modelData.definition; size: 34; square: true }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Txt { text: modelData.name || Fmt.short(modelData.definition); font.weight: Font.DemiBold }
                            Txt { text: modelData.kind === "fungible" ? "Token" : "NFT"; tone: "text2"; font.pixelSize: 12 }
                        }
                        Txt { text: Fmt.amount(modelData.amount, 0); num: true; font.weight: Font.DemiBold }
                    }
                }
            }

            // -- account chips -----------------------------------------------------------
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: home.store.accounts
                delegate: AccountChip {
                    account: modelData
                    selected: home.acct && modelData.accountId === home.acct.accountId
                    onClicked: home.store.selected = modelData.accountId
                }
            }

            // -- recent ------------------------------------------------------------------
            Card {
                Layout.fillWidth: true
                pad: 16
                ColumnLayout {
                    width: parent.width
                    spacing: 0
                    Txt { text: "Recent"; tone: "text2"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.bottomMargin: 4 }
                    // The latest faucet request (a job, not a transaction).
                    RowLayout {
                        objectName: "fundingRow"
                        visible: home.store.funding !== null
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        spacing: 12
                        readonly property var f: home.store.funding || ({})
                        readonly property var r: f.result || ({})
                        Rectangle {
                            implicitWidth: 36; implicitHeight: 36; radius: 14; color: Theme.surface2
                            Glyph { anchors.centerIn: parent; name: "droplet"; width: 16; height: 16; color: Theme.text2 }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Txt { text: parent.parent.r.status === "funded" ? "+" + Fmt.amount(parent.parent.r.amount, 0) + " LEZ test funds" : "Test funds"; font.weight: Font.DemiBold }
                            Txt {
                                Layout.fillWidth: true
                                tone: "text2"; font.pixelSize: 12
                                text: parent.parent.f.state === "running" ? "Requesting from the faucet…"
                                    : parent.parent.f.state === "error" ? Fmt.errorText(parent.parent.f.error)
                                    : parent.parent.r.status === "rate_limited" ? "You can claim again in " + Fmt.mmss(parent.parent.r.retryAfterSeconds)
                                    : parent.parent.r.status === "outcome_unknown" ? "Checking whether funds arrived…"
                                    : parent.parent.r.status === "funded" ? "Faucet → " + Fmt.short(parent.parent.r.fundedAccount)
                                    : (parent.parent.r.reason || "")
                            }
                        }
                        Spinner { visible: parent.f.state === "running"; size: 18 }
                        Tag { visible: parent.f.state !== "running"; text: parent.r.status === "funded" ? "Confirmed" : parent.f.state === "error" ? "Failed" : "Not funded"; tone: parent.r.status === "funded" ? "ok" : "danger" }
                    }
                    Repeater {
                        model: home.visibleActivity
                        ActivityRow { status: modelData; onClicked: home.openStatus(modelData) }
                    }
                    ColumnLayout {
                        visible: home.visibleActivity.length === 0 && home.store.funding === null
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 10
                        Txt { text: "No activity yet. Get test funds to start."; tone: "text2"; font.pixelSize: 13 }
                        Btn { visible: !!home.store.state.faucet; tone: "neutral"; icon: "droplet"; text: "Get test funds"; onClicked: home.funds() }
                    }
                }
            }
        }
    }
}
