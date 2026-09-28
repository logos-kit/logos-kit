"""Dev harness for a dApp next to the wallet: two windows, one real engine.

The wallet UI runs as in harness.py. The dApp gets its own `logos` bridge:
`callModuleAsync` reaches the engine as the dApp module would (caller
`{"kind": "module", "name": <app>}`), and `logos.request(intent, …)` opens the
wallet's intent sheet with the dApp as requester, then calls back with the
wallet's answer, like Basecamp's shell. Layout and flow work only: the real
shell chooser, sandbox and identity hop are exercised in Basecamp.

    uv run --python .qt/q692/bin/python modules/logos_kit_wallet_ui/dev/app_harness.py \
        --app logos_kit_testimonial --qml modules/logos_kit_testimonial/qml/Main.qml \
        [--prop chain=lez:local --prop program=<id>] [--script steps.py] [--shots DIR]

A script gets `d` (the dApp's Driver), `w` (the wallet's) and `e` (the engine).
"""
import argparse, json, pathlib, sys, tempfile

from PySide6.QtCore import QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QJSValue
from PySide6.QtQuick import QQuickView

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from harness import QML as WALLET_QML, ROOT, Bridge, Engine  # noqa: E402


class WalletBridge(Bridge):
    """The wallet's bridge; answers to dApp intents go back to the dApp."""

    def __init__(self, engine):
        super().__init__(engine)
        self.pending = {}  # request id -> callback(ok, data, error)

    @Slot(str, bool, "QVariant", str)
    def respond(self, request_id, ok, data, error):
        Bridge.respond(self, request_id, ok, data, error)
        cb = self.pending.pop(request_id, None)
        if cb:
            r = self.responses[-1]
            QTimer.singleShot(0, lambda: cb(r["ok"], r["data"], r["error"]))


class AppBridge(QObject):
    moduleEventReceived = Signal(str, str, "QVariantList")

    def __init__(self, engine, wallet, app):
        super().__init__()
        self.engine, self.wallet, self.app = engine, wallet, app
        self.view = None
        self.calls = []

    @Slot(str, str, "QVariantList", QJSValue, int)
    def callModuleAsync(self, module, method, args, callback, timeout):
        params = json.loads(args[0]) if args else {}
        ans = self.engine.call(method, params, caller={"kind": "module", "name": self.app})
        self.calls.append((method, "error" not in ans))
        # Engine events belong to the wallet window.
        for e in self.engine.events():
            name = "request_updated" if e.get("event") in ("request_updated", "request_opened") else "wallet_event"
            QTimer.singleShot(0, lambda n=name: self.wallet.moduleEventReceived.emit("logos_kit_wallet", n, []))
        payload = json.dumps(ans)
        QTimer.singleShot(0, lambda: callback.call([payload]))

    @Slot(str, "QVariant", QJSValue)
    def request(self, intent, params, callback):
        if isinstance(params, QJSValue):
            params = params.toVariant()
        print("INTENT", self.app, intent, json.dumps(params, default=str)[:300], flush=True)
        rid = self.wallet.intent(intent, params, requester=self.app)

        def answer(ok, data, error):
            res = {"ok": ok}
            if ok:
                res["data"] = data
            else:
                res["error"] = error
            callback.call([self.view.engine().toScriptValue(res)])

        self.wallet.pending[rid] = answer

    @Slot(str, str, result=bool)
    def onModuleEvent(self, module, event):
        return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", required=True)
    ap.add_argument("--qml", required=True)
    ap.add_argument("--prop", action="append", default=[], help="initial root property key=value")
    ap.add_argument("--data", default=None)
    ap.add_argument("--lib", default=str(ROOT / "target/release/libwallet_engine.dylib"))
    ap.add_argument("--width", type=int, default=520)
    ap.add_argument("--height", type=int, default=820)
    ap.add_argument("--script", default=None)
    ap.add_argument("--shots", default=str(ROOT / "docs/reviews/s8"))
    a = ap.parse_args()

    data = pathlib.Path(a.data or tempfile.mkdtemp(prefix="lk-app-"))
    qapp = QGuiApplication(sys.argv)
    engine = Engine(a.lib, data)
    wbridge = WalletBridge(engine)
    abridge = AppBridge(engine, wbridge, a.app)

    wview = QQuickView()
    wview.setTitle("Logos Kit Wallet")
    wview.rootContext().setContextProperty("logos", wbridge)
    wview.setResizeMode(QQuickView.SizeRootObjectToView)
    wview.resize(440, 780)
    wview.setSource(QUrl.fromLocalFile(str(WALLET_QML)))

    aview = QQuickView()
    aview.setTitle(a.app)
    abridge.view = aview
    aview.rootContext().setContextProperty("logos", abridge)
    aview.setResizeMode(QQuickView.SizeRootObjectToView)
    aview.resize(a.width, a.height)
    aview.setInitialProperties(dict(p.split("=", 1) for p in a.prop))
    aview.setSource(QUrl.fromLocalFile(str(ROOT / a.qml)))

    for v in (wview, aview):
        for e in v.errors():
            print("QML ERROR", e.toString())
        if v.status() != QQuickView.Ready:
            sys.exit(1)
    aview.setPosition(40, 60)
    wview.setPosition(40 + a.width + 20, 60)
    aview.show()
    wview.show()

    if a.script:
        from driver import Driver  # noqa: E402
        shots = pathlib.Path(a.shots)
        d = Driver(qapp, aview, abridge, engine, shots)
        w = Driver(qapp, wview, wbridge, engine, shots)
        ns = {"d": d, "w": w, "e": engine, "json": json}
        code = compile(open(a.script).read(), a.script, "exec")
        QTimer.singleShot(300, lambda: d.run(code, ns))
    sys.exit(qapp.exec())


if __name__ == "__main__":
    main()
