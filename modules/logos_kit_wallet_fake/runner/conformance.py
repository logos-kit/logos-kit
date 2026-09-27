"""Logos Kit conformance runner: a dApp's real QML against the fake wallet.

    just conformance <dapp dir>            # every scenario, headless
    uv run --python .qt/q692/bin/python modules/logos_kit_wallet_fake/runner/conformance.py \
        <dapp dir> [--scenario happy --scenario reject …] [--journey file.py] [--show]

<dapp dir> holds the module's metadata.json (ui_qml) and its QML. The runner
plays Basecamp's part for that view: `logos.callModuleAsync` reaches the fake
engine (libwallet_engine from modules/logos_kit_wallet_fake/engine) with the
dApp's module name as the attested caller, and `logos.request(intent, …)` is
delivered like the shell does (undeclared intents answer `not_declared`),
answered by the fake per scenario. A journey (the dApp's own clicks) drives
the flow; the runner then checks what the dApp did, from the fake's call log
and its own record of user actions, prompts and console errors.

It is not Basecamp: no sandbox, no shell chooser, no process hop. Those are
exercised by installing the dApp next to the fake in a real Basecamp
(docs/dev/conformance.md).
"""
import argparse, ctypes, importlib.util, json, os, pathlib, re, sys, time

from PySide6.QtCore import QEventLoop, QMetaObject, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QJSValue
from PySide6.QtQuick import QQuickView

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SCHEMA = ROOT / "protocol/schema"
LIB = HERE.parent / "engine/target/release" / ("libwallet_engine.dylib" if sys.platform == "darwin" else "libwallet_engine.so")
FINAL = {"included", "finalized", "rejected", "dropped", "expired"}
JS_ERROR = re.compile(r"TypeError|ReferenceError|SyntaxError|RangeError|is not a function|Cannot read property|Unable to assign|is not defined|Error: ")


# -- schema ------------------------------------------------------------------------------

def validate(value, schema, path="$"):
    """The JSON Schema subset LWS-0 uses. Returns a list of problems."""
    out = []
    if "anyOf" in schema:
        if all(validate(value, s, path) for s in schema["anyOf"]):
            out.append(f"{path}: matches none of anyOf")
        return out
    for s in schema.get("allOf", []):
        out += validate(value, s, path)
    t = schema.get("type")
    kinds = {"object": dict, "array": list, "string": str, "boolean": bool, "null": type(None)}
    if t == "integer":
        if not isinstance(value, int) or isinstance(value, bool):
            return [f"{path}: expected integer"]
    elif t == "number":
        if not isinstance(value, (int, float)) or isinstance(value, bool):
            return [f"{path}: expected number"]
    elif t in kinds and not isinstance(value, kinds[t]):
        return [f"{path}: expected {t}, got {type(value).__name__}"]
    if "const" in schema and value != schema["const"]:
        out.append(f"{path}: must be {schema['const']!r}")
    if isinstance(value, str):
        if "pattern" in schema and not re.search(schema["pattern"], value):
            out.append(f"{path}: {value[:40]!r} doesn't match {schema['pattern']}")
        if len(value) < schema.get("minLength", 0) or len(value) > schema.get("maxLength", 1 << 30):
            out.append(f"{path}: length {len(value)} out of range")
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if value < schema.get("minimum", float("-inf")) or value > schema.get("maximum", float("inf")):
            out.append(f"{path}: {value} out of range")
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0) or len(value) > schema.get("maxItems", 1 << 30):
            out.append(f"{path}: {len(value)} items out of range")
        if "items" in schema:
            for i, v in enumerate(value):
                out += validate(v, schema["items"], f"{path}[{i}]")
    if isinstance(value, dict):
        for k in schema.get("required", []):
            if k not in value:
                out.append(f"{path}: missing {k}")
        props = schema.get("properties", {})
        for k, v in value.items():
            if k in props:
                out += validate(v, props[k], f"{path}.{k}")
            else:
                for pat, s in schema.get("patternProperties", {}).items():
                    if re.search(pat, k):
                        out += validate(v, s, f"{path}.{k}")
    return out


# -- the fake -------------------------------------------------------------------------------

class Fake:
    def __init__(self, lib):
        self.lib = ctypes.CDLL(str(lib))
        for f in ("lk_engine_call", "lk_engine_init"):
            getattr(self.lib, f).restype = ctypes.c_void_p
            getattr(self.lib, f).argtypes = [ctypes.c_char_p]
        self.lib.lk_engine_events.restype = ctypes.c_void_p
        self.lib.lk_engine_free.argtypes = [ctypes.c_void_p]
        self._take(self.lib.lk_engine_init(b"{}"))

    def _take(self, ptr):
        s = ctypes.cast(ptr, ctypes.c_char_p).value.decode()
        self.lib.lk_engine_free(ptr)
        return json.loads(s)

    def raw(self, method, params, caller):
        req = {"method": method, "params": params, "caller": caller}
        return self._take(self.lib.lk_engine_call(json.dumps(req).encode()))

    def call(self, method, params, app):
        """What the core module shim answers: {"value"} or {"error"}."""
        out = self.raw(method, params, {"kind": "module", "name": app})
        return {"value": out.get("result")} if out.get("ok") else {"error": out.get("error")}

    def ui(self, method, params=None):
        out = self.raw("ui_" + method, params or {}, {"kind": "module", "name": "conformance"})
        if not out.get("ok"):
            raise RuntimeError(f"fake ui_{method}: {out.get('error')}")
        return out["result"]

    def events(self):
        return self._take(self.lib.lk_engine_events())


# -- Basecamp's part for one view -------------------------------------------------------------

class Host(QObject):
    moduleEventReceived = Signal(str, str, "QVariantList")

    def __init__(self, fake, app, uses, run):
        super().__init__()
        self.fake, self.app, self.uses, self.run = fake, app, uses, run
        self.view = None

    @Slot(str, str, "QVariantList", QJSValue, int)
    def callModuleAsync(self, module, method, args, callback, timeout):
        self.run.mark("call", method)
        if module != "logos_kit_wallet":
            ans = {"error": {"code": -32601, "message": f"no module {module} in this run"}}
            self.run.problems_misc.append(f"called unknown module {module}.{method}")
        else:
            try:
                params = json.loads(args[0]) if args and args[0] else {}
            except (TypeError, ValueError):
                params = None
            if params is None:
                self.run.bad_args.append(method)
                ans = {"error": {"code": -32602, "message": "params must be JSON"}}
            else:
                ans = self.fake.call(method, params, self.app)
        for e in self.fake.events():
            name = "request_updated" if e.get("event") == "request_updated" else "wallet_event"
            QTimer.singleShot(0, lambda n=name: self.moduleEventReceived.emit("logos_kit_wallet", n, []))
        payload = json.dumps(ans)
        QTimer.singleShot(0, lambda: callback.call([payload]))

    @Slot(str, str, "QVariantList", result=str)
    def callModule(self, module, method, args):
        self.run.problems_misc.append(f"used blocking callModule for {method} (use callModuleAsync)")
        params = json.loads(args[0]) if args else {}
        return json.dumps(self.fake.call(method, params, self.app))

    @Slot(str, "QVariant", QJSValue)
    def request(self, intent, params, callback):
        if isinstance(params, QJSValue):
            params = params.toVariant()
        params = json.loads(json.dumps(params, default=str)) if params is not None else {}
        self.run.mark("intent", intent, params)

        def deliver(res):
            self.run.mark("answer", intent, res)
            callback.call([self.view.engine().toScriptValue(res)])

        if intent not in self.uses:
            QTimer.singleShot(0, lambda: deliver({"ok": False, "error": "not_declared"}))
            return
        a = self.fake.ui("fakeIntent", {"intent": intent, "params": params, "requester": self.app})
        res = {"ok": True, "data": a.get("data")} if a.get("ok") else {"ok": False, "error": a.get("error", "failed")}
        self.run.pending += 1

        def later():
            self.run.pending -= 1
            deliver(res)

        QTimer.singleShot(int(a.get("delayMs", 0)) or 150, later)

    @Slot(str, str, result=bool)
    def onModuleEvent(self, module, event):
        return True


class Run:
    """One scenario: the view, the journey's actions and everything observed."""

    def __init__(self, qapp, scenario):
        self.qapp, self.scenario = qapp, scenario
        self.t0 = time.time()
        self.timeline = []      # (t, kind, name, detail)
        self.console = []
        self.bad_args = []
        self.problems_misc = []
        self.journey_problems = []
        self.pending = 0
        self.view = None

    def mark(self, kind, name, detail=None):
        self.timeline.append((time.time() - self.t0, kind, name, detail))

    # -- journey API ---------------------------------------------------------------
    def pump(self, ms=50):
        end = time.time() + ms / 1000
        while time.time() < end:
            self.qapp.processEvents(QEventLoop.AllEvents, 20)
            time.sleep(0.005)

    def items(self, item=None):
        item = item or self.view.rootObject()
        yield item
        for c in item.childItems():
            yield from self.items(c)

    def _shown(self, o):
        while o is not None:
            if not o.isVisible():
                return False
            o = o.parentItem()
        return True

    def find(self, name):
        for o in self.items():
            if o.objectName() == name and self._shown(o):
                return o
        return None

    def wait(self, cond, timeout=10):
        end = time.time() + timeout
        while time.time() < end:
            try:
                if cond():
                    return True
            except Exception:
                pass
            self.pump(100)
        return False

    def click(self, name, timeout=10):
        """Click a Btn (or anything with `clicked`) by objectName; False if it never shows up enabled."""
        ok = self.wait(lambda: (o := self.find(name)) is not None and o.property("enabled")
                       and o.property("armed") in (None, True) and not o.property("busy"), timeout)
        if not ok:
            return False
        self.mark("action", name)
        QMetaObject.invokeMethod(self.find(name), "clicked")
        self.pump(200)
        return True

    def type(self, name, text):
        if not self.wait(lambda: self.find(name) is not None, 10):
            return False
        self.mark("action", "type:" + name)
        self.find(name).setProperty("text", text)
        self.pump(80)
        return True

    def prop(self, name, key):
        o = self.find(name)
        return o.property(key) if o else None

    def text(self):
        """Every visible text on screen, joined (for expectations)."""
        out = []
        for o in self.items():
            t = o.property("text")
            if isinstance(t, str) and t and self._shown(o):
                out.append(t)
        return "\n".join(out)

    def settle(self, quiet_ms=1500, max_s=30):
        """Wait until the dApp and the wallet have been quiet for `quiet_ms`."""
        end = time.time() + max_s
        while time.time() < end:
            n = len(self.timeline)
            self.pump(quiet_ms)
            if len(self.timeline) == n and self.pending == 0:
                return True
        return False

    def expect(self, cond, message):
        if not cond:
            self.journey_problems.append(message)
        return cond

    def shot(self, path):
        self.pump(400)
        self.view.grabWindow().save(str(path))


# -- checks -------------------------------------------------------------------------------------

def check(run, log, methods, intents, uses):
    """(check id, passed, detail) for everything the run shows."""
    calls = [e for e in log if e["kind"] == "call"]
    prompts = [e for e in log if e["kind"] == "intent"]
    results = []

    def add(cid, problems, what):
        results.append((cid, not problems, what if not problems else "; ".join(problems[:4]) + (" …" if len(problems) > 4 else "")))

    errs = [m for m in run.console if JS_ERROR.search(m)]
    add("no-js-errors", errs, "no JavaScript errors in the console")

    add("lws0-methods-only", [f"{c['method']}" for c in calls if c["method"] not in methods["methods"]]
        + run.problems_misc, "only LWS-0 methods on the wallet module")

    bad = []
    for c in calls:
        spec = methods["methods"].get(c["method"])
        if spec:
            bad += [f"{c['method']} {p}" for p in validate(c["params"], spec["params"])]
    bad += [f"{m}: params not JSON" for m in run.bad_args]
    add("params-valid", bad, "every call's params match methods.json")

    by_intent = {i["intent"]: i for i in intents["intents"]}
    asked = [(n, d) for _, k, n, d in run.timeline if k == "intent"]
    add("intents-declared", [f"{n} not in metadata uses" for n, _ in asked if n not in uses]
        + [f"{n} is not an LWS-0 intent" for n, _ in asked if n not in by_intent], "every prompt is a declared LWS-0 intent")

    bad = []
    for n, d in asked:
        if n in by_intent:
            spec = methods["methods"][by_intent[n]["method"]]["params"]
            bad += [f"{n} {p}" for p in validate(d or {}, spec)]
    add("intent-params-valid", bad, "every prompt's params match the method schema")

    # A wallet prompt only after the user did something (no prompt on load, no auto-retry).
    bad, acted = [], False
    for _, k, n, _ in run.timeline:
        if k == "action":
            acted = True
        elif k == "intent":
            if not acted:
                bad.append(f"{n} without a user action")
            acted = False
    add("prompts-follow-user-actions", bad, "every wallet prompt follows a user action")

    direct = [c["method"] for c in calls if methods["methods"].get(c["method"], {}).get("userFacing")
              and not (c["method"] == "lez_connect" and c["params"].get("silent") is True)]
    add("user-steps-via-intents", [f"called {m} directly" for m in direct], "user-facing steps go through intents")

    issued = set()
    for p in prompts:
        if p["answer"].get("ok") and isinstance(p["answer"].get("data"), dict) and p["answer"]["data"].get("handle"):
            issued.add(p["answer"]["data"]["handle"])
    for c in calls:
        if c["method"] == "lez_signAndSendTransaction" and c["answer"].get("ok"):
            issued.add(c["answer"]["value"]["handle"])
    reads = [c for c in calls if c["method"] == "lez_getTransactionStatus"]
    add("known-handles", [f"status of {r['params'].get('handle')!r}" for r in reads if r["params"].get("handle") not in issued],
        "status reads only for handles the wallet issued")

    bad = []
    for h in issued:
        rs = [r for r in reads if r["params"].get("handle") == h]
        after = 0
        for r in rs:
            if after:
                after += 1
            elif r["answer"].get("ok") and r["answer"]["value"]["lifecycle"] in FINAL:
                after = 1
        if after > 3:
            bad.append(f"{h}: {after - 1} reads after it was final")
        if len(rs) > 120:
            bad.append(f"{h}: {len(rs)} status reads")
    add("polling-stops", bad, "status polling stops at a final lifecycle")

    times = [t for t, k, _, _ in run.timeline if k == "call"]
    peak = max((sum(1 for u in times if t <= u < t + 5) for t in times), default=0)
    add("no-call-storm", [f"{peak} calls in 5 s"] if peak > 50 else [], f"calm (peak {peak} calls in 5 s)")

    ids = [d.get("id") for n, d in asked if n == "lez.transaction.send" and d and d.get("id")]
    add("unique-proposal-ids", [f"id {i} reused" for i in set(ids) if ids.count(i) > 1], "proposal ids are never reused")

    # -- per scenario --------------------------------------------------------------------------
    s = run.scenario
    seq_of = lambda pred: next((e["seq"] for e in log if pred(e)), None)
    if s == "happy":
        bad = [f"{h} never read to a final state" for h in issued
               if not any(r["params"].get("handle") == h and r["answer"].get("ok") and r["answer"]["value"]["lifecycle"] in FINAL for r in reads)]
        if not any(p["name"] == "lez.wallet.connect" and p["answer"].get("ok") for p in prompts):
            bad.append("never connected")
        add("happy-path-completes", bad, "connects and follows every transaction to the end")
    elif s == "timeout":
        late = [(t, d) for t, k, n, d in run.timeline if k == "answer" and n == "lez.transaction.send" and d.get("ok")]
        if not late:
            add("late-result-followed", ["the journey never sent (nothing to time out)"], "")
        else:
            h = late[-1][1]["data"]["handle"]
            followed = any(t >= late[-1][0] and k == "call" and n == "lez_getTransactionStatus" for t, k, n, _ in run.timeline) \
                and any(r["params"].get("handle") == h for r in reads)
            add("late-result-followed", [] if followed else [f"the late handle {h} was never read (onLateResult)"],
                "a send answered after the SDK's timeout is still followed")
    elif s == "network_switch":
        sw = seq_of(lambda e: e["kind"] == "call" and e["method"] == "lez_chainId" and e["answer"].get("ok")
                    and e["answer"]["value"]["chain"] == "lez:local")
        if sw is None:
            add("follows-network-switch", ["never noticed the wallet's new network (lez_chainId)"], "")
        else:
            after = [e for e in calls if e["seq"] > sw]
            bad = [f"{e['method']} still names lez:testnet" for e in after if e["params"].get("chain") == "lez:testnet"]
            if not any(e["method"] in ("lez_getSession", "lez_getAccounts") for e in after):
                bad.append("didn't re-read the session on the new network")
            add("follows-network-switch", bad, "follows the wallet to the new network and drops the old session")
    elif s == "faucet_unknown":
        u = seq_of(lambda e: e["kind"] == "intent" and e["name"] == "lez.wallet.request_funds"
                   and (e["answer"].get("data") or {}).get("status") == "outcome_unknown")
        if u is not None:
            ok = any(e["seq"] > u and e["method"] == "lez_getBalance" for e in calls)
            add("unknown-funds-rechecked", [] if ok else ["didn't re-read the balance after an unknown faucet outcome"],
                "re-reads the balance when the faucet outcome is unknown")
    elif s == "unknown_outcome":
        u = seq_of(lambda e: e["kind"] == "call" and e["method"] == "lez_getTransactionStatus" and e["answer"].get("ok")
                   and e["answer"]["value"]["lifecycle"] in ("included", "finalized") and e["answer"]["value"]["outcome"] == "unknown")
        if u is not None:
            ok = any(e["seq"] > u and e["method"] in ("lez_getBalance", "lez_readAccount") for e in calls)
            add("unknown-outcome-verified", [] if ok else ["took an included/unknown status at face value (no follow-up read)"],
                "verifies an included transaction whose outcome is unknown")

    add("journey-expectations", run.journey_problems, "the dApp's own expectations for this scenario")
    return results


# -- main ---------------------------------------------------------------------------------------------

def load_journey(path):
    spec = importlib.util.spec_from_file_location("journey", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dapp", help="dApp module dir (metadata.json + qml)")
    ap.add_argument("--scenario", action="append", default=[])
    ap.add_argument("--journey", default=None, help="default: <dapp>/conformance.py, then runner/journeys/<name>.py")
    ap.add_argument("--lib", default=str(LIB))
    ap.add_argument("--out", default=None, help="report + screenshots (default target/conformance/<name>)")
    ap.add_argument("--show", action="store_true", help="show the window instead of running offscreen")
    ap.add_argument("--idle", type=float, default=7.0, help="seconds to watch after the journey (the SDK checks the network every 5 s)")
    a = ap.parse_args()

    dapp = pathlib.Path(a.dapp).resolve()
    meta = json.loads((dapp / "metadata.json").read_text())
    if meta.get("type") != "ui_qml":
        sys.exit(f"{dapp}: not a ui_qml module")
    app, view = meta["name"], dapp / meta.get("view", "qml/Main.qml")
    uses = [u["intent"] for u in meta.get("uses", []) if isinstance(u, dict) and "intent" in u]
    journey_path = next((p for p in ([pathlib.Path(a.journey)] if a.journey else
                                     [dapp / "conformance.py", HERE / "journeys" / f"{app}.py"]) if p.exists()), None)
    journey = load_journey(journey_path) if journey_path else None
    out = pathlib.Path(a.out or ROOT / "target/conformance" / app)
    out.mkdir(parents=True, exist_ok=True)

    if not a.show:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    qapp = QGuiApplication(sys.argv)
    methods = json.loads((SCHEMA / "methods.json").read_text())
    intents = json.loads((SCHEMA / "intents.json").read_text())
    fake = Fake(a.lib)
    catalog = {s["name"]: s["description"] for s in fake.ui("fakeScenarios")}
    scenarios = a.scenario or list(catalog)
    for s in scenarios:
        if s not in catalog:
            sys.exit(f"unknown scenario {s}; known: {', '.join(catalog)}")

    # Qt's console (JS errors, warnings) goes to fd 2; a Python message
    # handler deadlocks when the QML loader thread logs, so capture the fd.
    console = out / "console.log"
    cfd = os.open(console, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
    sys.stderr = os.fdopen(os.dup(2), "w", buffering=1)  # Python's own errors still show
    os.dup2(cfd, 2)

    def console_since(pos):
        with open(console, errors="replace") as f:
            f.seek(pos)
            return [m for m in f.read().splitlines() if m and "usedbeforedeclared" not in m and "qt.qpa.fonts" not in m]

    print(f"conformance: {app} ({view.relative_to(dapp)}), journey: {journey_path or 'none (load only)'}")
    report = {"app": app, "journey": str(journey_path) if journey_path else None, "scenarios": []}
    failed = 0
    for s in scenarios:
        fake.ui("fakeSetScenario", {"scenario": s})
        st = fake.ui("fakeState")
        run = Run(qapp, s)
        cpos = os.path.getsize(console)
        host = Host(fake, app, uses, run)
        v = QQuickView()
        host.view = v
        run.view = v
        v.rootContext().setContextProperty("logos", host)
        v.setResizeMode(QQuickView.SizeRootObjectToView)
        v.resize(480, 800)
        v.setSource(QUrl.fromLocalFile(str(view)))
        load_errors = [e.toString() for e in v.errors()]
        if v.status() != QQuickView.Ready:
            print(f"  FAIL  {s}: the view didn't load: {load_errors}")
            report["scenarios"].append({"scenario": s, "loaded": False, "errors": load_errors})
            failed += 1
            continue
        v.show()
        run.pump(1500)
        run.settle(max_s=10)
        crashed = None
        if journey:
            j = run
            j.account, j.other = st["publicAccount"], st["otherAccount"]
            try:
                journey.journey(j)
            except Exception as e:  # noqa: BLE001
                crashed = f"journey stopped: {e!r}"
        run.settle(max_s=70 if s == "timeout" else 30)
        run.pump(int(a.idle * 1000))
        run.settle(max_s=15)
        if journey and hasattr(journey, "check"):
            try:
                journey.check(run, s)
            except Exception as e:  # noqa: BLE001
                run.journey_problems.append(f"check raised {e!r}")
        if crashed:
            run.journey_problems.append(crashed)
        run.shot(out / f"{s}.png")
        log = fake.ui("fakeLog")
        run.console = console_since(cpos)
        res = check(run, log, methods, intents, uses)
        bad = [r for r in res if not r[1]]
        failed += bool(bad)
        print(f"  {'PASS' if not bad else 'FAIL'}  {s:<16} {len(log):>3} wallet calls/prompts, {len(res) - len(bad)}/{len(res)} checks")
        for cid, ok, detail in bad:
            print(f"        ✗ {cid}: {detail}")
        report["scenarios"].append({
            "scenario": s, "description": catalog[s],
            "checks": [{"id": c, "pass": ok, "detail": d} for c, ok, d in res],
            "log": log, "console": run.console[-50:], "screenshot": str(out / f"{s}.png"),
        })
        v.hide()
        v.deleteLater()
        run.pump(200)

    (out / "report.json").write_text(json.dumps(report, indent=2))
    print(f"{len(scenarios) - failed}/{len(scenarios)} scenarios passed; report: {out / 'report.json'}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
