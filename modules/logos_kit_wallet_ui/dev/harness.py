"""Dev harness for the wallet UI: the real QML against the real engine, no Basecamp.

A stand-in `logos` bridge answers `callModuleAsync` by calling
libwallet_engine (ctypes) with the caller the module shim would attest
(`logos_kit_wallet_ui`), in the same {"value"}/{"error"} form. Intents can be
simulated. For layout and flow work only: the real sandbox, shell chooser and
identity hop are exercised in Basecamp (QA step 4 in docs/dev/PLAN.md).

    uv run --python .qt/q692/bin/python modules/logos_kit_wallet_ui/dev/harness.py \
        [--data DIR] [--width 480] [--height 780] [--script steps.py] [--shots DIR]
"""
import argparse, ctypes, json, os, sys, tempfile, time, pathlib

from PySide6.QtCore import QObject, Signal, Slot, QTimer, QUrl, QMetaObject, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QJSValue
from PySide6.QtQuick import QQuickView

ROOT = pathlib.Path(__file__).resolve().parents[3]
QML = ROOT / "modules/logos_kit_wallet_ui/qml/Main.qml"
UI = {"kind": "module", "name": "logos_kit_wallet_ui"}


class Engine:
    def __init__(self, lib, data):
        # Apps' metadata.json + icons (Basecamp: <user dir>/plugins).
        os.environ.setdefault("LOGOS_KIT_PLUGINS_DIR", str(ROOT / "modules"))
        self.lib = ctypes.CDLL(str(lib))
        for f in ("lk_engine_call", "lk_engine_init"):
            getattr(self.lib, f).restype = ctypes.c_void_p
            getattr(self.lib, f).argtypes = [ctypes.c_char_p]
        self.lib.lk_engine_events.restype = ctypes.c_void_p
        self.lib.lk_engine_free.argtypes = [ctypes.c_void_p]
        print("init", self._take(self.lib.lk_engine_init(json.dumps({"dataDir": str(data)}).encode())))

    def _take(self, ptr):
        s = ctypes.cast(ptr, ctypes.c_char_p).value.decode()
        self.lib.lk_engine_free(ptr)
        return json.loads(s)

    def call(self, method, params, caller=UI):
        req = {"method": method, "params": params, "caller": caller}
        out = self._take(self.lib.lk_engine_call(json.dumps(req).encode()))
        return {"value": out.get("result")} if out.get("ok") else {"error": out.get("error")}

    def events(self):
        return self._take(self.lib.lk_engine_events())


class Bridge(QObject):
    moduleEventReceived = Signal(str, str, "QVariantList")
    intentRequested = Signal(str, str, "QVariantMap", str)
    viewModuleReadyChanged = Signal(str, bool)

    def __init__(self, engine):
        super().__init__()
        self.engine = engine
        self.responses = []
        self._n = 0

    @Slot(str, str, "QVariantList", QJSValue, int)
    def callModuleAsync(self, module, method, args, callback, timeout):
        if method == "ui":
            ans = self.engine.call("ui_" + args[0], json.loads(args[1] or "{}"))
        else:
            ans = self.engine.call(method, json.loads(args[0]) if args else {})
        payload = json.dumps(ans)
        for e in self.engine.events():
            name = "request_updated" if e.get("event") in ("request_updated", "request_opened") else "wallet_event"
            QTimer.singleShot(0, lambda n=name: self.moduleEventReceived.emit("logos_kit_wallet", n, []))
        QTimer.singleShot(0, lambda: callback.call([payload]))

    @Slot(str, str, result=bool)
    def onModuleEvent(self, module, event):
        return True

    @Slot(str, bool, "QVariant", str)
    def respond(self, request_id, ok, data, error):
        if isinstance(data, QJSValue):
            data = data.toVariant()
        print("RESPOND", request_id, ok, json.dumps(data, default=str)[:400], error, flush=True)
        self.responses.append({"id": request_id, "ok": ok, "data": data, "error": error})

    def intent(self, name, params, requester="probe_dapp"):
        self._n += 1
        rid = f"req-{self._n}"
        self.intentRequested.emit(rid, name, params, requester)
        return rid


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=None)
    ap.add_argument("--lib", default=str(ROOT / "target/release/libwallet_engine.dylib"))
    ap.add_argument("--width", type=int, default=480)
    ap.add_argument("--height", type=int, default=780)
    ap.add_argument("--script", default=None)
    ap.add_argument("--shots", default=str(ROOT / "docs/reviews/s7"))
    a = ap.parse_args()
    data = pathlib.Path(a.data or tempfile.mkdtemp(prefix="lk-ui-"))
    app = QGuiApplication(sys.argv)
    engine = Engine(a.lib, data)
    bridge = Bridge(engine)
    view = QQuickView()
    view.rootContext().setContextProperty("logos", bridge)
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.resize(a.width, a.height)
    view.setSource(QUrl.fromLocalFile(str(QML)))
    for e in view.errors():
        print("QML ERROR", e.toString())
    if view.status() != QQuickView.Ready:
        sys.exit(1)
    view.show()
    if a.script:
        from driver import Driver  # noqa: E402
        sys.path.insert(0, str(pathlib.Path(a.script).parent))
        drv = Driver(app, view, bridge, engine, pathlib.Path(a.shots))
        ns = {"d": drv}
        code = compile(open(a.script).read(), a.script, "exec")
        QTimer.singleShot(300, lambda: drv.run(code, ns))
    sys.exit(app.exec())


if __name__ == "__main__":
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    main()
