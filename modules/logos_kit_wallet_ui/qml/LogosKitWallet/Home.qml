import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt
import "../LogosKitUi/Units.js" as Units

// Tray home on LogosKitUi v2: account + network bar, the balance hero
// (BalanceCard: rolling figure, private spendable / pending / locked), the
// quick actions, the account's assets (TokenRow, real logos) and activity
// (TxRow over the kit's ActivityRow). ux-spec §2; Codex full review §4 P1.
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
    // Private buckets, from the transactions in flight (native only).
    function inFlight(s) { return s.lifecycle !== "included" && s.lifecycle !== "dropped" && s.lifecycle !== "awaiting_approval" && !s.token }
    readonly property string pendingIn: {
        var sum = "0"
        if (!acct) return sum
        for (var i = 0; i < store.activity.length; i++) {
            var s = store.activity[i]
            if (inFlight(s) && s.to === acct.accountId && s.amount) sum = Units.add(sum, s.amount)
        }
        return sum
    }
    readonly property string lockedOut: {
        var sum = "0"
        if (!acct) return sum
        for (var i = 0; i < store.activity.length; i++) {
            var s = store.activity[i]
            if (inFlight(s) && s.from === acct.accountId && s.amount) sum = Units.add(sum, s.amount)
        }
        return sum
    }
    readonly property bool synced: !!acct && acct.native !== null && acct.native !== undefined

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
            spacing: 14

            // -- top bar ----------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    id: pill
                    objectName: "accountPill"
                    signal clicked()
                    onClicked: home.accounts()
                    implicitHeight: 40
                    implicitWidth: pillRow.implicitWidth + 22
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    Layout.minimumWidth: 90
                    clip: true
                    radius: 20
                    color: pillMouse.containsMouse ? Theme.soft(Theme.text, 0.08) : Theme.surface2
                    Behavior on color { ColorAnimation { duration: Theme.dFast } }
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Account " + (home.acct ? Fmt.accountName(home.acct) : "none") + ", switch"
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    RowLayout {
                        id: pillRow
                        anchors.verticalCenter: parent.verticalCenter
                        x: 7
                        spacing: 8
                        Item {
                            implicitWidth: 26; implicitHeight: 26
                            Identicon { seed: home.acct ? home.acct.accountId : ""; size: 26 }
                            Rectangle {
                                visible: home.priv
                                width: 12; height: 12; radius: 6; x: 16; y: 16
                                color: Theme.priv; border.width: 2; border.color: Theme.surface2
                            }
                        }
                        Txt { text: home.acct ? Fmt.accountName(home.acct) : home.store.accounts.length === 0 ? "Loading accounts…" : "No account"; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.maximumWidth: Math.min(200, col.width - 230) }
                        Glyph { name: "chevronDown"; implicitWidth: 14; implicitHeight: 14; color: Theme.text2 }
                    }
                    MouseArea { id: pillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
                    FocusRing { anchors.fill: parent }
                }
                Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }
                Badge {
                    text: home.narrow ? "" : home.store.offline ? "Offline" : (home.store.zone.chain === "lez:local" ? "LEZ local" : home.store.zone.chain === "lez:preview" ? "LEZ preview" : "LEZ testnet")
                    tone: home.store.offline ? "warn" : "ok"
                    live: !home.store.offline
                }
                IconButton {
                    glyph: Theme.dark ? "sun" : "moon"
                    label: "Switch theme"
                    filled: true
                    onClicked: {
                        Theme.dark = !Theme.dark
                        home.store.call("setPrefs", { theme: Theme.dark ? "dark" : "light" }, null)
                    }
                }
                IconButton { objectName: "openSettings"; glyph: "sliders"; label: "Settings"; filled: true; onClicked: home.settings() }
            }

            ErrorCard {
                visible: home.store.offline
                glyph: "refresh"
                title: "Can't reach the network"
                body: "Your keys and funds are safe. Retrying automatically"
                      + (home.store.snapshotMs ? "; balances last updated " + Fmt.ago(home.store.snapshotMs) + "." : ".")
                detail: home.store.zone.sequencer || ""
                retryText: "Retry now"
                onRetry: home.store.call("refresh", {}, null)
            }

            // -- balance --------------------------------------------------------------
            Card {
                Layout.fillWidth: true
                pad: 22
                BalanceCard {
                    id: bal
                    width: parent.width
                    tickerName: "balance"
                    label: home.priv ? "Private balance · only you can see it" : "Public balance · visible on-chain"
                    value: home.synced ? home.acct.native : "0"
                    loading: !home.synced
                    note: !home.synced ? (home.store.tip ? "Syncing… block " + Units.group(String(home.store.tip)) : "Syncing…")
                          : home.acct.proofInProgress ? "Part of this is locked by a proof in progress." : ""
                    privSpendable: home.priv && home.synced ? home.acct.native : ""
                    privPending: home.pendingIn
                    privLocked: home.lockedOut
                    ActionTile { objectName: "homeSend"; glyph: "arrowUp"; text: "Send"; tone: "ink"; onClicked: home.send() }
                    ActionTile { objectName: "homeReceive"; glyph: "arrowDown"; text: "Receive"; onClicked: home.receive() }
                    ActionTile { objectName: "homeFunds"; glyph: "droplet"; text: "Test LGO"; enabled: !!home.store.state.faucet; opacity: enabled ? 1 : 0.4; onClicked: home.funds() }
                }
            }

            // -- assets ---------------------------------------------------------------
            Card {
                Layout.fillWidth: true
                pad: 8
                ColumnLayout {
                    width: parent.width
                    spacing: 0
                    Txt { text: "Assets"; tone: "text2"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.leftMargin: 12; Layout.topMargin: 8; Layout.bottomMargin: 4 }
                    TokenRow {
                        name: "Logos"
                        symbol: Units.SYMBOL
                        sub: home.priv ? "Private · only you" : "Native token"
                        isPrivate: home.priv
                        amount: home.synced ? Units.lgo(home.acct.native) : ""
                        loading: !home.synced
                    }
                    Repeater {
                        model: home.acct ? (home.acct.tokens || []) : []
                        TokenRow {
                            name: modelData.name || Fmt.short(modelData.definition)
                            symbol: modelData.name || ""
                            definition: modelData.definition
                            sub: modelData.kind === "fungible" ? "Token · " + Fmt.short(modelData.definition) : "NFT"
                            isPrivate: !!modelData.private
                            amount: Units.group(modelData.amount)
                        }
                    }
                }
            }

            // -- other accounts -----------------------------------------------------------
            ListView {
                visible: home.store.accounts.length > 1
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

            // -- activity ------------------------------------------------------------------
            Card {
                Layout.fillWidth: true
                pad: 8
                ColumnLayout {
                    width: parent.width
                    spacing: 0
                    Txt { text: "Activity"; tone: "text2"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.leftMargin: 12; Layout.topMargin: 8; Layout.bottomMargin: 4 }
                    // The latest faucet request (a job, not a transaction).
                    ActivityRow {
                        objectName: "fundingRow"
                        visible: home.store.funding !== null
                        readonly property var f: home.store.funding || ({})
                        readonly property var r: f.result || ({})
                        kind: "faucet"
                        title: r.status === "funded" ? "Test LGO from the faucet" : "Test LGO"
                        amount: r.status === "funded" ? Units.lgo(r.amount) : ""
                        status: f.state === "running" || r.status === "outcome_unknown" ? "pending"
                              : r.status === "funded" ? "included" : "failed"
                        sub: f.state === "running" ? "Requesting from the faucet"
                            : f.state === "error" ? Fmt.errorText(f.error)
                            : r.status === "rate_limited" ? "You can claim again in " + Fmt.mmss(r.retryAfterSeconds)
                            : r.status === "outcome_unknown" ? "Checking whether it arrived"
                            : r.status === "funded" ? "To " + Fmt.short(r.fundedAccount)
                            : (r.reason || "")
                    }
                    Repeater {
                        model: home.visibleActivity
                        TxRow { tx: modelData; onClicked: home.openStatus(modelData) }
                    }
                    EmptyState {
                        visible: home.visibleActivity.length === 0 && home.store.funding === null
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        Layout.bottomMargin: 14
                        glyph: "inbox"
                        title: "No activity yet"
                        body: home.store.state.faucet ? "Get test LGO from the faucet to try a send." : "Sends, receives and app requests show up here."
                        actionText: home.store.state.faucet ? "Get test LGO" : ""
                        actionTone: "ink"
                        onAction: home.funds()
                    }
                }
            }
        }
    }
}
