"""Render the LogosKitUi v2 gallery and save screenshots (light and dark).

    uv run --python .qt/q692/bin/python sdk/qml/gallery/shoot.py [--out docs/reviews/revamp/kit] [--only SECTION]

Also captures mid-animation frames: the sheet sliding in, the pipeline's
active stage pulsing, the toast stack settling, the success check drawing.
"""
import argparse, pathlib, sys

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SECTIONS = ["foundations", "loading", "pipeline", "feedback", "wallet", "connect", "onboarding", "overlays"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "docs/reviews/revamp/kit"))
    ap.add_argument("--only", default=None)
    a = ap.parse_args()
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    app = QGuiApplication(sys.argv)
    view = QQuickView()
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.resize(1200, 820)
    view.setSource(QUrl.fromLocalFile(str(HERE / "Gallery.qml")))
    if view.status() != QQuickView.Ready:
        for e in view.errors():
            print(e.toString())
        sys.exit(1)
    view.show()
    root = view.rootObject()

    plan = []   # (delay_ms, action)
    t = 400
    for dark in (True, False):
        for s in SECTIONS:
            if a.only and s != a.only:
                continue
            name = f"{s}-{'dark' if dark else 'light'}"
            plan.append((t, lambda dark=dark, s=s: (root.setProperty("dark", dark), root.setProperty("section", s))))
            t += 1500
            plan.append((t, lambda name=name: shot(view, out / f"{name}.png")))
            t += 150
            if s == "overlays" and dark:
                # Motion frames: re-open the sheet and grab it mid-slide; retrigger toasts.
                plan.append((t, lambda: reopen(root, "sheet")))
                plan.append((t + 700 + 90, lambda: shot(view, out / "motion-sheet-in-90ms.png")))
                plan.append((t + 700 + 220, lambda: shot(view, out / "motion-sheet-in-220ms.png")))
                plan.append((t + 1200, lambda: open_dialog(root)))
                plan.append((t + 1290, lambda: shot(view, out / "motion-dialog-in-90ms.png")))
                plan.append((t + 1700, lambda: shot(view, out / "overlays-dialog-dark.png")))
                plan.append((t + 1800, lambda: close_dialog(root)))
                t += 2200
            if s == "feedback" and dark:
                plan.append((t, lambda: replay(root, "check")))
                plan.append((t + 140, lambda: shot(view, out / "motion-check-140ms.png")))
                plan.append((t + 320, lambda: shot(view, out / "motion-check-320ms.png")))
                t += 900
            if s == "pipeline" and dark:
                plan.append((t + 300, lambda: shot(view, out / "motion-pipeline-pulse-a.png")))
                plan.append((t + 900, lambda: shot(view, out / "motion-pipeline-pulse-b.png")))
                t += 1200
    plan.append((t + 300, app.quit))
    for d, f in plan:
        QTimer.singleShot(d, f)
    sys.exit(app.exec())


def find(root, name):
    from PySide6.QtCore import QObject
    o = root.findChild(QObject, name)
    if o is None:
        print("MISSING", name)
    return o


def reopen(root, name):
    s = find(root, name)
    if s:
        s.setProperty("opened", False)
        QTimer.singleShot(700, lambda: s.setProperty("opened", True))


def open_dialog(root):
    d = find(root, "dialog")
    if d:
        d.setProperty("opened", True)


def close_dialog(root):
    d = find(root, "dialog")
    if d:
        d.setProperty("opened", False)


def replay(root, name):
    c = find(root, name)
    if c:
        from PySide6.QtCore import QMetaObject
        QMetaObject.invokeMethod(c, "play")


def shot(view, path):
    view.grabWindow().save(str(path))
    print("SHOT", path.relative_to(ROOT) if path.is_relative_to(ROOT) else path)


if __name__ == "__main__":
    main()
