#!/usr/bin/env bash
# S4 exit proof, through the `logos-kit` CLI against the standalone sequencer
# (e2e/standalone.sh), dev-mode proofs:
#   - the faucet reaches `funded` (public target) and funds + shields a private one;
#   - a demo token is created, then moved on every route: public → public,
#     shield, private → private, unshield;
#   - native unshield; the builtin token program's header checks out;
#   - an encrypted backup restores with its password.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export RISC0_DEV_MODE=1
(cd "$ROOT" && cargo build -q -p logos-kit-cli)
LK="$ROOT/target/debug/logos-kit"

export LOGOS_KIT_HOME="$(mktemp -d)"
RESTORED="$(mktemp -d)"
export LOGOS_KIT_PASSWORD=e2e-password LOGOS_KIT_ZONE=lez-local SUPPRESS_VERBOSE_PRINTS=1
trap 'rm -rf "$LOGOS_KIT_HOME" "$RESTORED"' EXIT
# LEZ debug genesis account (vendor/lez/Justfile `wallet-import-test-accounts`),
# used here as the faucet's funded key (the e2e GenesisSupply backend).
export LK_GENESIS_KEY=7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb
field() { tail -1 | python3 -c "import sys,json; v=json.load(sys.stdin); print(eval('v'+sys.argv[1]))" "$1"; }
check() { [[ "$2" == "$3" ]] || { echo "FAIL $1: got $2, want $3" >&2; exit 1; }; echo "ok   $1 = $2"; }

"$LK" init --json 2>/dev/null >/dev/null
PUB=$("$LK" account new --json | field "['accountId']")
PUB2=$("$LK" account new --json | field "['accountId']")
PRIV=$("$LK" account new --private --json | field "['accountId']")
PRIV2=$("$LK" account new --private --json | field "['accountId']")

# Faucet: public target → funded.
OUT=$("$LK" faucet "$PUB" --key-env LK_GENESIS_KEY --drop 2000000000 --yes --json)
check "faucet public status" "$(echo "$OUT" | field "['status']")" funded
check "PUB native" "$("$LK" balance "$PUB" --json | field "['balance']")" 2000000000
# Rate limit is per process here (a service keeps it); a second claim works.
# Faucet: private target → funds PUB2, then shields into PRIV.
"$LK" faucet "$PRIV" --via "$PUB2" --key-env LK_GENESIS_KEY --drop 5000 --yes --json >/dev/null
check "PRIV native (faucet → shield)" "$("$LK" balance "$PRIV" --json | field "['balance']")" 5000

# Demo token: a new definition account; all supply to PUB.
DEF=$("$LK" token create --name DEMO --supply 1000000 --holder "$PUB" --yes --json | field "['definition']")
check "PUB DEMO" "$("$LK" balance "$PUB" --token "$DEF" --json | field "['balance']")" 1000000

"$LK" send --from "$PUB" --to "$PUB2" --token "$DEF" --amount 100 --yes --json >/dev/null
check "public token send" "$("$LK" balance "$PUB2" --token "$DEF" --json | field "['balance']")" 100

"$LK" shield --from "$PUB" --to "$PRIV2" --token "$DEF" --amount 50 --yes --json >/dev/null
check "token shield" "$("$LK" balance "$PRIV2" --token "$DEF" --json | field "['balance']")" 50

PRIV3=$("$LK" account new --private --json | field "['accountId']")
"$LK" send --from "$PRIV2" --to "$PRIV3" --token "$DEF" --amount 20 --yes --json >/dev/null
check "private token send (from)" "$("$LK" balance "$PRIV2" --token "$DEF" --json | field "['balance']")" 30
check "private token send (to)" "$("$LK" balance "$PRIV3" --token "$DEF" --json | field "['balance']")" 20

PUB3=$("$LK" account new --json | field "['accountId']")
"$LK" deshield --from "$PRIV3" --to "$PUB3" --token "$DEF" --amount 5 --yes --json >/dev/null
check "token unshield" "$("$LK" balance "$PUB3" --token "$DEF" --json | field "['balance']")" 5

"$LK" deshield --from "$PRIV" --to "$PUB3" --amount 1234 --yes --json >/dev/null
check "native unshield" "$("$LK" balance "$PUB3" --json | field "['balance']")" 1234
check "native private left" "$("$LK" balance "$PRIV" --json | field "['balance']")" 3766

# Private payment to someone else's keys: wallet B shares its private
# account's keys; A pays them; B finds the note by syncing.
B_HOME="$(mktemp -d)"; trap 'rm -rf "$LOGOS_KIT_HOME" "$RESTORED" "$B_HOME"' EXIT
LOGOS_KIT_HOME="$B_HOME" "$LK" init --json 2>/dev/null >/dev/null
B_PRIV=$(LOGOS_KIT_HOME="$B_HOME" "$LK" account new --private --json | field "['accountId']")
LOGOS_KIT_HOME="$B_HOME" "$LK" account keys "$B_PRIV" > "$B_HOME/b.keys"
"$LK" send --from "$PRIV" --to-keys "$B_HOME/b.keys" --amount 700 --yes --json >/dev/null
check "native private left after paying B" "$("$LK" balance "$PRIV" --json | field "['balance']")" 3066
LOGOS_KIT_HOME="$B_HOME" "$LK" sync --json >/dev/null
B_GOT=$(LOGOS_KIT_HOME="$B_HOME" "$LK" account list --json | tail -1 | python3 -c "
import sys,json
print(len([a for a in json.load(sys.stdin) if a['kind']=='private']))")
echo "info B private accounts after sync: $B_GOT"
B_SUM=0
for acct in $(LOGOS_KIT_HOME="$B_HOME" "$LK" account list --json | tail -1 | python3 -c "
import sys,json
print(' '.join(a['accountId'] for a in json.load(sys.stdin) if a['kind']=='private'))"); do
  B_SUM=$((B_SUM + $(LOGOS_KIT_HOME="$B_HOME" "$LK" balance "$acct" --json | field "['balance']")))
done
check "B received privately" "$B_SUM" 700

# Tokens in an associated token account are sent through the ATA program.
PUB4=$("$LK" account new --json | field "['accountId']")
"$LK" faucet "$PUB4" --key-env LK_GENESIS_KEY --drop 1000000000 --yes --json >/dev/null
ATA4=$("$LK" token ata "$PUB4" "$DEF" --json | field "['ata']")
"$LK" send --from "$PUB" --to "$ATA4" --token "$DEF" --amount 7 --yes --json >/dev/null
"$LK" send --from "$PUB4" --to "$PUB2" --token "$DEF" --amount 3 --yes --json >/dev/null
check "ATA token send" "$("$LK" balance "$PUB2" --token "$DEF" --json | field "['balance']")" 103

N=$("$LK" token list --json | tail -1 | python3 -c "import sys,json; print(len([h for h in json.load(sys.stdin) if h['definition']=='$DEF']))")
check "token list holdings" "$N" 6

STATUS=$("$LK" program token --json | field "['status']")
[[ "$STATUS" == verified_local ]] || { echo "FAIL token program status $STATUS" >&2; exit 1; }
echo "ok   builtin token program header = $STATUS"

"$LK" backup export "$RESTORED/backup.json"
LOGOS_KIT_HOME="$RESTORED/home" "$LK" backup import "$RESTORED/backup.json" >/dev/null
check "restored PUB DEMO" "$(LOGOS_KIT_HOME="$RESTORED/home" "$LK" balance "$PUB" --token "$DEF" --json | field "['balance']")" 999843

echo "OK: S4 faucet + demo token on every route + backup (dev-mode proofs)"
