#!/usr/bin/env bash
# S8: the testimonial app end to end against the standalone sequencer, in the
# two-window dev harness (app + wallet UI on the release engine):
#   deploy the program (CLI), seed one post, then in the app: connect → no
#   funds → faucet → compose (validation) → approve in the wallet → included →
#   "your testimonial". Screenshots go to docs/reviews/s8/testimonial/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export RISC0_DEV_MODE=1
(cd "$ROOT" && cargo build -q -p logos-kit-cli && cargo build -q --release -p wallet-engine)
LK="$ROOT/target/debug/logos-kit"

export LOGOS_KIT_HOME="$(mktemp -d)"
export LOGOS_KIT_PASSWORD=e2e-password LOGOS_KIT_ZONE=lez-local SUPPRESS_VERBOSE_PRINTS=1
trap 'rm -rf "$LOGOS_KIT_HOME"' EXIT
export LK_GENESIS_KEY=7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb
field() { tail -1 | python3 -c "import sys,json; v=json.load(sys.stdin); print(eval('v'+sys.argv[1]))" "$1"; }

"$LK" init --json 2>/dev/null >/dev/null
DEPLOYER=$("$LK" account new --json | field "['accountId']")
SEED=$("$LK" account new --json | field "['accountId']")
for acct in "$DEPLOYER" "$SEED"; do
  "$LK" faucet "$acct" --key-env LK_GENESIS_KEY --drop 2000000000 --yes --json >/dev/null
done
PROGRAM=$("$LK" testimonial deploy --payer "$DEPLOYER" --yes --json | field "['account']")
echo "info program $PROGRAM"
"$LK" testimonial post --program "$PROGRAM" --from "$SEED" --username alice \
  --text "I use the Logos Kit wallet on LEZ to pay friends privately." --yes --json >/dev/null

cd "$ROOT"
uv run -q --python .qt/q692/bin/python modules/logos_kit_wallet_ui/dev/app_harness.py \
  --app logos_kit_testimonial --qml modules/logos_kit_testimonial/qml/Main.qml \
  --prop "program=$PROGRAM" \
  --script modules/logos_kit_testimonial/dev/qa_testimonial.py \
  --shots docs/reviews/s8/testimonial 2>&1 | grep -v "usedbeforedeclared"
