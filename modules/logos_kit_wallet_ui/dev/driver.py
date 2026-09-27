"""Scripted QA for the dev harness: click by objectName, type, wait, screenshot.

A script is plain Python run with `d` bound to a Driver, e.g.
    d.wait(lambda: d.find("createWallet"))
    d.click("createWallet"); d.type("password", "correct horse 1"); d.shot("create")
"""
import sys, time, traceback
from PySide6.QtCore import QObject, QMetaObject, Qt, QEventLoop, QTimer, QPointF
from PySide6.QtGui import QMouseEvent, QPointingDevice
from PySide6.QtCore import QEvent


class Driver:
    def __init__(self, app, view, bridge, engine, shots):
        self.app, self.view, self.bridge, self.engine = app, view, bridge, engine
        self.shots = shots
        shots.mkdir(parents=True, exist_ok=True)

    def pump(self, ms=50):
        end = time.time() + ms / 1000
        while time.time() < end:
            self.app.processEvents(QEventLoop.AllEvents, 20)
            time.sleep(0.005)

    def root(self):
        return self.view.rootObject()

    def items(self, item=None):
        """Every item in the visual tree (Repeater delegates have no QObject parent)."""
        item = item or self.root()
        yield item
        for c in item.childItems():
            yield from self.items(c)

    def find(self, name, visible=True):
        for o in self.items():
            if o.objectName() == name and (not visible or self._shown(o)):
                return o
        return None

    def _shown(self, o):
        p = o
        while p is not None:
            if not p.isVisible():
                return False
            p = p.parentItem()
        return True

    def wait(self, cond, timeout=30, what="condition"):
        end = time.time() + timeout
        while time.time() < end:
            try:
                if cond():
                    return True
            except Exception:
                pass
            self.pump(100)
        raise TimeoutError(f"timed out waiting for {what}")

    def click(self, name, timeout=30):
        self.wait(lambda: self.find(name) is not None, timeout, name)
        o = self.find(name)
        # Btn/IconBtn expose `clicked`; wait for the arm delay.
        self.wait(lambda: o.property("armed") in (None, True) and o.property("enabled") and not o.property("busy"), timeout, name + " enabled")
        QMetaObject.invokeMethod(o, "clicked")
        self.pump(250)

    def type(self, name, text):
        self.wait(lambda: self.find(name) is not None, 30, name)
        self.find(name).setProperty("text", text)
        self.pump(80)

    def prop(self, name, key):
        o = self.find(name)
        return o.property(key) if o else None

    def shot(self, label, settle=600):
        self.pump(settle)
        img = self.view.grabWindow()
        path = self.shots / f"{label}-{self.view.width()}.png"
        img.save(str(path))
        print("SHOT", path, flush=True)

    def resize(self, w, h=None):
        self.view.resize(w, h or self.view.height())
        self.pump(400)

    def js(self, code):
        # Evaluate against the root item (the Main.qml Item).
        return QMetaObject.invokeMethod

    def intent(self, name, params, requester="probe_dapp"):
        rid = self.bridge.intent(name, params, requester)
        self.pump(300)
        return rid

    def response(self, rid, timeout=60):
        self.wait(lambda: any(r["id"] == rid for r in self.bridge.responses), timeout, "response " + rid)
        return [r for r in self.bridge.responses if r["id"] == rid][0]

    def run(self, code, ns):
        try:
            exec(code, ns)
            print("SCRIPT OK", flush=True)
            self.app.exit(0)
        except Exception:
            traceback.print_exc()
            self.shot("failure")
            self.app.exit(1)
