# Design pass shots: home (dark, light), send review, private home.
PW = "correct horse 42"
e = d.engine
e.call("ui_setPrefs", {"zone": "lez-local"})
created = e.call("ui_create", {"password": PW})["value"]
pub = [a for a in created["accounts"] if a["kind"] == "public"][0]["accountId"]
priv = [a for a in created["accounts"] if a["kind"] == "private"][0]["accountId"]
job = e.call("ui_requestFunds", {"account": pub})["value"]["job"]
d.wait(lambda: e.call("ui_fundStatus", {"job": job})["value"]["state"] != "running", 90, "faucet")
d.wait(lambda: d.find("balance"), 30, "home")
d.wait(lambda: any(a.get("native") not in (None, "0") for a in e.call("ui_snapshot", {})["value"]["accounts"]), 60, "funded")
d.pump(3000)

def home_store():
    for o in d.items():
        if o.metaObject().className().startswith("Home"):
            return o.property("store")
    raise RuntimeError("Home not found")

import os
T = os.environ.get("QA_THEME", "dark")
home_store().setProperty("selected", pub)
d.pump(1500)
if T == "light":
    d.click("themeToggle")
    d.pump(800)
d.shot("d-home-" + T)
d.click("homeSend")
d.type("sendTo", priv)
d.click("sendNext")
for o in d.items():
    if o.metaObject().className().startswith("SendFlow"):
        o.setProperty("amountText", "0.0005")
d.pump(600)
d.shot("d-send-amount-" + T)
d.click("sendReview")
d.wait(lambda: d.find("approvePassword"), 30, "review")
d.pump(800)
d.shot("d-review-" + T)
