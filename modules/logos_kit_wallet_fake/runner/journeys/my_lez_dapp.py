"""Journey for the dApp template (templates/basecamp-dapp, module my_lez_dapp).

A journey is the user's side of the flow: click, type, wait. The runner calls
`journey(j)` once per scenario, whatever the wallet answers, so steps check
what is on screen instead of assuming success. `check(j, scenario)` adds the
dApp's own expectations (j.expect). A third-party dApp ships the same two
functions as `conformance.py` next to its metadata.json.

j: click(name) -> bool, type(name, text), settle(), wait(cond, s), find(name),
   prop(name, key), text(), expect(cond, msg), account, other, scenario.
"""


def journey(j):
    if not j.click("connect"):
        return
    j.settle()
    if j.find("funds"):
        j.click("funds")
        j.settle()
        said = j.text().lower()
        if j.scenario == "rate_limited":
            j.expect("try again" in said or "busy" in said, "rate_limited: no visible explanation after the faucet refused")
    j.type("to", j.other)
    j.type("amount", "42")
    if j.click("send", timeout=5):
        # timeout: the wallet answers after 50 s.
        j.settle(max_s=70 if j.scenario == "timeout" else 30)


def check(j, scenario):
    tone = j.prop("lifecycle", "tone")
    if scenario in ("unknown_outcome", "failed_onchain", "stale"):
        j.expect(tone != "ok", f"{scenario}: the receipt is marked as a success")
    if scenario == "happy":
        j.expect(tone == "ok", "happy: the receipt never shows success")
    if scenario == "reject":
        j.expect(j.find("connect") is not None, "reject: the connect button is gone after the user declined")
    if scenario == "unavailable":
        j.expect(j.find("connect") is not None, "unavailable: the connect button is gone")
