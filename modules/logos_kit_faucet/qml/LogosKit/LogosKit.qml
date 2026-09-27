// Logos Kit for Basecamp QML apps: a thin wrapper that hands the SDK the
// bridge (`logos`) and QML timers. Everything else lives in logoskit.js.
//
//   import "LogosKit"   // this folder, copied into your ui_qml module
//   LogosKit { id: kit; visible: root.visible }
//   kit.api.connect().then(function (session) { ... })
//
// `chain` follows the network the wallet is on (like wagmi following the
// wallet); set `followWallet: false` to pin it. `api` is rebuilt when the
// chain changes, so read `kit.api` each time rather than keeping it.
//
// Your metadata.json must list the intents it uses:
//   "uses": [{"intent": "lez.wallet.connect", "cardinality": "single"},
//            {"intent": "lez.transaction.send", "cardinality": "single"}, …]
import QtQml
import "logoskit.js" as SDK

QtObject {
    id: kit

    property string chain: "lez:testnet"
    /** Switch `chain` to the wallet's network (checked on start, when shown, and every 5 s while visible). */
    property bool followWallet: true
    /** Status polling pauses while false (bind it to your view's visibility). */
    property bool visible: true
    /** Wallet core module name. */
    property string module: "logos_kit_wallet"
    /** The SDK (see createLogosKit in packages/qml-bundle/src/facade.ts). */
    readonly property var api: _api
    readonly property var sdk: SDK.LogosKit

    property var _api: null
    property int _nextTimer: 1
    property var _timers: ({})

    function _setTimeout(fn, ms) {
        var t = Qt.createQmlObject("import QtQml; Timer { repeat: false }", kit)
        var id = _nextTimer++
        _timers[id] = t
        t.interval = ms || 0
        t.triggered.connect(function () {
            delete _timers[id]
            t.destroy()
            fn()
        })
        t.start()
        return id
    }

    function _clearTimeout(id) {
        var t = _timers[id]
        if (t) {
            t.stop()
            t.destroy()
            delete _timers[id]
        }
    }

    property bool _ready: false

    function _follow() {
        if (!followWallet || !_api) return
        _api.getChainId().then(function (c) { if (c && c !== kit.chain) kit.chain = c }, function () {})
    }

    onChainChanged: if (_ready) _create()
    onVisibleChanged: if (visible) _follow()

    // The user can switch the wallet's network while the app is open.
    property Timer _followTimer: Timer {
        interval: 5000
        repeat: true
        running: kit.followWallet && kit.visible && kit._ready
        onTriggered: kit._follow()
    }

    Component.onCompleted: {
        SDK.LogosKit.installQmlHost({ setTimeout: _setTimeout, clearTimeout: _clearTimeout })
        _ready = true
        _create()
        _follow()
    }

    function _create() {
        _api = SDK.LogosKit.createLogosKit({
            chain: chain,
            module: module,
            isVisible: function () { return kit.visible },
            callModuleAsync: function (m, method, args, cb, timeoutMs) {
                logos.callModuleAsync(m, method, args, cb, timeoutMs)
            },
            openIntent: function (intent, params, cb) {
                logos.request(intent, params, cb)
            }
        })
    }
}
