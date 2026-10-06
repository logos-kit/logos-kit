#!/usr/bin/env bash
# Stage T: the drip sends a sample token with each test-LGO drop, and a new
# wallet finds it on its own (it lands in the account's token account; the
# wallet reads the blocks). Against the standalone sequencer (e2e/standalone.sh),
# dev-mode proofs; the LEZ debug genesis key plays the drip's treasury.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export RISC0_DEV_MODE=1 SUPPRESS_VERBOSE_PRINTS=1
(cd "$ROOT" && cargo build -q -p logos-kit-cli -p logos-kit-drip)
LK="$ROOT/target/debug/logos-kit"
DRIP="$ROOT/target/debug/logos-kit-drip"
GENESIS=7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb
PORT="${LK_DRIP_TEST_PORT:-18080}"

TREASURY_HOME="$(mktemp -d)" USER_HOME="$(mktemp -d)" DRIP_DATA="$(mktemp -d)"
DRIP_PID=""
trap '[[ -n "$DRIP_PID" ]] && kill "$DRIP_PID" 2>/dev/null; rm -rf "$TREASURY_HOME" "$USER_HOME" "$DRIP_DATA"' EXIT
field() { tail -1 | python3 -c "import sys,json; v=json.load(sys.stdin); print(eval('v'+sys.argv[1]))" "$1"; }
check() { [[ "$2" == "$3" ]] || { echo "FAIL $1: got $2, want $3" >&2; exit 1; }; echo "ok   $1 = $2"; }

# The treasury holds the sample token in its own slot.
T() { LOGOS_KIT_HOME="$TREASURY_HOME" LOGOS_KIT_PASSWORD=treasury-pw LOGOS_KIT_ZONE=lez-local "$LK" "$@"; }
T init --json >/dev/null 2>&1
G=$(LOGOS_KIT_IMPORT_KEY="$GENESIS" T account import --json | field "['accountId']")
DEF=$(T token create --name "Logos Kit Test Token" --supply 100000000 --holder "$G" --yes --json | tail -1 | python3 -c "import sys,json; print(json.load(sys.stdin)['definition'])")
echo "ok   sample token $DEF held by the treasury $G"

# The drip, with the sample token configured.
LK_DRIP_KEY="$GENESIS" LK_DRIP_SEQUENCER="http://127.0.0.1:${LK_E2E_PORT:-3040}" LK_DRIP_DATA="$DRIP_DATA" \
  LK_DRIP_LISTEN="127.0.0.1:$PORT" LK_DRIP_TOKEN="$DEF" LK_DRIP_TOKEN_AMOUNT=10000 "$DRIP" >"$DRIP_DATA/drip.log" 2>&1 &
DRIP_PID=$!
for _ in $(seq 1 50); do curl -fs "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && break; sleep 0.2; done
check "the drip advertises its sample token" "$(curl -fs "http://127.0.0.1:$PORT/" | python3 -c "import sys,json; print(json.load(sys.stdin)['sampleToken']['definition'])")" "$DEF"

# A new wallet claims test LGO and finds the sample token by itself.
U() { LOGOS_KIT_HOME="$USER_HOME" LOGOS_KIT_PASSWORD=user-pw LOGOS_KIT_ZONE=lez-local "$LK" "$@"; }
U init --json >/dev/null 2>&1
A=$(U account new --json | field "['accountId']")
check "test LGO" "$(U faucet "$A" --url "http://127.0.0.1:$PORT" --yes --json | field "['status']")" funded
FOUND=0
for _ in $(seq 1 30); do
  FOUND=$(U token list --all --json | tail -1 | python3 -c "import sys,json; print(sum(int(h['amount']) for h in json.load(sys.stdin) if h['definition']=='$DEF' and h['account']=='$A' and h['via']=='ata'))")
  [[ "$FOUND" != 0 ]] && break
  sleep 2
done
check "the sample token arrived in the account's token account" "$FOUND" 10000
echo "OK: the drip sends the sample token and a new wallet finds it"
