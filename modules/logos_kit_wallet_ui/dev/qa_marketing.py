# Marketing shots on the official testnet: home and private receive, dark
# and light (QA_THEME). A fresh wallet funded by the testnet drip; the
# network can take minutes to include the drop.
import os
PW = "correct horse 42"
T = os.environ.get("QA_THEME", "dark")
e = d.engine
e.call("ui_setPrefs", {"zone": "lez-testnet"})
created = e.call("ui_create", {"password": PW})["value"]
pub = [a for a in created["accounts"] if a["kind"] == "public"][0]["accountId"]
priv = [a for a in created["accounts"] if a["kind"] == "private"][0]["accountId"]
job = e.call("ui_requestFunds", {"account": pub})["value"]["job"]
d.wait(lambda: e.call("ui_fundStatus", {"job": job})["value"]["state"] != "running", 300, "faucet")
d.wait(lambda: d.find("balance"), 30, "home")
d.wait(lambda: any(a.get("native") not in (None, "0") for a in e.call("ui_snapshot", {})["value"]["accounts"]), 900, "funded")
d.pump(3000)

def home_store():
    for o in d.items():
        if o.metaObject().className().startswith("Home"):
            return o.property("store")
    raise RuntimeError("Home not found")

home_store().setProperty("selected", pub)
d.pump(1500)
if T == "light":
    d.click("themeToggle")
    d.pump(800)
d.shot("m-home-" + T)
home_store().setProperty("selected", priv)
d.pump(1500)
d.click("homeReceive")
d.wait(lambda: d.find("fingerprint"), 60, "private receive")
d.pump(1500)
d.shot("m-receive-" + T)
