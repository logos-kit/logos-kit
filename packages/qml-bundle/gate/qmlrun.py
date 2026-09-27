"""Load a bundle (IIFE with global `Suite`, `.pragma library`) into a real QML document
and run Suite.run(host). host = {log, setTimeout, clearTimeout, done}. Prints every log line.
Usage: python qmlrun.py out/bundle.js [timeout_ms]"""
import sys, os, shutil, tempfile
os.environ.setdefault("QT_LOGGING_RULES", "qt.qml.usedbeforedeclared=false")
from PySide6.QtCore import QCoreApplication, QUrl, QTimer, qInstallMessageHandler, qVersion
from PySide6.QtQml import QQmlApplicationEngine

bundle = os.path.realpath(sys.argv[1]); tmo = int(sys.argv[2]) if len(sys.argv) > 2 else 60000
d = tempfile.mkdtemp(prefix="qmlrun_"); d = os.path.realpath(d)
shutil.copy(bundle, os.path.join(d, "bundle.js"))
open(os.path.join(d, "Main.qml"), "w").write("""import QtQml
import "bundle.js" as B
QtObject {
  id: root
  property int nextId: 1
  property var timers: ({})
  function log(s) { console.log("|" + s) }
  function setTimeout(fn, ms) {
    var t = Qt.createQmlObject("import QtQml; Timer { repeat: false }", root)
    var id = nextId++; timers[id] = t
    t.interval = ms || 0
    t.triggered.connect(function() { delete timers[id]; t.destroy(); fn() })
    t.start(); return id
  }
  function clearTimeout(id) { var t = timers[id]; if (t) { t.stop(); t.destroy(); delete timers[id] } }
  function done(ok) { console.log("GLOBALCHECK typeof TextEncoder/globalThis seen from QML document: " + typeof TextEncoder + "/" + typeof globalThis); console.log("|DONE " + ok); Qt.quit() }
  Component.onCompleted: {
    try {
      var host = { log: log, setTimeout: setTimeout, clearTimeout: clearTimeout, done: done }
      var r = B.Suite.run(host)
      if (r && typeof r.then === "function") r.then(function() { done(true) }, function(e) { log("REJECT " + e + (e && e.stack ? "\\n" + e.stack : "")); done(false) })
      else done(true)
    } catch (e) { log("THROW " + e + (e && e.stack ? "\\n" + e.stack : "")); done(false) }
  }
}
""")
def h(t, c, m):
    if m.startswith("|"): print(m[1:], flush=True)
    else: print("[qt]", m[:600], flush=True)
qInstallMessageHandler(h)
app = QCoreApplication(sys.argv)
print(f"== Qt {qVersion()} :: {os.path.basename(bundle)} ({os.path.getsize(bundle)} bytes)")
eng = QQmlApplicationEngine(); eng.quit.connect(app.quit)
import time; _t0 = time.perf_counter()
eng.load(QUrl.fromLocalFile(os.path.join(d, "Main.qml")))
print(f"TIME load+run(sync part) {1000*(time.perf_counter()-_t0):.0f} ms")
if not eng.rootObjects(): print("LOAD FAILED"); sys.exit(2)
QTimer.singleShot(tmo, lambda: (print("TIMEOUT"), app.quit()))
app.exec()
