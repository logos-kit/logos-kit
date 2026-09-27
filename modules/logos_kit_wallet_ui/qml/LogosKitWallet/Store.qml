import QtQuick
import "Fmt.js" as Fmt

// The only file that touches `logos`. Every view reads parsed properties from
// here and calls `call()`; nothing else knows about the bridge, the core
// module or JSON.
//
// The core answers `{"value": …}` or `{"error": {code, message}}` (the bridge
// hands it over as JSON text). Intents are held here, one at a time, and
// answered exactly once with `respond`.
QtObject {
    id: store

    readonly property string core: "logos_kit_wallet"
    readonly property bool bridge: typeof logos !== "undefined" && logos !== null

    // ui_state
    property var state: ({})
    property bool loaded: false
    // The core didn't answer at all (not installed, crashed, still starting).
    property string unreachable: ""
    readonly property bool initialized: state.initialized === true
    readonly property bool unlocked: state.unlocked === true
    readonly property var zone: state.zone || ({})
    readonly property var pending: state.pending || null
    readonly property var active: state.active || null
    readonly property var network: state.status ? state.status.network : null
    readonly property bool offline: !!network && network.state === "offline"

    // ui_snapshot + ui_activity
    property var accounts: []
    property real snapshotMs: 0
    property var tip: null
    property string syncError: ""
    property var activity: []

    // The account the home screen shows.
    property string selected: ""
    readonly property var current: {
        for (var i = 0; i < accounts.length; i++)
            if (accounts[i].accountId === selected) return accounts[i]
        return accounts.length > 0 ? accounts[0] : null
    }

    // The latest faucet request the user started here: {job, state, result|error}.
    property var funding: null
    function requestFunds(account, cb) {
        call("requestFunds", { account: account }, function (v, e) {
            if (!e) store.funding = { job: v.job, state: "running", account: account }
            if (cb) cb(v, e)
        })
    }
    property Timer fundingTimer: Timer {
        interval: 1500
        repeat: true
        running: store.funding !== null && store.funding.state === "running"
        onTriggered: store.call("fundStatus", { job: store.funding.job }, function (v, e) {
            if (e || !v) return
            if (v.state !== "running") { v.job = store.funding.job; store.funding = v; store.refreshAll() }
        })
    }

    // The intent being served: {requestId, intent, params, requester}.
    property var intent: null
    // Requesting apps' display name + icon, by module name (appInfo).
    property var apps: ({})
    function loadApp(requester) {
        if (!requester || apps[requester]) return
        call("appInfo", { requester: requester }, function (info) {
            if (!info) return
            var next = Object.assign({}, apps)
            next[requester] = info
            apps = next
        })
    }
    // The app's own name when it has one; the module name otherwise.
    function appName(requester) {
        var a = apps[requester]
        return a && a.displayName ? a.displayName : requester
    }
    // Set when a private send, shield or dApp request should show its proof.
    property string watching: ""

    signal intentArrived()
    signal toast(string text, string tone)

    function parse(raw) {
        var v = raw
        for (var i = 0; i < 3 && typeof v === "string"; i++) {
            try { v = JSON.parse(v) } catch (e) { break }
        }
        return v
    }

    // call("state", {}, function(value, error) {…})
    function call(method, params, cb, timeoutMs) {
        if (!bridge || !logos.callModuleAsync) {
            if (cb) cb(null, { code: 6109, message: "Basecamp bridge unavailable" })
            return
        }
        logos.callModuleAsync(core, "ui", [method, JSON.stringify(params || {})], function (raw) {
            var r = store.parse(raw)
            var err = null, value = null
            if (r && typeof r === "object" && ("value" in r)) value = r.value
            else if (r && typeof r === "object" && r.error !== undefined)
                err = typeof r.error === "string"
                    ? { code: 6108, message: r.error === "timeout" ? "The wallet didn't answer in time" : r.error }
                    : r.error
            else err = { code: -32603, message: "Unexpected answer from the wallet core" }
            if (cb) cb(value, err)
        }, timeoutMs || 20000)
    }

    // Assign only on change: replacing an array rebuilds every delegate that
    // shows it (activity rows, account chips) on each poll.
    property string _stateKey: ""
    property string _accountsKey: ""
    property string _activityKey: ""
    function setActivity(v) {
        var k = JSON.stringify(v)
        if (k !== _activityKey) { _activityKey = k; activity = v }
    }

    function refreshState(cb) {
        call("state", {}, function (v, e) {
            if (e) {
                if (!store.loaded) store.unreachable = Fmt.errorText(e)
                if (cb) cb(false)
                return
            }
            store.unreachable = ""
            if (v && v.zone && store.zone.id && v.zone.id !== store.zone.id) store.selected = ""
            var k = JSON.stringify(v || {})
            if (k !== store._stateKey) { store._stateKey = k; store.state = v || {} }
            store.loaded = true
            if (v && v.theme) Theme.dark = v.theme !== "light"
            if (!store.unlocked && store.accounts.length) {
                store.accounts = []; store._accountsKey = ""
                store.activity = []; store._activityKey = ""
            }
            if (cb) cb(true)
        })
    }

    function refreshData() {
        if (!unlocked) return
        call("snapshot", {}, function (v, e) {
            if (e || !v) return
            // A fresh session (unlock, zone switch) starts empty: drop the old list.
            if (!v.updatedMs && store.accounts.length) {
                store.accounts = []; store._accountsKey = ""; store.selected = ""
            }
            if (v.accounts && v.accounts.length) {
                var k = JSON.stringify(v.accounts)
                if (k !== store._accountsKey) { store._accountsKey = k; store.accounts = v.accounts }
            }
            store.snapshotMs = v.updatedMs || 0
            store.tip = v.tip
            store.syncError = v.error || ""
            if (store.selected === "" && store.accounts.length > 0) {
                // Start on the first private account (Tray home shows the private balance).
                for (var i = 0; i < store.accounts.length; i++)
                    if (store.accounts[i].kind === "private") { store.selected = store.accounts[i].accountId; break }
                if (store.selected === "") store.selected = store.accounts[0].accountId
            }
        })
        call("activity", {}, function (v, e) { if (!e && v) store.setActivity(v) })
    }

    function refreshAll() {
        refreshState(function (ok) { if (ok) store.refreshData() })
    }

    function syncNow() { call("refresh", {}, null) }

    function touch() { if (unlocked) call("touch", {}, null) }

    function statusOf(handle) {
        for (var i = 0; i < activity.length; i++)
            if (activity[i].handle === handle) return activity[i]
        return null
    }

    // Clipboard through an off-screen TextEdit (no clipboard API in QML).
    property TextEdit clipboard: TextEdit { visible: false }
    function copy(text) {
        clipboard.text = text
        clipboard.selectAll()
        clipboard.copy()
        clipboard.text = ""
        toast("Copied", "ok")
    }

    // -- intents ---------------------------------------------------------------

    function receiveIntent(requestId, name, params, requester) {
        if (intent !== null) {
            // One at a time; the shell rarely lets a second through.
            logos.respond(requestId, false, ({}), "failed")
            return
        }
        intent = { requestId: requestId, intent: name, params: params || {}, requester: requester || "" }
        loadApp(requester)
        intentArrived()
    }

    // Answer the open intent once. `error` is one of the shell's codes
    // (cancelled, bad_request, failed); anything else is coerced to failed.
    function answer(ok, data, error) {
        if (intent === null) return
        var id = intent.requestId
        intent = null
        if (bridge && logos.respond) logos.respond(id, ok, data === undefined ? ({}) : data, ok ? "" : (error || "failed"))
    }

    // -- polling -----------------------------------------------------------------

    property Timer stateTimer: Timer {
        interval: store.unlocked ? 2500 : 4000
        running: store.bridge
        repeat: true
        triggeredOnStart: true
        onTriggered: store.refreshAll()
    }

    // Fast while something is being proved or sent.
    property Timer busyTimer: Timer {
        interval: 1000
        running: store.bridge && store.unlocked && (store.active !== null || store.watching !== "")
        repeat: true
        onTriggered: store.call("activity", {}, function (v, e) { if (!e && v) store.setActivity(v) })
    }

    property Connections events: Connections {
        target: store.bridge ? logos : null
        ignoreUnknownSignals: true
        function onModuleEventReceived(moduleName, eventName, data) {
            if (moduleName !== store.core) return
            store.refreshAll()
        }
        function onIntentRequested(requestId, intent, params, requesterName) {
            store.receiveIntent(requestId, intent, params, requesterName)
        }
    }

    Component.onCompleted: {
        if (bridge && logos.onModuleEvent) {
            logos.onModuleEvent(core, "request_updated")
            logos.onModuleEvent(core, "wallet_event")
        }
    }
}
