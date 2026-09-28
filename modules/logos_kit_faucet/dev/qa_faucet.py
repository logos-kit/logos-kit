# The faucet app's user flow in the two-window harness (e2e/faucet-app.sh).
PW = "correct horse 42"
e.call("ui_setPrefs", {"zone": "lez-local"})
created = e.call("ui_create", {"password": PW})["value"]
pub = [a for a in created["accounts"] if a["kind"] == "public"][0]["accountId"]
priv = [a for a in created["accounts"] if a["kind"] == "private"][0]["accountId"]
root = d.root()

def shown(name):
    return d.find(name) is not None

def approve_funds():
    w.wait(lambda: w.find("fundsApprove"), 30, "faucet sheet")
    w.click("fundsApprove")
    # The result holds the wallet's sheet until Done.
    w.click("fundsDone", 60)

def session_account(kind):
    accts = root.property("accounts")
    accts = accts.toVariant() if hasattr(accts, "toVariant") else accts
    return [a["address"] for a in accts if a["kind"] == kind][0]

# Let the wallet UI pick up the zone set behind its back.
w.wait(lambda: w.find("balance"), 30, "wallet home")
w.pump(3000)
d.shot("01-disconnected")

d.click("fcConnect")
w.wait(lambda: w.find("connectApprove"), 30, "connect sheet")
# Tick the private account too, and its extra consent (as a user would).
from PySide6.QtCore import QMetaObject, Q_ARG
iv = [o for o in w.items() if o.metaObject().className().startswith("IntentView")][0]
QMetaObject.invokeMethod(iv, "toggle", Q_ARG("QVariant", priv))
iv.setProperty("privConsent", True)
w.shot("02-wallet-connect-private")
w.type("connectPassword", PW)
w.click("connectApprove")
d.wait(lambda: shown("fcAccount_1"), 30, "two accounts shared")
root.setProperty("account", pub)
d.shot("02-accounts", settle=1500)

# Public: funded.
d.click("fcRequest")
approve_funds()
d.wait(lambda: shown("fcDone"), 60, "funded")
assert "1,000,000,000" in d.prop("fcAmount", "text"), d.prop("fcAmount", "text")
d.shot("03-funded", settle=2500)
d.click("fcAgain")

# Again right away: rate-limited, with a countdown that reopens the button.
d.click("fcRequest")
approve_funds()
d.wait(lambda: shown("fcLimited"), 30, "rate limited")
d.shot("04-rate-limited")
d.wait(lambda: d.prop("fcRequest", "enabled"), 90, "countdown over")
d.shot("05-limit-over")

# Private: funded through the public account, then the shield is approved and proved.
root.setProperty("account", session_account("private"))
d.pump(800)
d.shot("06-private-selected")
d.click("fcRequest")
approve_funds()
d.wait(lambda: shown("fcShielding"), 60, "shield step")
d.shot("07-shield-approve")
w.wait(lambda: w.find("approve") or w.find("approvePassword"), 60, "shield approval in wallet")
w.shot("08-wallet-shield")
if w.find("approvePassword"):
    w.type("approvePassword", PW)
w.click("approve")
d.shot("09-shield-proving", settle=1500)
d.wait(lambda: shown("fcDone"), 900, "private funded")
d.shot("10-private-funded", settle=2500)

def js(name):
    v = root.property(name)
    return v.toVariant() if hasattr(v, "toVariant") else v

assert js("shield")["status"]["outcome"] == "success", js("shield")
assert js("result").get("fundedAccount") == pub, js("result")
d.click("fcAgain")

# Outcome unknown that never shows up: the watch ends in a clear state
# (read failures and unchanged balances both count), with a safe re-check.
root.setProperty("account", pub)
root.setProperty("maxChecks", 2)
bal = js("balances")[pub]
QMetaObject.invokeMethod(root, "startChecking", Q_ARG("QVariant", pub), Q_ARG("QVariant", bal))
d.wait(lambda: shown("fcUnconfirmed"), 30, "unconfirmed after the watch")
d.shot("11-unconfirmed")
assert shown("fcCheckAgain")
print("OK faucet app: public funded, rate-limited countdown, private funded via shield, unknown ends unconfirmed")
