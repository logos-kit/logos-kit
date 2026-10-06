# Performance budgets (docs/dev/PLAN.md "Budgets", recorded in docs/dev/perf.md):
# engine call latency, first sync on the official testnet, account switch,
# Send review (engine build vs. the sheet appearing). Prints one PERF line per
# figure; run it on an idle machine.
#
#   HOME=$(mktemp -d) QT_QPA_PLATFORM=offscreen uv run --python .qt/q692/bin/python \
#     modules/logos_kit_wallet_ui/dev/harness.py --script modules/logos_kit_wallet_ui/dev/qa_perf.py
import statistics, time

PW = "correct horse 42"
e = d.engine


def perf(name, ms):
    print(f"PERF {name} {ms:.0f} ms", flush=True)


def ms_since(t):
    return (time.perf_counter() - t) * 1000


def home():
    for o in d.items():
        if o.metaObject().className().startswith("Home"):
            return o.property("store")
    raise RuntimeError("Home not found")


# Engine call latency (a status read the UI makes every 2.5 s).
samples = []
for _ in range(30):
    t = time.perf_counter()
    e.call("ui_state", {})
    samples.append(ms_since(t))
perf("ui_state p50", statistics.median(samples))
perf("ui_state max", max(samples))

# Create, then the first sync on the testnet (fresh wallet: no history to scan).
t = time.perf_counter()
created = e.call("ui_create", {"password": PW})["value"]
perf("create wallet (KDF + vault)", ms_since(t))
pub = [a for a in created["accounts"] if a["kind"] == "public"][0]["accountId"]
priv = [a for a in created["accounts"] if a["kind"] == "private"][0]["accountId"]
t = time.perf_counter()
d.wait(lambda: e.call("ui_snapshot", {})["value"].get("tip"), 180, "first sync")
perf("first sync to the testnet tip", ms_since(t))
d.wait(lambda: d.find("balance") is not None, 60, "home")
d.pump(2000)

# Account switch: until the header shows the other account.
names = {a["accountId"]: a["label"] for a in e.call("ui_snapshot", {})["value"]["accounts"]}
switches = []
for target in [priv, pub, priv, pub, priv, pub]:
    t = time.perf_counter()
    home().setProperty("selected", target)
    d.wait(lambda: any(o.property("text") == names[target] for o in d.items() if o.metaObject().className().startswith("Txt")), 5, "switch")
    switches.append(ms_since(t))
perf("account switch p50", statistics.median(switches))

# Send review: the engine builds and decodes it (network reads), then the
# sheet shows it.
t = time.perf_counter()
ticket = e.call("ui_prepareSend", {"kind": "transfer", "from": pub, "to": priv, "amount": "1"})
perf("prepareSend (engine build + decode, network)", ms_since(t))
if "value" in ticket:
    e.call("ui_reject", {"handle": ticket["value"]["handle"]})
d.click("homeSend")
d.type("sendTo", priv)
d.click("sendNext")
for o in d.items():
    if o.metaObject().className().startswith("SendFlow"):
        o.setProperty("amountText", "0.000000001")
t = time.perf_counter()
d.click("sendReview")
d.wait(lambda: d.find("approve") is not None, 60, "review")
perf("Review tap to approval sheet shown", ms_since(t))
