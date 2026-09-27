import QtQuick
import QtQuick.Layouts
import "LogosKit"
import "LogosKitUi"

// Logos Kit Testimonials: the LP-0021 reference app for the Logos Kit SDK.
//
//   connect (wallet picks a public account) → compose → approve in the
//   wallet (fee shown there) → watch the transaction → explorer link.
//
// Every read goes through the wallet core module (`kit.api.*`); nothing here
// touches keys. Untrusted strings (other people's posts) render as plain text.
Item {
    id: root
    width: 520
    height: 820

    /** CAIP-2 chain; the wallet must be on the same one. */
    property string chain: "lez:testnet"
    /** The testimonial program; defaults to the deployment known for `chain`. */
    property string program: ""
    readonly property string programId: program !== "" ? program
        : (kit.sdk && kit.sdk.TESTIMONIAL_PROGRAMS[chain]) || localProgram.text.trim()
    readonly property int maxText: kit.sdk ? kit.sdk.TESTIMONIAL_MAX_TEXT : 280
    readonly property int maxName: kit.sdk ? kit.sdk.TESTIMONIAL_MAX_USERNAME : 32

    // Session and the selected account.
    property var session: null
    property var accounts: session ? session.accounts.filter(function (a) { return a.kind === "public" }) : []
    property string account: ""
    property var balance: null        // string (base units) once read
    property var nonce: null          // string once read
    property var mine: undefined      // undefined: unknown, null: not posted, object: posted
    property bool checking: false

    // Posting.
    property string phase: "compose"  // compose | approving | pending | done | failed
    property string handle: ""
    property var status: null
    property string failure: ""
    property string note: ""          // soft notice under the composer
    property var watcher: null

    // Feed.
    property var feed: null
    property bool feedLoading: false
    property string feedError: ""
    property bool funding: false

    LogosKit {
        id: kit
        chain: root.chain
        visible: root.visible
        onApiChanged: if (api) { root.restore(); root.loadFeed() }
    }

    // ---- helpers --------------------------------------------------------------

    function shortId(a) { return a && a.length > 12 ? a.substring(0, 5) + "…" + a.substring(a.length - 4) : (a || "") }
    function ago(ms) {
        var s = Math.max(0, (Date.now() - ms) / 1000)
        if (s < 60) return "just now"
        if (s < 3600) return Math.floor(s / 60) + " min ago"
        if (s < 86400) return Math.floor(s / 3600) + " h ago"
        if (s < 86400 * 30) return Math.floor(s / 86400) + " d ago"
        return new Date(ms).toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }
    function thisMonth() {
        if (!feed) return 0
        var d = new Date(), key = d.getUTCFullYear() * 100 + d.getUTCMonth() + 1
        for (var i = 0; i < feed.monthly.length; i++) if (feed.monthly[i].yyyymm === key) return feed.monthly[i].count
        return 0
    }
    function errText(e) {
        if (!e) return "Something went wrong"
        if (e.code === 4902) return "Your wallet is on another network. Switch it to " + root.chain + " in the wallet's settings."
        if (e.code === 4900 || e.code === 4901) return "Can't reach the network right now. Check your connection and try again."
        if (e.code === 4100) return "The wallet no longer shares this account with the app. Connect again."
        return e.message || ("Error " + e.code)
    }
    function isRejection(e) { return e && kit.sdk && kit.sdk.isUserRejection(e) }

    // What the program accepts (testimonial_core::check_text / check_username),
    // plus our rule: the text must name the wallet so it counts for Logos Kit.
    readonly property var hidden: /[\u00AD\u061C\u200B-\u200F\u2028-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]/
    function textProblem(t) {
        if (t.trim() === "") return "Write a sentence or two."
        if (composer.over) return "That's over " + root.maxText + " bytes. Shorten it a little."
        if (/[\u0000-\u0009\u000B-\u001F\u007F-\u009F]/.test(t) || hidden.test(t)) return "Remove the invisible or control characters."
        if (!/logos\s*kit/i.test(t)) return "Mention “Logos Kit” so it counts for this wallet."
        return ""
    }
    function nameProblem(n) {
        if (n === "") return ""
        if (n.trim() !== n) return "Remove spaces at the start or end of the name."
        if (composer.utf8Length(n) > root.maxName) return "Names are up to " + root.maxName + " bytes."
        if (/[\u0000-\u001F\u007F-\u009F]/.test(n) || hidden.test(n)) return "Remove the invisible or control characters."
        return ""
    }

    // ---- flows ----------------------------------------------------------------

    function restore() {
        kit.api.getSession().then(function (s) { if (s && s.accounts.length) useSession(s) }, function () {})
    }

    function connect() {
        root.note = ""
        kit.api.connect({ accountKinds: ["public"] }).then(useSession, function (e) {
            root.note = isRejection(e) ? "" : errText(e)
        })
    }

    function useSession(s) {
        root.session = s
        var pub = root.accounts
        if (!pub.length) { root.note = "Share a public account: testimonials are signed in public."; return }
        var keep = pub.some(function (a) { return a.address === root.account })
        selectAccount(keep ? root.account : pub[0].address)
    }

    function selectAccount(a) {
        root.account = a
        root.phase = "compose"
        root.failure = ""
        refreshAccount()
    }

    function refreshAccount() {
        var a = root.account
        if (!a) return
        root.checking = true
        var reads = [
            kit.api.getWalletBalance(a).then(function (b) { if (a === root.account) root.balance = b.amount }),
        ]
        if (root.programId) {
            reads.push(kit.api.readAccount(a, root.programId).then(function (r) { if (a === root.account) root.nonce = r.nonce }))
            reads.push(kit.api.getTestimonial(root.programId, a).then(function (t) { if (a === root.account) root.mine = t }))
        }
        Promise.all(reads).then(function () { root.checking = false }, function (e) {
            root.checking = false
            root.note = errText(e)
        })
    }

    function loadFeed() {
        if (!root.programId) return
        root.feedLoading = true
        root.feedError = ""
        kit.api.getTestimonials(root.programId, { limit: 25 }).then(function (f) {
            root.feed = f
            root.feedLoading = false
        }, function (e) {
            root.feedLoading = false
            root.feedError = e && e.code === 4100 ? "Connect to read testimonials." : errText(e)
        })
    }

    function getFunds() {
        root.funding = true
        root.note = ""
        kit.api.requestFunds(root.account).then(function (r) {
            root.funding = false
            if (r.status === "funded") { root.note = ""; delayedRefresh.restart() }
            else if (r.status === "rate_limited") root.note = "The faucet is busy. Try again" + (r.retryAfterSeconds ? " in " + Math.ceil(r.retryAfterSeconds / 60) + " min." : " later.")
            else if (r.status === "outcome_unknown") { root.note = "The faucet hasn't confirmed yet. Your balance updates when it does."; delayedRefresh.restart() }
            else root.note = r.reason || "The faucet said no."
        }, function (e) {
            root.funding = false
            root.note = isRejection(e) ? "" : errText(e)
        })
    }

    function post() {
        var text = composer.text, name = nameField.text
        if (textProblem(text) || nameProblem(name)) return
        root.phase = "approving"
        root.failure = ""
        root.note = ""
        var req = { program: root.programId, author: root.account, text: text }
        if (name !== "") req.username = name
        kit.api.postTestimonial(req).then(function (r) {
            root.handle = r.handle
            root.status = null
            root.phase = "pending"
            if (root.watcher) root.watcher.stop()
            root.watcher = kit.api.watchTransaction(r.handle, onStatus, function (e) { fail(errText(e)) })
        }, function (e) {
            if (isRejection(e)) { root.phase = "compose"; root.note = "Cancelled in the wallet. Nothing was sent." }
            else if (e && e.code === 6108) { root.phase = "compose"; root.note = e.message }
            else fail(errText(e))
        })
    }

    function onStatus(s) {
        root.status = s
        var lc = s.lifecycle
        if (lc === "included" || lc === "finalized") {
            if (s.outcome === "failure") { recheckAfterReject(s); return }
            root.phase = "done"
            refreshAccount()
            loadFeed()
        } else if (lc === "rejected" || lc === "dropped" || lc === "expired") {
            recheckAfterReject(s)
        }
    }

    // A rejected post may still mean "you already posted" (another device, a
    // retry): read the record before calling it a failure.
    function recheckAfterReject(s) {
        kit.api.getTestimonial(root.programId, root.account).then(function (t) {
            if (t) { root.mine = t; root.phase = "compose"; loadFeed(); return }
            fail(s.error && s.error.message ? s.error.message
                : s.lifecycle === "expired" ? "The approval expired before it was sent."
                : "The network didn't accept it.")
        }, function () { fail("The network didn't accept it.") })
    }

    function fail(msg) { root.failure = msg; root.phase = "failed" }

    Timer { id: delayedRefresh; interval: 2500; onTriggered: root.refreshAccount() }
    Timer { interval: 30000; repeat: true; running: root.visible && root.phase !== "pending"; onTriggered: root.loadFeed() }

    onProgramIdChanged: if (kit.api) { root.feed = null; loadFeed(); refreshAccount() }

    // ---- view -----------------------------------------------------------------

    Rectangle { anchors.fill: parent; color: Theme.bg }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: Math.min(flick.width - 32, 560)
            x: (flick.width - width) / 2
            y: 20
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                LogosMark { size: 22; white: Theme.dark }
                Txt { text: "Testimonials"; font.pixelSize: 20; font.weight: Font.DemiBold }
                Tag { text: root.chain.replace("lez:", ""); tone: "pending" }
                Item { Layout.fillWidth: true }
                Rectangle {
                    objectName: "tmAccount"
                    visible: root.account !== ""
                    implicitHeight: 36
                    implicitWidth: accRow.implicitWidth + 20
                    radius: 18
                    color: Theme.surface
                    RowLayout {
                        id: accRow
                        anchors.centerIn: parent
                        spacing: 8
                        Identicon { seed: root.account; size: 22 }
                        Txt { text: root.shortId(root.account); mono: true; font.pixelSize: 12 }
                    }
                }
                Btn {
                    objectName: "tmConnectTop"
                    visible: root.account === ""
                    text: "Connect"
                    tone: "action"
                    enabled: !kit.api || !kit.api.isBusy()
                    onClicked: root.connect()
                }
            }

            // Count
            Card {
                Layout.fillWidth: true
                ColumnLayout {
                    width: parent.width
                    spacing: 6
                    RowLayout {
                        spacing: 10
                        Txt {
                            objectName: "tmCount"
                            text: root.feed ? root.feed.count : "–"
                            font.pixelSize: 40
                            font.weight: Font.DemiBold
                            num: true
                        }
                        ColumnLayout {
                            spacing: 2
                            Txt { text: root.feed && root.feed.count === 1 ? "testimonial" : "testimonials"; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Txt { text: "for the Logos Kit wallet, on chain"; tone: "text2"; font.pixelSize: 13 }
                        }
                        Item { Layout.fillWidth: true }
                        Tag { visible: root.feed !== null; text: root.thisMonth() + " this month"; tone: root.thisMonth() > 0 ? "ok" : "pending" }
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: "Each one is a transaction on the Logos Execution Zone, signed by the account that wrote it."
                        tone: "text3"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }

            // Compose / status
            Card {
                Layout.fillWidth: true
                ColumnLayout {
                    width: parent.width
                    spacing: 12

                    // No program on this chain
                    Notice {
                        visible: !root.programId
                        tone: "warn"
                        text: root.chain === "lez:testnet"
                            ? "Posting opens when the testimonial program is live on testnet 0.3."
                            : "No testimonial program is known on " + root.chain + ". Paste its id below."
                    }
                    Field {
                        id: localProgram
                        objectName: "tmProgram"
                        visible: root.chain !== "lez:testnet" && root.program === "" && !(kit.sdk && kit.sdk.TESTIMONIAL_PROGRAMS[root.chain])
                        Layout.fillWidth: true
                        mono: true
                        placeholderText: "Testimonial program id"
                    }

                    // Disconnected
                    ColumnLayout {
                        visible: root.account === "" && root.programId !== ""
                        Layout.fillWidth: true
                        spacing: 10
                        Txt { text: "Vouch for Logos Kit"; font.pixelSize: 18; font.weight: Font.DemiBold }
                        Txt {
                            Layout.fillWidth: true
                            text: "Connect a public account and say what you use the wallet for. You approve the post in your wallet, which shows the fee first."
                            tone: "text2"
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                        }
                        Btn {
                            objectName: "tmConnect"
                            Layout.fillWidth: true
                            large: true
                            text: "Connect wallet"
                            tone: "action"
                            onClicked: root.connect()
                        }
                    }

                    // Checking the account
                    ColumnLayout {
                        visible: root.account !== "" && root.programId !== "" && root.mine === undefined
                        Layout.fillWidth: true
                        spacing: 10
                        Skeleton { Layout.preferredWidth: 180; implicitHeight: 18 }
                        Skeleton { Layout.fillWidth: true; implicitHeight: 110; radius: Theme.rRow }
                        Skeleton { Layout.fillWidth: true; implicitHeight: 52; radius: 26 }
                    }

                    // Already posted
                    ColumnLayout {
                        objectName: "tmMine"
                        visible: root.account !== "" && !!root.mine && root.phase !== "done"
                        Layout.fillWidth: true
                        spacing: 10
                        RowLayout {
                            spacing: 8
                            Txt { text: "Your testimonial"; font.pixelSize: 18; font.weight: Font.DemiBold }
                            Tag { text: "On chain"; tone: "ok"; icon: "check" }
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: root.mine ? root.mine.text : ""
                            font.pixelSize: 15
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                            lineHeight: 1.2
                        }
                        Txt {
                            text: root.mine ? (root.mine.username ? root.mine.username + " · " : "") + root.ago(root.mine.timestampMs) : ""
                            tone: "text2"
                            font.pixelSize: 12
                        }
                        Txt {
                            Layout.fillWidth: true
                            text: "Each account posts once. To post again, use another public account with some history."
                            tone: "text3"
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                        }
                        Btn { text: "View account on explorer"; icon: "external"; tone: "ghost"; visible: root.chain === "lez:testnet"; onClicked: kit.api.openExplorer({ account: root.account }).catch(function (e) { root.note = errText(e) }) }
                    }

                    // Compose
                    ColumnLayout {
                        visible: root.account !== "" && root.mine === null && (root.phase === "compose" || root.phase === "approving")
                        Layout.fillWidth: true
                        spacing: 10

                        Txt { text: "Say what you use it for"; font.pixelSize: 18; font.weight: Font.DemiBold }

                        // Several shared accounts: pick one.
                        Flow {
                            visible: root.accounts.length > 1
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: root.accounts
                                Rectangle {
                                    implicitHeight: 34
                                    implicitWidth: r.implicitWidth + 18
                                    radius: 17
                                    color: modelData.address === root.account ? Theme.surface2 : "transparent"
                                    border.width: 1
                                    border.color: modelData.address === root.account ? Theme.text : Theme.line
                                    RowLayout {
                                        id: r
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Identicon { seed: modelData.address; size: 18 }
                                        Txt { text: modelData.label || root.shortId(modelData.address); font.pixelSize: 12 }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectAccount(modelData.address) }
                                }
                            }
                        }

                        Notice {
                            objectName: "tmNoFunds"
                            visible: root.balance === "0"
                            tone: "warn"
                            text: "This account has no LEZ for the network fee. Get test funds first."
                        }
                        Btn {
                            objectName: "tmFunds"
                            visible: root.balance === "0"
                            text: root.funding ? "Waiting for the faucet…" : "Get test funds"
                            icon: "droplet"
                            busy: root.funding
                            onClicked: root.getFunds()
                        }
                        Notice {
                            objectName: "tmFresh"
                            visible: root.balance !== "0" && root.balance !== null && root.nonce === "0"
                            text: "This account hasn't sent anything yet. Posts from accounts with real use count for more: try a transfer first if you can."
                        }

                        Field {
                            id: nameField
                            objectName: "tmName"
                            Layout.fillWidth: true
                            placeholderText: "Name (optional)"
                            maximumLength: 64
                            invalid: root.nameProblem(text) !== ""
                        }
                        TextBox {
                            id: composer
                            objectName: "tmText"
                            Layout.fillWidth: true
                            maxBytes: root.maxText
                            text: "I use the Logos Kit wallet on LEZ to "
                            placeholderText: "I use the Logos Kit wallet to…"
                            invalid: dirty && root.textProblem(text) !== ""
                            property bool dirty: false
                            Connections { target: composer.area; function onTextChanged() { if (composer.area.activeFocus) composer.dirty = true } }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: ["send private payments", "use Basecamp apps", "hold test tokens", "build on LEZ"]
                                Rectangle {
                                    implicitHeight: 28
                                    implicitWidth: s.implicitWidth + 20
                                    radius: 14
                                    color: Theme.surface2
                                    Txt { id: s; anchors.centerIn: parent; text: modelData; tone: "text2"; font.pixelSize: 12 }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { composer.text = "I use the Logos Kit wallet on LEZ to " + modelData + "."; composer.dirty = true }
                                    }
                                }
                            }
                        }
                        Txt {
                            objectName: "tmProblem"
                            readonly property string problem: root.nameProblem(nameField.text) || (composer.dirty ? root.textProblem(composer.text) : "")
                            visible: problem !== ""
                            Layout.fillWidth: true
                            text: problem
                            tone: "danger"
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                        }
                        Txt {
                            visible: root.note !== ""
                            Layout.fillWidth: true
                            text: root.note
                            tone: "text2"
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                        }
                        Btn {
                            objectName: "tmPost"
                            Layout.fillWidth: true
                            large: true
                            tone: "ink"
                            busy: root.phase === "approving"
                            text: root.phase === "approving" ? "Approve in your wallet…" : "Post testimonial"
                            enabled: root.textProblem(composer.text) === "" && root.nameProblem(nameField.text) === "" && root.balance !== "0" && !root.checking
                            onClicked: { composer.dirty = true; root.post() }
                        }
                        Txt {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: "Public and permanent. One per account."
                            tone: "text3"
                            font.pixelSize: 12
                        }
                    }

                    // Pending
                    ColumnLayout {
                        objectName: "tmPending"
                        visible: root.phase === "pending"
                        Layout.fillWidth: true
                        spacing: 12
                        Txt { text: "Posting…"; font.pixelSize: 18; font.weight: Font.DemiBold }
                        Repeater {
                            model: [
                                { label: "Approved in your wallet", at: 0 },
                                { label: "Signed and sent to the network", at: 1 },
                                { label: "Included in a block", at: 2 }
                            ]
                            RowLayout {
                                readonly property int reached: {
                                    var lc = root.status ? root.status.lifecycle : ""
                                    return lc === "included" || lc === "finalized" ? 3 : lc === "submitted" ? 2 : 1
                                }
                                spacing: 10
                                Item {
                                    implicitWidth: 22; implicitHeight: 22
                                    Rectangle { anchors.fill: parent; radius: 11; visible: parent.parent.reached > modelData.at; color: Theme.soft(Theme.ok, 0.16) }
                                    Glyph { anchors.centerIn: parent; visible: parent.parent.reached > modelData.at; name: "check"; color: Theme.ok; width: 13; height: 13; stroke: 2.6 }
                                    Spinner { anchors.centerIn: parent; visible: parent.parent.reached === modelData.at; size: 18 }
                                    Rectangle { anchors.centerIn: parent; visible: parent.parent.reached < modelData.at; width: 8; height: 8; radius: 4; color: Theme.text3 }
                                }
                                Txt { text: modelData.label; tone: parent.reached >= modelData.at ? "text" : "text3" }
                            }
                        }
                        Txt { text: "Usually a few seconds. You can leave this screen."; tone: "text3"; font.pixelSize: 12 }
                    }

                    // Done
                    ColumnLayout {
                        objectName: "tmDone"
                        visible: root.phase === "done"
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            implicitWidth: 48; implicitHeight: 48; radius: 24
                            color: Theme.soft(Theme.ok, 0.16)
                            Glyph { anchors.centerIn: parent; name: "check"; color: Theme.ok; width: 24; height: 24; stroke: 2.6 }
                        }
                        Txt { text: "Posted on LEZ"; font.pixelSize: 20; font.weight: Font.DemiBold }
                        Txt {
                            Layout.fillWidth: true
                            text: "Thank you. Your testimonial is on chain and counts for Logos Kit."
                            tone: "text2"
                            wrapMode: Text.Wrap
                            elide: Text.ElideNone
                        }
                        InfoRow {
                            visible: !!(root.status && root.status.txHash)
                            label: "Transaction"
                            value: root.status && root.status.txHash ? root.shortId(root.status.txHash.replace("0x", "")) : ""
                            mono: true
                        }
                        InfoRow {
                            visible: !!(root.status && root.status.block)
                            label: "Block"
                            value: root.status && root.status.block ? "#" + root.status.block.id : ""
                        }
                        RowLayout {
                            spacing: 8
                            Btn {
                                objectName: "tmExplorer"
                                visible: root.chain === "lez:testnet" && !!(root.status && root.status.txHash)
                                text: "View on explorer"
                                icon: "external"
                                tone: "action"
                                onClicked: kit.api.openExplorer({ txHash: root.status.txHash }).catch(function (e) { root.note = errText(e) })
                            }
                            Btn { text: "Done"; tone: "neutral"; onClicked: root.phase = "compose" }
                        }
                    }

                    // Failed
                    ColumnLayout {
                        objectName: "tmFailed"
                        visible: root.phase === "failed"
                        Layout.fillWidth: true
                        spacing: 12
                        Txt { text: "Not posted"; font.pixelSize: 18; font.weight: Font.DemiBold }
                        Notice { tone: "danger"; text: root.failure }
                        RowLayout {
                            spacing: 8
                            Btn { objectName: "tmRetry"; text: "Try again"; tone: "ink"; onClicked: { root.phase = "compose"; root.refreshAccount() } }
                        }
                    }
                }
            }

            // Feed
            RowLayout {
                visible: root.programId !== ""
                Layout.fillWidth: true
                Layout.topMargin: 6
                Txt { text: "Latest"; font.pixelSize: 15; font.weight: Font.DemiBold }
                Item { Layout.fillWidth: true }
                Spinner { visible: root.feedLoading && root.feed !== null; size: 14 }
            }
            ColumnLayout {
                visible: root.feed === null && root.feedLoading
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: 3
                    Card {
                        Layout.fillWidth: true
                        RowLayout {
                            width: parent.width
                            spacing: 12
                            Skeleton { implicitWidth: 32; implicitHeight: 32; radius: 16 }
                            ColumnLayout { Layout.fillWidth: true; spacing: 8; Skeleton { Layout.preferredWidth: 120 } Skeleton { Layout.fillWidth: true } }
                        }
                    }
                }
            }
            Notice { visible: root.feedError !== "" && root.feed === null; tone: "warn"; text: root.feedError }
            Txt {
                objectName: "tmEmpty"
                visible: !!root.feed && root.feed.count === 0
                text: "No testimonials yet. Be the first."
                tone: "text2"
            }
            Repeater {
                model: root.feed ? root.feed.latest : []
                Card {
                    Layout.fillWidth: true
                    pad: 16
                    RowLayout {
                        width: parent.width
                        spacing: 12
                        Identicon { seed: modelData.author; size: 32; Layout.alignment: Qt.AlignTop }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            RowLayout {
                                spacing: 6
                                Txt { text: modelData.username || root.shortId(modelData.author); font.pixelSize: 13; font.weight: Font.DemiBold; mono: !modelData.username; Layout.maximumWidth: 220 }
                                Tag { visible: modelData.author === root.account; text: "You"; tone: "action" }
                                Txt { text: "· " + root.ago(modelData.timestampMs); tone: "text3"; font.pixelSize: 12 }
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: modelData.text
                                font.pixelSize: 14
                                wrapMode: Text.Wrap
                                elide: Text.ElideNone
                                lineHeight: 1.2
                            }
                        }
                    }
                }
            }
        }
    }
}
