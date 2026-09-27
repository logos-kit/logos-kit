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
w.wait(lambda: w.find("fundsApprove") is None, 60, "faucet answered")
w.pump(1500)
if w.find("fundsDone"):
    w.click("fundsDone")
d.wait(lambda: d.prop("balance", "text").startswith("1000000000"), 60, "funded")
d.type("to", other)
d.type("amount", "42")
d.shot("03-compose")
d.click("send")
w.wait(lambda: w.find("approve"), 30, "approval")
w.shot("04-wallet-approval")
w.click("approve")
d.wait(lambda: d.prop("lifecycle", "text") in ("included", "finalized"), 120, "included")
d.shot("05-receipt", settle=1500)
print("OK template: connect, in-flow faucet, transfer approved, receipt included")
