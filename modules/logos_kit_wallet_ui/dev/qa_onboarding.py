# QA walk: first run on the local zone → home with test funds.
d.wait(lambda: d.find("createWallet"), 30, "welcome")
d.shot("01-welcome")
# Local sequencer (testnet is still 0.2): pick the local zone first.
d.engine.call("ui_setPrefs", {"zone": "lez-local"})
d.pump(3000)
d.click("createWallet")
d.type("password", "correct horse 42")
d.type("password2", "correct horse 42")
d.shot("02-password")
d.click("continueCreate")
d.wait(lambda: d.find("revealPhrase"), 60, "phrase step")
d.shot("03-phrase-hidden")
d.click("revealPhrase")
d.shot("04-phrase")
# Read the words back through the engine-facing Onboarding property.
ob = [o for o in d.items() if o.property("step") == "phrase"][0]
words = ob.property("words")
words = words.toVariant() if hasattr(words, "toVariant") else words
d.click("savedPhrase")
for n in (3, 11, 19):
    d.type(f"confirmWord{n}", "wrong")
d.click("confirmPhrase")
d.shot("05-confirm-wrong")
for n in (3, 11, 19):
    d.type(f"confirmWord{n}", words[n - 1])
d.click("confirmPhrase")
d.wait(lambda: d.find("goWallet"), 10, "ready")
d.shot("06-ready")
d.click("readyFunds")
d.wait(lambda: d.find("balance") and d.prop("balance", "text") not in ("—", ""), 60, "home balance")
d.shot("07-home-private")
