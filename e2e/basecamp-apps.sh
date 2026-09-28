#!/usr/bin/env bash
# S8 in a real Basecamp (tests/apps-flow.mjs): wallet + testimonial + faucet
# installed into an isolated user dir, the standalone sequencer, the
# testimonial program deployed with the CLI, then the apps driven through the
# shell's intents. Needs `just lgx` for the four modules.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${LOGOS_TOOLS:-$HOME/.local/share/logos-tools}"
DIR="${LK_BC_DIR:-/tmp/lk-bc-apps}"
pkill -9 -f 'logos_host|LogosBasecamp|ui-host' 2>/dev/null || true
rm -rf "$DIR"; mkdir -p "$DIR"
for m in logos_kit_wallet logos_kit_wallet_ui logos_kit_testimonial logos_kit_faucet; do
  "$TOOLS/lgpm-aarch64-macos/bin/lgpm" --modules-dir "$DIR/modules" --ui-plugins-dir "$DIR/plugins" \
    --allow-unsigned install --file "$ROOT"/modules/$m/result-portable/*.lgx >/dev/null
done
"$ROOT/e2e/standalone.sh"
export RISC0_DEV_MODE=1

# Deploy the testimonial program from a throwaway CLI wallet.
(cd "$ROOT" && cargo build -q -p logos-kit-cli)
LK="$ROOT/target/debug/logos-kit"
H="$(mktemp -d)"
export LOGOS_KIT_PASSWORD=e2e-password LOGOS_KIT_ZONE=lez-local SUPPRESS_VERBOSE_PRINTS=1
export LK_GENESIS_KEY=7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb
field() { tail -1 | python3 -c "import sys,json; v=json.load(sys.stdin); print(eval('v'+sys.argv[1]))" "$1"; }
LOGOS_KIT_HOME="$H" "$LK" init --json 2>/dev/null >/dev/null
D=$(LOGOS_KIT_HOME="$H" "$LK" account new --json | field "['accountId']")
LOGOS_KIT_HOME="$H" "$LK" faucet "$D" --key-env LK_GENESIS_KEY --drop 2000000000 --yes --json >/dev/null
PROGRAM=$(LOGOS_KIT_HOME="$H" "$LK" testimonial deploy --payer "$D" --yes --json | field "['account']")
rm -rf "$H"
echo "info program $PROGRAM"

"$TOOLS/basecamp-inspector/bin/LogosBasecamp" --user-dir "$DIR" > "$DIR/basecamp.log" 2>&1 &
BC=$!
[[ "${LK_KEEP:-}" == 1 ]] || trap 'kill $BC 2>/dev/null; pkill -9 -f "logos_host|ui-host" 2>/dev/null; "$ROOT/e2e/standalone.sh" stop' EXIT
for _ in $(seq 1 120); do nc -z 127.0.0.1 3768 2>/dev/null && break; sleep 2; done
sleep 5
PROGRAM="$PROGRAM" node "$ROOT/tests/apps-flow.mjs" --shots "$ROOT/docs/reviews/s8/basecamp"
