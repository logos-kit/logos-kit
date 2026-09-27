# The testimonial app's user flow in the two-window harness (e2e/testimonial-app.sh).
PW = "correct horse 42"
e.call("ui_setPrefs", {"zone": "lez-local"})
created = e.call("ui_create", {"password": PW})["value"]
pub = [a for a in created["accounts"] if a["kind"] == "public"][0]["accountId"]

def shown(name):
    return d.find(name) is not None

def txt(name):
    return d.prop(name, "text")

# Disconnected: count and feed come from chain data (the seeded post).
d.wait(lambda: txt("tmCount") == "1", 60, "count 1")
d.shot("01-disconnected", settle=1200)

# Connect: the wallet asks which account to share.
d.click("tmConnect")
w.wait(lambda: w.find("connectApprove"), 30, "connect sheet")
w.shot("02-wallet-connect")
w.type("connectPassword", PW)
w.click("connectApprove")

# A fresh account: no funds for the fee.
d.wait(lambda: shown("tmNoFunds"), 60, "no-funds notice")
d.shot("03-no-funds")
d.click("tmFunds")
w.wait(lambda: w.find("fundsApprove"), 30, "faucet sheet")
w.shot("04-wallet-faucet")
w.click("fundsApprove")
d.wait(lambda: not shown("tmNoFunds") and shown("tmFresh"), 120, "funded, fresh-account nudge")
d.shot("05-funded-fresh")

# Validation: the text must name the wallet.
d.type("tmText", "Great wallet!")
d.find("tmText").setProperty("dirty", True)
d.wait(lambda: "Logos Kit" in (txt("tmProblem") or ""), 10, "naming rule")
assert not d.prop("tmPost", "enabled")
d.shot("06-invalid")

d.type("tmName", "harness")
d.type("tmText", "I use the Logos Kit wallet on LEZ to test Basecamp apps end to end.")
d.wait(lambda: d.prop("tmPost", "enabled"), 10, "post enabled")
d.shot("07-compose")

# Post: approve in the wallet, then watch it land.
d.click("tmPost")
w.wait(lambda: w.find("approve"), 30, "wallet approval")
d.shot("08-approving")
w.shot("09-wallet-approval")
w.click("approve")
d.wait(lambda: shown("tmPending") or shown("tmDone"), 30, "pending")
d.shot("10-pending", settle=200)
d.wait(lambda: shown("tmDone"), 120, "included")
d.wait(lambda: txt("tmCount") == "2", 60, "count 2")
d.shot("11-done")

# Back: the account has posted; the composer is gone.
d.find("tmDone")  # still visible
d.root().setProperty("phase", "compose")
d.wait(lambda: shown("tmMine"), 30, "your testimonial")
d.shot("12-mine")
assert not shown("tmPost")
print("OK testimonial app: connect, faucet, validate, post, included, already-posted")
