#!/usr/bin/env python3
"""LWS-0 capability matrix: what the protocol defines, and what the real
wallet and the conformance fake answer.

    python3 scripts/capability-matrix.py          # write docs/protocol/capability-matrix.{md,json}
    python3 scripts/capability-matrix.py --check  # exit 1 if the committed files are stale

Sources (read, never executed, so it needs no build):
- protocol/schema/{methods,intents}.json and protocol/src/errors.ts: the protocol;
- crates/wallet-engine/src/service.rs + policy.rs, modules/logos_kit_wallet/*.lidl,
  modules/logos_kit_wallet_ui/metadata.json: the real wallet;
- modules/logos_kit_wallet_fake/engine/src/lib.rs + ui/metadata.json: the fake.
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/protocol/capability-matrix"
REAL = ROOT / "crates/wallet-engine/src"
FAKE = ROOT / "modules/logos_kit_wallet_fake/engine/src/lib.rs"


def read(p):
    return (ROOT / p).read_text() if not isinstance(p, pathlib.Path) else p.read_text()


def arms(src):
    """`"lez_x" [| "lez_y"] => body` in the first `match method {` that lists LWS-0 methods."""
    out = {}
    parts = re.split(r'\n\s*((?:"lez_\w+"\s*\|?\s*)+)=>', src)
    for i in range(1, len(parts) - 1, 2):
        body = parts[i + 1].split("\n        _ =>")[0][:1500]
        for m in re.findall(r'"(lez_\w+)"', parts[i]):
            out.setdefault(m, body)
    return out


def classify(method, body, lidl=None):
    if lidl is not None and method not in lidl:
        return "not exposed"
    if body is None:
        return "—"
    if "4200" in body:
        return "intent only"
    if method == "lez_connect":
        return "silent restore; else intent"
    return "yes"


def codes_in(src, enum=None):
    found = set(int(c) for c in re.findall(r"(?<![\w.])(-326\d\d|4\d{3}|5\d{3}|6\d{3})(?![\w.])", src))
    for name, val in (enum or {}).items():
        if f"Code::{name}" in src:
            found.add(val)
    return found


def rust_json_keys(src, fn):
    """Top-level keys and literal values of `fn <fn>() -> Value { json!({ … }) }`."""
    m = re.search(rf"fn {fn}\(\) -> Value \{{\s*json!\(\{{(.*?)\n    \}}\)", src, re.S)
    if not m:
        return {}
    out = {}
    for k, v in re.findall(r'^\s{8}"(\w+)":\s*(.+?),?$', m.group(1), re.M):
        out[k] = v.strip().rstrip(",")
    return out


def main():
    methods = json.loads(read("protocol/schema/methods.json"))
    intents = json.loads(read("protocol/schema/intents.json"))["intents"]
    errors_ts = read("protocol/src/errors.ts")
    codes = dict((n, int(v)) for n, v in re.findall(r"^\s+(\w+): (-?\d+),$", errors_ts.split("} as const")[0], re.M))
    defaults = dict((int(c), m) for c, m in re.findall(r"^\s+(-?\d+): ['\"](.+)['\"],$", errors_ts, re.M))

    service = read(REAL / "service.rs")
    real_src = "\n".join(read(p) for p in sorted(REAL.glob("*.rs")))
    enum = dict((n, int(v)) for n, v in re.findall(r"^\s+(\w+) = (-?\d+),$",
                                                     re.search(r"pub enum Code \{(.*?)\}", read(REAL / "policy.rs"), re.S).group(1), re.M))
    lidl = set(re.findall(r"method (lez_\w+)\(", read("modules/logos_kit_wallet/logos_kit_wallet.lidl")))
    fake_src = read(FAKE)
    real_arms, fake_arms = arms(service), arms(fake_src)
    real_intents = [p["intent"] for p in json.loads(read("modules/logos_kit_wallet_ui/metadata.json"))["provides"]]
    fake_meta = ROOT / "modules/logos_kit_wallet_fake/ui/metadata.json"
    fake_intents = [p["intent"] for p in json.loads(fake_meta.read_text())["provides"]] if fake_meta.exists() else []
    fake_handles = set(re.findall(r'^\s+"(lez\.[\w.]+)" =>', fake_src, re.M))
    scen_block = fake_src.split("pub const SCENARIOS")[1].split("];")[0]
    scenarios = [(n, re.sub(r"\\\n\s*", "", d).replace('\\"', '"'))
                 for n, d in re.findall(r'\(\s*"(\w+)",\s*"((?:[^"\\]|\\.)*)",?\s*\)', scen_block, re.S)]

    by_method = {i["method"]: i["intent"] for i in intents if i.get("method")}
    rows = []
    for name, spec in methods["methods"].items():
        rows.append({
            "method": name,
            "userFacing": bool(spec.get("userFacing")),
            "intent": by_method.get(name),
            "required": spec["params"].get("required", []),
            "result": sorted((spec.get("result") or {}).get("properties", {}).keys()),
            "real": classify(name, real_arms.get(name), lidl),
            "fake": classify(name, fake_arms.get(name)),
        })
    intent_rows = [{
        "intent": i["intent"], "method": i.get("method") or None,
        "real": i["intent"] in real_intents,
        "fake": i["intent"] in fake_intents and i["intent"] in fake_handles,
    } for i in intents]
    real_codes, fake_codes = codes_in(real_src, enum), codes_in(fake_src)
    error_rows = [{"code": v, "name": n, "message": defaults.get(v, ""), "real": v in real_codes, "fake": v in fake_codes}
                  for n, v in codes.items()]
    caps_real, caps_fake = rust_json_keys(service, "capabilities"), rust_json_keys(fake_src, "capabilities")
    cap_keys = list(json.loads(read("protocol/schema/lws0.schema.json"))["$defs"]["Capabilities"]["properties"])
    cap_rows = [{"capability": k, "real": caps_real.get(k), "fake": caps_fake.get(k)} for k in cap_keys]
    notes = [{"notification": n, "real": n in real_src, "fake": n in fake_src} for n in methods["notifications"]]

    data = {"protocol": methods["version"], "methods": rows, "intents": intent_rows,
            "capabilities": cap_rows, "errors": error_rows, "notifications": notes,
            "fakeScenarios": [{"name": n, "description": d} for n, d in scenarios]}

    yn = lambda b: "yes" if b else "—"
    md = [
        "# LWS-0 capability matrix",
        "",
        "Generated by `scripts/capability-matrix.py` (`just capability-matrix`); don't edit by hand.",
        f"Protocol {methods['version']}. **Real** is the Logos Kit wallet (core `logos_kit_wallet` +",
        "UI `logos_kit_wallet_ui`); **fake** is the conformance fake (`modules/logos_kit_wallet_fake`).",
        "",
        "## Methods (called on the wallet core module)",
        "",
        "| Method | User-facing | Through intent | Required params | Real | Fake |",
        "|---|---|---|---|---|---|",
    ]
    md += [f"| `{r['method']}` | {yn(r['userFacing'])} | {('`' + r['intent'] + '`') if r['intent'] else '—'} | "
           f"{', '.join(r['required']) or '—'} | {r['real']} | {r['fake']} |" for r in rows]
    md += ["", "## Intents (opened through the Basecamp shell)", "", "| Intent | Method | Real | Fake |", "|---|---|---|---|"]
    md += [f"| `{r['intent']}` | {('`' + r['method'] + '`') if r['method'] else '— (opens the wallet)'} | {yn(r['real'])} | {yn(r['fake'])} |"
           for r in intent_rows]
    md += ["", "## Capabilities (`lez_getCapabilities`)", "", "| Field | Real | Fake |", "|---|---|---|"]
    md += [f"| `{r['capability']}` | `{r['real'] or '—'}` | `{r['fake'] or '—'}` |" for r in cap_rows]
    md += ["", "## Error codes", "", "Whether each wallet can answer with the code (found in its source).", "",
           "| Code | Name | Default message | Real | Fake |", "|---|---|---|---|---|"]
    md += [f"| {r['code']} | {r['name']} | {r['message']} | {yn(r['real'])} | {yn(r['fake'])} |" for r in error_rows]
    md += ["", "## Notifications", "",
           "Basecamp modules can't push LWS-0 notifications to an app; wallets emit `request_updated` and",
           "`wallet_event` module events, and apps poll (the SDK does).", "",
           "| Notification | Real | Fake |", "|---|---|---|"]
    md += [f"| `{r['notification']}` | {yn(r['real'])} | {yn(r['fake'])} |" for r in notes]
    md += ["", "## Fake wallet scenarios", "", "| Scenario | What the fake does |", "|---|---|"]
    md += [f"| `{n}` | {d.replace('|', '/')} |" for n, d in scenarios]
    md_text = "\n".join(md) + "\n"
    json_text = json.dumps(data, indent=2) + "\n"

    if "--check" in sys.argv:
        stale = [p for p, t in ((OUT.with_suffix(".md"), md_text), (OUT.with_suffix(".json"), json_text))
                 if not p.exists() or p.read_text() != t]
        if stale:
            print("stale: " + ", ".join(str(p.relative_to(ROOT)) for p in stale) + " (run `just capability-matrix`)")
            sys.exit(1)
        print("capability matrix is up to date")
        return
    OUT.with_suffix(".md").write_text(md_text)
    OUT.with_suffix(".json").write_text(json_text)
    print(f"wrote {OUT.relative_to(ROOT)}.md/.json: {len(rows)} methods, {len(intent_rows)} intents, "
          f"{len(error_rows)} error codes, {len(scenarios)} fake scenarios")


if __name__ == "__main__":
    main()
