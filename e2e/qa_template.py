# The dApp template's flow in the two-window harness (e2e/template-app.sh).
PW = "correct horse 42"
e.call("ui_setPrefs", {"zone": "lez-local"})
created = e.call("ui_create", {"password": PW})["value"]
other = e.call("ui_newAccount", {"kind": "public", "label": "Other"})["value"]["accountId"]
w.wait(lambda: w.find("balance"), 30, "wallet home")
w.pump(3000)

d.shot("01-start")
d.click("connect")
w.wait(lambda: w.find("connectApprove"), 30, "connect sheet")
w.type("connectPassword", PW)
w.click("connectApprove")
d.wait(lambda: d.find("funds"), 30, "empty account offers funds")
d.shot("02-connected-empty")
d.click("funds")
w.wait(lambda: w.find("fundsApprove"), 30, "faucet sheet")
w.click("fundsApprove")
# The result holds the wallet's sheet until Done (new requests wait for it).
w.click("fundsDone", 60)
d.wait(lambda: d.prop("balance", "text") == "1", 60, "funded (1 LGO)")
# Send to a public account other than the one the app was given (the
# connect sheet shares the wallet's current account, which may be "Other").
publics = [a["accountId"] for a in created["accounts"] if a["kind"] == "public"] + [other]
to = [a for a in publics if a != d.root().property("account")][0]
d.type("to", to)
d.type("amount", "0.000000042")   # 42 lepta
d.shot("03-compose")
d.click("send")
w.wait(lambda: w.find("approve"), 30, "approval")
w.shot("04-wallet-approval")
w.click("approve")
d.wait(lambda: d.root().property("phase") == "done", 120, "included, outcome success")
rc = d.root().property("receipt")
rc = rc.toVariant() if hasattr(rc, "toVariant") else rc
assert rc["outcome"] == "success", rc
d.shot("05-receipt", settle=1500)
print("OK template: connect, in-flow faucet, transfer approved, receipt included")
