# QA: private → private by receive code; private receive QR; light theme.
PW = "correct horse 42"
e = d.engine
e.call("ui_setPrefs", {"zone": "lez-local"})
c = e.call("ui_create", {"password": PW})["value"]
pub = [a for a in c["accounts"] if a["kind"] == "public"][0]["accountId"]
priv = [a for a in c["accounts"] if a["kind"] == "private"][0]["accountId"]
job = e.call("ui_requestFunds", {"account": pub})["value"]["job"]
d.wait(lambda: e.call("ui_fundStatus", {"job": job})["value"]["state"] != "running", 90, "faucet")
t = e.call("ui_prepareSend", {"kind": "transfer", "from": pub, "to": priv, "amount": "5000"})["value"]
e.call("ui_approve", {"handle": t["handle"], "requestHash": t["request"]["requestHash"], "password": PW})
d.wait(lambda: e.call("ui_status", {"handle": t["handle"]})["value"]["lifecycle"] == "included", 300, "shield")
priv2 = e.call("ui_newAccount", {"kind": "private", "label": "Vault"})["value"]["accountId"]
code = e.call("ui_receive", {"account": priv2})["value"]["code"]
d.wait(lambda: d.find("balance"), 30, "home")
d.pump(4000)

def home():
    return [o for o in d.items() if o.metaObject().className().startswith("Home")][0]
home().property("store").setProperty("selected", priv)
d.pump(800)
d.click("homeSend")
d.type("sendTo", code)
d.click("sendNext")
[o for o in d.items() if o.metaObject().className().startswith("SendFlow")][0].setProperty("amountText", "0.0000001")
d.click("sendReview")
d.wait(lambda: d.find("approvePassword"), 30, "review")
d.shot("40-private-review")
d.type("approvePassword", PW)
d.click("approve")
d.wait(lambda: d.find("proofDone"), 600, "private outcome")
d.shot("41-private-done")
assert "Sent privately" in (d.prop("outcomeTitle", "text") or ""), d.prop("outcomeTitle", "text")
d.click("proofDone")

home().property("store").setProperty("selected", priv2)
d.pump(800)
d.click("homeReceive")
d.wait(lambda: d.find("fingerprint") and d.prop("fingerprint", "text"), 20, "code")
d.shot("42-receive-private", settle=4000)
d.click("sheetClose")
d.pump(800)
home().property("store").call if False else None
e.call("ui_setPrefs", {"theme": "light"})
d.pump(4000)
d.shot("43-home-light")
snap = e.call("ui_snapshot", {})["value"]["accounts"]
vault = [a for a in snap if a["accountId"] == priv2][0]
assert vault["native"] == "100", vault
