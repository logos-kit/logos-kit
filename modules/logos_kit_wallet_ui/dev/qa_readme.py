# README screenshots (docs/assets/readme/MISSING.md): the real wallet, light
# mode, 2x, on the official testnet with a fresh wallet funded by the drip.
# Window shots for the full screens, panel crops for the sheets. The proving
# shot cancels its proof right after (nothing is sent).
#
#   HOME=$(mktemp -d) QT_QPA_PLATFORM=offscreen QT_SCALE_FACTOR=2 \
#     uv run --python .qt/q692/bin/python modules/logos_kit_wallet_ui/dev/harness.py \
#     --width 480 --height 820 --script modules/logos_kit_wallet_ui/dev/qa_readme.py \
#     --shots docs/assets/readme/raw
import pathlib
from PySide6.QtCore import QMetaObject, QPointF

PW = "correct horse 42"
OUT = pathlib.Path.cwd() / "docs/assets/readme"  # run from the repo root
e = d.engine


def shown(name):
    return d.find(name) is not None


def save(name, item=None, pad=0):
    """Window shot, or the scene rectangle of `item` (a sheet panel)."""
    d.pump(900)
    img = d.view.grabWindow()
    if item is not None:
        dpr = img.width() / d.view.width()
        p = item.mapToScene(QPointF(0, 0))
        x, y = max(0, int((p.x() - pad) * dpr)), max(0, int((p.y() - pad) * dpr))
        w, h = int((item.width() + 2 * pad) * dpr), int((item.height() + 2 * pad) * dpr)
        img = img.copy(x, y, min(w, img.width() - x), min(h, img.height() - y))
    img.save(str(OUT / f"{name}.png"))
    print("README", name, img.width(), "x", img.height(), flush=True)


def home():
    for o in d.items():
        if o.metaObject().className().startswith("Home"):
            return o.property("store")
    raise RuntimeError("Home not found")


def close_sheet():
    d.root().setProperty("sheet", "")
    d.pump(700)


# Light from the first frame.
e.call("ui_setPrefs", {"theme": "light", "zone": "lez-testnet"})
d.pump(3000)

# -- 02 welcome ------------------------------------------------------------------
d.wait(lambda: shown("createWallet"), 30, "welcome")
save("basecamp-02-create")

# -- 03 recovery phrase (throwaway wallet: this one is discarded below) ---------
d.click("createWallet")
d.type("password", PW)
d.type("password2", PW)
d.click("continueCreate")
d.click("revealPhrase", 60)
d.wait(lambda: shown("savedPhrase"), 30, "phrase")
save("basecamp-03-phrase")

# Confirm the words it asks for, then "Get test LGO" on the ready screen.
d.click("savedPhrase")
ob = [o for o in d.items() if o.metaObject().className().startswith("Onboarding")][0]
words = ob.property("words")
words = words.toVariant() if hasattr(words, "toVariant") else list(words)
for n in (3, 11, 19):
    d.type(f"confirmWord{n}", words[n - 1])
d.click("confirmPhrase")
d.click("readyFunds", 60)
snap = lambda: e.call("ui_snapshot", {})["value"]
d.wait(lambda: len(snap()["accounts"]) >= 2, 120, "accounts")
accts = snap()["accounts"]
pub = [a for a in accts if a["kind"] == "public"][0]["accountId"]
priv = [a for a in accts if a["kind"] == "private"][0]["accountId"]

# -- 04 home after Test LGO -----------------------------------------------------
home().setProperty("selected", pub)
d.wait(lambda: any(a.get("native") not in (None, "0") for a in snap()["accounts"] if a["accountId"] == pub), 900, "funded")
d.pump(4000)
save("basecamp-04-test-lgo")

# -- 05 accounts: two public, one private, one being renamed --------------------
e.call("ui_newAccount", {"kind": "public"})
d.pump(3000)
d.click("accountPill")
d.wait(lambda: shown("newPublic"), 10, "accounts sheet")
for o in d.items():
    if o.metaObject().className().startswith("AccountsView"):
        o.setProperty("editing", pub)
d.pump(800)
save("basecamp-05-accounts", d.find("sheetPanel"))
close_sheet()

# -- 06 receive privately ---------------------------------------------------------
home().setProperty("selected", priv)
d.pump(1200)
d.click("homeReceive")
d.wait(lambda: shown("fingerprint"), 20, "private receive")
save("basecamp-06-receive", d.find("sheetPanel"))
close_sheet()

# -- 07 review of a public send ---------------------------------------------------
home().setProperty("selected", pub)
d.pump(1200)
payee = [a for a in snap()["accounts"] if a["kind"] == "public" and a["accountId"] != pub][0]["accountId"]
d.click("homeSend")
d.type("sendTo", payee)
d.click("sendNext")
for o in d.items():
    if o.metaObject().className().startswith("SendFlow"):
        o.setProperty("amountText", "0.25")
d.click("sendReview")
d.wait(lambda: shown("approvePassword") or shown("approve"), 60, "review")
save("basecamp-07-send", d.find("sheetPanel"))
for o in d.items():
    if o.metaObject().className().startswith("SendFlow"):
        QMetaObject.invokeMethod(o, "back")
        QMetaObject.invokeMethod(o, "reset")
close_sheet()

# -- 08 a shield proving (cancelled before it's sent) ---------------------------
t = e.call("ui_prepareSend", {"kind": "transfer", "from": pub, "to": priv, "amount": "100000000"})["value"]
ok = e.call("ui_approve", {"handle": t["handle"], "requestHash": t["request"]["requestHash"], "password": PW})
d.root().setProperty("proofHandle", t["handle"])
d.root().setProperty("sheet", "proof")
d.wait(lambda: shown("keepRunning"), 120, "proving")
d.pump(20000)
save("basecamp-08-private", d.find("sheetPanel"))
e.call("ui_cancel", {"handle": t["handle"]})
close_sheet()
