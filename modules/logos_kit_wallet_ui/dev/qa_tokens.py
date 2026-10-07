# QA walk for stage T (docs/design/ux-tokens-nfts.md §2): a local network,
# a token created in the app, and a stranger (the CLI, another wallet) who
# sends an unknown token and an airdrop-bait one. Checks and shots: the home
# list with "Added", the folded "Hidden · Unknown" row, Unknown and Spam
# tabs, token details with the trust panel, Manage tokens, the add tray's
# preview and decimals, and Send with a token; dark, then light.
#
#   e2e/standalone.sh
#   HOME=$(mktemp -d) QT_QPA_PLATFORM=offscreen uv run --python .qt/q692/bin/python \
#     modules/logos_kit_wallet_ui/dev/harness.py --width 480 --height 900 \
#     --script modules/logos_kit_wallet_ui/dev/qa_tokens.py --shots docs/reviews/t
import json, os, pathlib, subprocess, tempfile
from PySide6.QtCore import QMetaObject

PW = "correct horse 42"
ROOT = pathlib.Path.cwd()
LK = str(ROOT / "target/debug/logos-kit")
GENESIS = "7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb"
e = d.engine


def shown(name):
    return d.find(name) is not None


def store():
    for o in d.items():
        if o.metaObject().className().startswith("Home"):
            return o.property("store")
    raise RuntimeError("Home not found")


def sheet(name):
    d.root().setProperty("sheet", name)
    d.pump(700)


def snap():
    return e.call("ui_snapshot", {})["value"]


def tokens_of(account):
    for a in snap()["accounts"]:
        if a["accountId"] == account:
            return a.get("tokens") or []
    return []


# A stranger's wallet, driven by the CLI.
STRANGER = tempfile.mkdtemp(prefix="lk-stranger-")
SENV = dict(os.environ, LOGOS_KIT_HOME=STRANGER, LOGOS_KIT_PASSWORD="stranger-pw", LOGOS_KIT_ZONE="lez-local",
            SUPPRESS_VERBOSE_PRINTS="1", RISC0_DEV_MODE="1", LK_GENESIS_KEY=GENESIS)


def slk(*args):
    out = subprocess.run([LK, *args, "--json"], env=SENV, capture_output=True, text=True, timeout=300)
    lines = [l for l in out.stdout.strip().splitlines() if l.startswith("{") or l.startswith("[")]
    if out.returncode != 0 or not lines:
        raise RuntimeError(f"{args}: {out.stderr[-400:]}")
    return json.loads(lines[-1])


# -- the wallet, funded ------------------------------------------------------------
e.call("ui_setPrefs", {"zone": "lez-local"})
created = e.call("ui_create", {"password": PW})["value"]
pub = [a for a in created["accounts"] if a["kind"] == "public"][0]["accountId"]
d.wait(lambda: shown("balance"), 60, "home")
job = e.call("ui_requestFunds", {"account": pub})["value"]["job"]
d.wait(lambda: e.call("ui_fundStatus", {"job": job})["value"]["state"] != "running", 120, "faucet")
d.wait(lambda: any(a["accountId"] == pub and a.get("native") not in (None, "0") for a in snap()["accounts"]), 120, "funded")
store().setProperty("selected", pub)
d.pump(1500)

# -- create a token in the app ---------------------------------------------------------
d.click("manageTokens")
d.wait(lambda: shown("manageCreate"), 10, "manage")
d.shot("01-manage-empty")
d.click("manageCreate")
d.type("createName", "Logos Club Points")
d.type("createSupply", "1000000")
d.type("createDecimals", "2")
for o in d.items():
    if o.metaObject().className().startswith("CreateToken"):
        o.setProperty("holder", pub)
d.shot("02-create-token")
d.click("createNext")
d.wait(lambda: shown("approvePassword"), 60, "create review")
d.shot("03-create-review")
d.type("approvePassword", PW)
d.click("approve")
d.wait(lambda: shown("proofDone"), 120, "created")
d.click("proofDone")
d.wait(lambda: shown("tokenName"), 30, "token detail")
d.wait(lambda: d.find("tokenBalance") and d.find("tokenBalance").property("text") not in ("", "0"), 120, "created balance")
d.shot("04-token-detail-added")
sheet("")

# -- a stranger sends an unknown token and an airdrop-bait one -------------------------------
slk("init")
s1 = slk("account", "new")["accountId"]
slk("faucet", s1, "--key-env", "LK_GENESIS_KEY", "--drop", "1000000000", "--yes")
unknown = slk("token", "create", "--name", "Payroll Coin", "--supply", "5000", "--holder", s1, "--yes")["definition"]
s2 = slk("account", "new")["accountId"]
slk("faucet", s2, "--key-env", "LK_GENESIS_KEY", "--drop", "1000000000", "--yes")
bait = slk("token", "create", "--name", "Claim free gift", "--supply", "9999", "--holder", s2, "--yes")["definition"]
slk("send", "--from", s1, "--to", pub, "--token", unknown, "--amount", "42", "--yes")
slk("send", "--from", s2, "--to", pub, "--token", bait, "--amount", "1", "--yes")
e.call("ui_refresh", {})
d.wait(lambda: {t["definition"]: t["tier"] for t in tokens_of(pub)}.get(unknown) == "unknown", 180, "unknown token found")
d.wait(lambda: {t["definition"]: t["tier"] for t in tokens_of(pub)}.get(bait) == "spam", 60, "spam token found")
d.pump(2500)
assert shown("tokensMoreRow"), "the Hidden · Unknown row is missing"
assert not shown("tokenRow_" + unknown), "an unknown token is in the main list"
# Its name stays out of the activity feed too (it could be a lure).
feed = [o.property("title") for o in d.items() if o.metaObject().className().startswith("TxRow")]
assert "Received an unknown token" in feed, feed
assert not any("Claim free gift" in str(o.property("symbol")) for o in d.items() if o.metaObject().className().startswith("TxRow")), "spam name in the feed"
d.shot("05-home-with-unknown")

d.click("tokensMoreRow")
d.wait(lambda: shown("moreRow_" + unknown), 10, "unknown tab")
d.shot("06-unknown-tab")
for o in d.items():
    if o.metaObject().className().startswith("TokensMore"):
        o.setProperty("tab", 1)
d.pump(600)
assert shown("moreRow_" + bait), "spam token not in the Spam tab"
d.shot("07-spam-tab")
d.root().setProperty("tokenFocus", unknown)
sheet("tokenDetail")
d.wait(lambda: shown("tokenTrust"), 10, "unknown detail")
d.pump(2500)
d.shot("08-token-detail-unknown")
sheet("")

# -- manage tokens, then add the unknown one by ID ------------------------------------------
d.click("manageTokens")
d.wait(lambda: shown("manageAdd"), 10, "manage")
d.shot("09-manage")
d.click("manageAdd")
d.type("addTokenId", unknown)
d.wait(lambda: shown("addTokenName"), 60, "preview")
d.type("addTokenDecimals", "0")
d.shot("10-add-token-preview")
d.click("addTokenGo")
d.wait(lambda: {t["definition"]: t["tier"] for t in tokens_of(pub)}.get(unknown) == "added", 60, "added")
d.wait(lambda: shown("tokenName"), 20, "detail after add")
sheet("")
d.pump(2500)
assert shown("tokenRow_" + unknown), "the added token isn't in the main list"
d.shot("11-home-after-add")

# -- send with a token --------------------------------------------------------------------------
d.click("homeSend")
d.type("sendTo", s1)
for o in d.items():
    if o.metaObject().className().startswith("SendFlow"):
        created_def = [t["definition"] for t in tokens_of(pub) if t.get("name") == "Logos Club Points"][0]
        o.setProperty("token", created_def)
d.click("sendNext")
for o in d.items():
    if o.metaObject().className().startswith("SendFlow"):
        o.setProperty("amountText", "12.5")
d.pump(800)
d.shot("12-send-token-amount")
sheet("")

# -- light ------------------------------------------------------------------------------------------
d.click("themeToggle")
d.pump(800)
d.shot("13-home-light")
d.click("tokensMoreRow")
d.pump(800)
d.shot("14-unknown-tab-light")
d.root().setProperty("tokenFocus", bait)
sheet("tokenDetail")
d.pump(2500)
d.shot("15-token-detail-spam-light")
