# QA walk over the unlocked wallet: home, send (shield), receive, accounts,
# settings, app intents, responsive widths, light theme.
import base64, json
PW = "correct horse 42"
e = d.engine
e.call("ui_setPrefs", {"zone": "lez-local"})
created = e.call("ui_create", {"password": PW})["value"]
pub = [a for a in created["accounts"] if a["kind"] == "public"][0]["accountId"]
priv = [a for a in created["accounts"] if a["kind"] == "private"][0]["accountId"]
job = e.call("ui_requestFunds", {"account": pub})["value"]["job"]
d.wait(lambda: e.call("ui_fundStatus", {"job": job})["value"]["state"] != "running", 90, "faucet")
pub2 = e.call("ui_newAccount", {"kind": "public", "label": "Savings"})["value"]["accountId"]
d.wait(lambda: d.find("balance"), 30, "home")
store = [o for o in d.items() if o.property("core") == "logos_kit_wallet"]
d.wait(lambda: any(a.get("native") not in (None, "0") for a in (d.root().property("visible") and [x for x in e.call("ui_snapshot", {})["value"]["accounts"]])), 60, "funded snapshot")
d.pump(3000)

def set_selected(acct):
    # Home exposes `store`; set store.selected through QML.
    for o in d.items():
        if o.metaObject().className().startswith("Home"):
            o.property("store").setProperty("selected", acct)
            d.pump(600)
            return
    raise RuntimeError("Home not found")

set_selected(pub)
d.shot("10-home-public")

# -- send: public -> own private (shield) ------------------------------------
d.click("homeSend")
d.type("sendTo", priv)
d.shot("11-send-to")
d.click("sendNext")
for o in d.items():
    if o.metaObject().className().startswith("SendFlow"):
        o.setProperty("amountText", "1234")
d.shot("12-send-amount")
d.click("sendReview")
d.wait(lambda: d.find("approvePassword"), 30, "review")
d.shot("13-send-review")
d.type("approvePassword", PW)
d.click("approve")
d.wait(lambda: d.find("keepRunning") or d.find("proofDone"), 30, "proof view")
d.shot("14-send-proving", settle=1500)
d.wait(lambda: d.find("proofDone"), 600, "shield outcome")
d.shot("15-send-done")
d.click("proofDone")

# -- receive (private) -----------------------------------------------------------
set_selected(priv)
d.click("homeReceive")
d.wait(lambda: d.find("fingerprint") and d.prop("fingerprint", "text"), 20, "receive code")
d.shot("16-receive-private", settle=1500)
d.click("sheetClose")
d.pump(500)

# -- accounts, settings -----------------------------------------------------------
d.click("homeSend") ; d.click("sheetClose"); d.pump(400)
for o in d.items():
    if o.objectName() == "accountPill":
        pass
root = d.root()
root.setProperty("sheet", "accounts"); d.shot("17-accounts")
root.setProperty("sheet", "settings"); d.shot("18-settings", settle=1500)
root.setProperty("sheet", ""); d.pump(600)

# -- intents ------------------------------------------------------------------------
rid = d.intent("lez.wallet.connect", {"chains": ["lez:local"], "accountKinds": ["public", "private"]})
d.wait(lambda: d.find("connectApprove"), 20, "connect sheet")
d.shot("20-connect")
d.type("connectPassword", PW)
d.click("connectApprove")
r = d.response(rid, 30)
assert r["ok"], r
print("SESSION", json.dumps(r["data"], default=str)[:300])

data = base64.b64encode(bytes([0]) + (5).to_bytes(16, "little")).decode()
proposal = {"chain": "lez:local", "account": pub, "id": "qa-1", "instructions": [{
    "program": "11111111111111111111111111111111",
    "accounts": [{"account": pub, "writable": True, "signer": True}, {"account": pub2, "writable": True, "signer": False}],
    "data": data}]}
rid = d.intent("lez.transaction.send", proposal)
d.wait(lambda: d.find("approve"), 30, "tx approval")
d.shot("21-tx-approval")
d.click("approve")
r = d.response(rid, 30)
assert r["ok"] and r["data"]["handle"], r
d.wait(lambda: d.find("proofDone"), 120, "tx outcome")
d.shot("22-tx-done")
d.click("proofDone")

rid = d.intent("lez.message.sign", {"account": pub, "message": base64.b64encode(b"Sign in to Probe dApp\nnonce 42").decode()})
d.wait(lambda: d.find("signApprove"), 20, "sign sheet")
d.shot("23-sign-message")
d.click("signApprove")
r = d.response(rid, 20)
assert r["ok"] and r["data"]["signature"], r

# Rejected connect answers `cancelled`.
rid = d.intent("lez.wallet.connect", {"chains": ["lez:local"]}, requester="other_dapp")
d.click("connectCancel")
r = d.response(rid, 10)
assert not r["ok"] and r["error"] == "cancelled", r

# -- responsive + light -----------------------------------------------------------------
set_selected(pub)
for w in (360, 680, 1024):
    d.resize(w, 780 if w < 1024 else 720)
    d.shot("30-home")
d.resize(480, 780)
for o in d.items():
    if o.metaObject().className().startswith("Home"):
        o.property("store").call if False else None
d.click("homeSend"); d.click("sheetClose")
