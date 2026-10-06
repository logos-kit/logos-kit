import QtQuick
import "../LogosKitUi"
import QtQuick.Layouts
import "Fmt.js" as Fmt
import "../LogosKitUi/Units.js" as Units

// Ledger home (Refero: Family / Fuse / Phantom wallet homes): the account as
// a bold header that opens the switcher, the balance with quiet decimals,
// three action tiles, then flat Tokens and Activity lists. No card chrome.
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
        contentHeight: col.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            objectName: "homeCol"
            width: Math.min(home.width - 40, 560)
            x: (home.width - width) / 2
            y: 52
            spacing: 0

            // -- account header (Family: avatar + bold name opens the switcher) --
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Item {
                    id: pill
                    objectName: "accountPill"
                    signal clicked()
                    onClicked: home.accounts()
                    implicitHeight: 48
                    implicitWidth: pillRow.implicitWidth + 12
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    Layout.minimumWidth: 90
                    clip: true
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: "Account " + (home.acct ? Fmt.accountName(home.acct) : "none") + ", switch"
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    Rectangle { anchors.fill: parent; radius: 24; color: pillMouse.containsMouse ? Theme.surface : "transparent"; Behavior on color { ColorAnimation { duration: Theme.dFast } } }
                    RowLayout {
                        id: pillRow
                        anchors.verticalCenter: parent.verticalCenter
                        x: 4
                        spacing: 10
                        Item {
                            implicitWidth: 36; implicitHeight: 36
                            Identicon { seed: home.acct ? home.acct.accountId : ""; size: 36 }
                            Rectangle {
                                visible: home.priv
                                width: 18; height: 18; radius: 9; x: 22; y: 22
                                color: Theme.bg
                                Glyph { anchors.centerIn: parent; name: "lock"; color: Theme.text; width: 11; height: 11 }
                            }
                        }
                        Txt { text: home.acct ? Fmt.accountName(home.acct) : home.store.accounts.length === 0 ? "Loading accounts…" : "No account"; font.pixelSize: 20; font.weight: Font.Bold; Layout.maximumWidth: Math.min(240, col.width - 190) }
                        Glyph { name: "chevronDown"; implicitWidth: 16; implicitHeight: 16; color: Theme.text2 }
                    }
                    MouseArea { id: pillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
                    FocusRing { anchors.fill: parent }
                }
                Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }
                Badge {
                    visible: !home.narrow || home.store.offline
                    text: home.store.offline ? "Offline" : (home.store.zone.chain === "lez:local" ? "Local" : home.store.zone.chain === "lez:preview" ? "Preview" : "Testnet")
                    tone: home.store.offline ? "warn" : "ok"
                    live: !home.store.offline
                }
                IconButton {
                    objectName: "themeToggle"
                    glyph: Theme.dark ? "sun" : "moon"
                    label: Theme.dark ? "Light mode" : "Dark mode"
                    onClicked: {
                        Theme.dark = !Theme.dark
                        home.store.call("setPrefs", { theme: Theme.dark ? "dark" : "light" }, null)
                    }
                }
                IconButton { objectName: "openSettings"; glyph: "sliders"; label: "Settings"; onClicked: home.settings() }
            }

            ErrorCard {
                visible: home.store.offline
                Layout.fillWidth: true
                Layout.topMargin: 16
                glyph: "refresh"
                title: "Can't reach the network"
                body: "Your keys and funds are safe. Retrying automatically"
                      + (home.store.snapshotMs ? "; balances last updated " + Fmt.ago(home.store.snapshotMs) + "." : ".")
                detail: home.store.zone.sequencer || ""
                retryText: "Retry now"
                onRetry: home.store.call("refresh", {}, null)
            }

            // -- balance (Fuse: label, the figure, then the actions) -----------------
            BalanceCard {
                id: bal
                Layout.fillWidth: true
                Layout.topMargin: 28
                tickerName: "balance"
                label: home.priv ? "Private balance · only you can see it" : "Public balance"
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

            // -- tokens ----------------------------------------------------------------
            SectionTitle { text: "Tokens"; Layout.topMargin: 32 }
            TokenRow {
                Layout.leftMargin: -12
                Layout.rightMargin: -12
                name: "Logos"
                symbol: Units.SYMBOL
                sub: home.priv ? "Private · only you" : "LGO · native token"
                isPrivate: home.priv
                amount: home.synced ? (bal.hidden ? "••••" : Units.lgo(home.acct.native)) : ""
                amountSub: home.synced && !bal.hidden ? Units.SYMBOL : ""
                loading: !home.synced
            }
            Repeater {
                model: home.acct ? (home.acct.tokens || []) : []
                TokenRow {
                    Layout.leftMargin: -12
                    Layout.rightMargin: -12
                    name: modelData.name || Fmt.short(modelData.definition)
                    symbol: modelData.name || ""
                    definition: modelData.definition
                    sub: modelData.kind === "fungible" ? "Token · " + Fmt.short(modelData.definition) : "NFT"
                    isPrivate: !!modelData.private
                    amount: bal.hidden ? "••••" : Units.group(modelData.amount)
                }
            }

            // -- activity ---------------------------------------------------------------
            SectionTitle { text: "Activity"; Layout.topMargin: 28 }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: -12
                Layout.rightMargin: -12
                spacing: 0
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
                    TxRow { tx: modelData; store: home.store; onClicked: home.openStatus(modelData) }
                }
            }
            EmptyState {
                visible: home.visibleActivity.length === 0 && home.store.funding === null
                Layout.fillWidth: true
                Layout.topMargin: 8
                glyph: "inbox"
                title: "No activity yet"
                // Funded already: the faucet nudge would read as a mistake.
                readonly property bool nudge: !!home.store.state.faucet && !(home.synced && home.acct.native !== "0")
                body: nudge ? "Get test LGO from the faucet to try a send." : "Your sends and app requests show up here."
                actionText: nudge ? "Get test LGO" : ""
                actionTone: "ink"
                onAction: home.funds()
            }
        }
    }
}
