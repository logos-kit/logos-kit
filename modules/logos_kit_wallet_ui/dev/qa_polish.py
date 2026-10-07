# QA walk for stage W (wallet polish, docs/dev/PLAN-LP0001.md §4.8) on the
# default zone (the official testnet; reads only, nothing is sent):
# welcome with networks behind "Advanced", home opens on the public account,
# Send's recipient checks (private code fingerprint, first-time address),
# Receive's explorer link, the private-account explainer and the two-step
# test-LGO notice, Settings (add a network, password, low-memory proving,
# programs you named, backup), and the same home in light and dark.
#
#   HOME=$(mktemp -d) QT_QPA_PLATFORM=offscreen uv run --python .qt/q692/bin/python \
#     modules/logos_kit_wallet_ui/dev/harness.py --script modules/logos_kit_wallet_ui/dev/qa_polish.py \
#     --shots docs/reviews/w
# (HOME points at a scratch dir: the backup step writes to ~/Downloads.)
import os, pathlib
from PySide6.QtCore import QMetaObject

PW = "correct horse 42"
e = d.engine
pathlib.Path(os.environ["HOME"], "Downloads").mkdir(parents=True, exist_ok=True)


def store():
    for o in d.items():
        if o.metaObject().className().startswith("Home"):
            return o.property("store")
    raise RuntimeError("Home not found")


def shown(name):
    return d.find(name) is not None


# -- welcome: the testnet by default, other networks behind Advanced ---------
d.wait(lambda: shown("createWallet"), 30, "welcome")
assert shown("welcomeAdvanced"), "the Advanced link is missing"
d.shot("01-welcome")
d.click("welcomeAdvanced")
assert not shown("welcomeAdvanced"), "Advanced didn't open"
d.shot("02-welcome-advanced")

# -- create (engine call, as qa_wallet does), then home ------------------------
created = e.call("ui_create", {"password": PW})["value"]
pub = [a for a in created["accounts"] if a["kind"] == "public"][0]["accountId"]
priv = [a for a in created["accounts"] if a["kind"] == "private"][0]["accountId"]
d.wait(lambda: shown("balance"), 60, "home")
d.wait(lambda: store().property("selected") != "", 60, "an account selected")
assert store().property("selected") == pub, "home should open on the public account"
d.shot("03-home-public-dark")

# New accounts get names; the account the wallet makes for itself doesn't show.
named = e.call("ui_newAccount", {"kind": "public"})["value"]
assert named["label"] == "Public account 2", named

# -- send: a private code shows its fingerprint; a new address is first-time --
code = e.call("ui_receive", {"account": priv})["value"]
d.click("homeSend")
d.type("sendTo", code["code"])
d.wait(lambda: shown("sendCodeFingerprint"), 15, "fingerprint")
fp = d.find("sendCodeFingerprint").property("text")
assert code["fingerprint"] in fp, (code["fingerprint"], fp)
d.shot("04-send-code-fingerprint")
d.type("sendTo", "US517G5965aydkZ46HS38QLi7UQiSojurfbQfKCELFx")
d.pump(1500)
d.shot("05-send-first-time")
store().setProperty("selected", pub)
for o in d.items():
    if o.metaObject().className().startswith("SendFlow"):
        QMetaObject.invokeMethod(o, "reset")
d.pump(300)
QMain = d.root()
QMain.setProperty("sheet", "")
d.pump(600)

# -- receive: public, with the explorer link ----------------------------------
d.click("homeReceive")
d.wait(lambda: shown("copyReceive"), 15, "receive")
d.pump(800)
assert shown("receiveExplorer"), "explorer link missing on the testnet"
d.shot("06-receive-public")
QMain.setProperty("sheet", "")
d.pump(600)

# -- private account: explainer and the two-step test LGO -----------------------
store().setProperty("selected", priv)
d.pump(800)
d.click("privateInfoLink")
d.wait(lambda: shown("privateInfoDone"), 10, "explainer")
d.shot("07-private-explainer")
d.click("privateInfoDone")
d.pump(500)
d.click("homeFunds")
d.wait(lambda: shown("privateFundsGo"), 10, "two-step notice")
d.shot("08-private-funds-notice")
QMain.setProperty("sheet", "")
d.pump(600)
store().setProperty("selected", pub)
d.pump(600)

# -- settings ------------------------------------------------------------------
d.click("openSettings")
d.wait(lambda: shown("lowMemoryToggle"), 10, "settings")
d.shot("09-settings")
d.click("addZoneOpen")
d.type("addZoneName", "My devnet")
d.type("addZoneUrl", "https://devnet.example.org")
d.shot("10-settings-add-network")
e.call("ui_setPrefs", {"lowMemory": True})
d.pump(3000)
assert d.find("lowMemoryToggle").property("checked"), "low-memory toggle didn't follow the pref"
e.call("ui_nameProgram", {"account": "5YoH3xjhgeKt2mcJXW7c31bqDNCWWA4CRJxVdvzFvVef", "name": "Testimonials"})
progs = e.call("ui_programs", {})["value"]
assert progs and progs[0]["name"] == "Testimonials", progs
saved = e.call("ui_exportBackup", {})["value"]["path"]
assert pathlib.Path(saved).is_file() and "Downloads" in saved, saved
found = e.call("ui_findBackups", {})["value"]
assert any(b["path"] == saved for b in found), found
print("BACKUP", saved, flush=True)
QMain.setProperty("sheet", "")
d.pump(400)
d.click("openSettings")
d.pump(1200)
d.shot("11-settings-after")
QMain.setProperty("sheet", "")
d.pump(600)

# -- light -----------------------------------------------------------------------
d.click("themeToggle")
d.pump(800)
d.shot("12-home-public-light")
d.click("homeSend")
d.type("sendTo", code["code"])
d.wait(lambda: shown("sendCodeFingerprint"), 15, "fingerprint")
d.shot("13-send-code-fingerprint-light")
