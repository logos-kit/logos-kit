# Public send on the local zone: the review's fee at today's rate (exact for a
# native transfer, which runs at zero cycles), the cap and signers under
# technical details, and the fee paid afterwards, which must match.
PW = "correct horse 42"
e = d.engine
e.call("ui_setPrefs", {"zone": "lez-local"})
created = e.call("ui_create", {"password": PW})["value"]
pub = [a for a in created["accounts"] if a["kind"] == "public"][0]["accountId"]
job = e.call("ui_requestFunds", {"account": pub})["value"]["job"]
d.wait(lambda: e.call("ui_fundStatus", {"job": job})["value"]["state"] != "running", 90, "faucet")
pub2 = e.call("ui_newAccount", {"kind": "public", "label": "Savings"})["value"]["accountId"]
d.wait(lambda: d.find("balance"), 30, "home")
d.wait(lambda: any(a.get("native") not in (None, "0") for a in e.call("ui_snapshot", {})["value"]["accounts"]), 60, "funded")
d.pump(2000)
for o in d.items():
    if o.metaObject().className().startswith("Home"):
        o.property("store").setProperty("selected", pub)
d.pump(600)

d.click("homeSend")
d.type("sendTo", pub2)
d.click("sendNext")
for o in d.items():
    if o.metaObject().className().startswith("SendFlow"):
        o.setProperty("amountText", "0.25")
d.click("sendReview")
d.wait(lambda: d.find("approvePassword"), 30, "review")
d.pump(800)
d.shot("f1-review")
review_fee = [o.property("value") for o in d.items() if o.property("label") == "Network fee" and d._shown(o)][0]
print("REVIEW FEE", review_fee)
d.find("approvalDetails", visible=False).setProperty("visible", True)
d.pump(600)
d.shot("f1b-review-details")
d.type("approvePassword", PW)
d.click("approve")
# Log sheet, lock and selection changes until the outcome shows.
store = [o for o in d.items() if o.metaObject().className().startswith("Home")][0].property("store")
seen = None
def settled():
    global seen
    now = (d.root().property("sheet"), store.property("unlocked"), store.property("selected"))
    if now != seen:
        print("STATE", now)
        seen = now
    return d.find("proofDone")
d.wait(settled, 300, "outcome")
d.wait(lambda: d.find("feePaid") and d.prop("feePaid", "visible"), 30, "fee paid")
paid = d.prop("feePaid", "text")
print("FEE", paid)
assert review_fee.split(" · ")[0] == paid.replace("Network fee paid ", ""), (review_fee, paid)
d.shot("f2-done", settle=1200)
