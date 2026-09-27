// Logos Kit for Basecamp QML apps: a thin wrapper that hands the SDK the
// bridge (`logos`) and QML timers. Everything else lives in logoskit.js.
//
//   import "LogosKit"   // this folder, copied into your ui_qml module
//   LogosKit { id: kit; chain: "lez:testnet"; visible: root.visible }
//   kit.api.connect().then(function (session) { ... })
//
// Your metadata.json must list the intents it uses:
//   "uses": [{"intent": "lez.wallet.connect", "cardinality": "single"},
//            {"intent": "lez.transaction.send", "cardinality": "single"}, …]
import QtQml
import "logoskit.js" as SDK

QtObject {
    id: kit

    property string chain: "lez:testnet"
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

    Component.onCompleted: {
        SDK.LogosKit.installQmlHost({ setTimeout: _setTimeout, clearTimeout: _clearTimeout })
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
