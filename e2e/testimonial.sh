#!/usr/bin/env bash
# S5 exit proof, through the `logos-kit` CLI against the standalone sequencer
# (e2e/standalone.sh), dev-mode proofs:
#   - the reproducibly built testimonial program deploys and checks out as
#     `verified_local` (recognised by its image, wherever it is deployed);
#   - posts from three distinct accounts (two wallets) land and decode (no
#     `--ack-unknown`), a second post by the same account and a post from a
#     private account are refused;
#   - `list` and `evidence` read everything back from chain data alone.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export RISC0_DEV_MODE=1
(cd "$ROOT" && cargo build -q -p logos-kit-cli)
LK="$ROOT/target/debug/logos-kit"

export LOGOS_KIT_HOME="$(mktemp -d)"
B_HOME="$(mktemp -d)"
export LOGOS_KIT_PASSWORD=e2e-password LOGOS_KIT_ZONE=lez-local SUPPRESS_VERBOSE_PRINTS=1
trap 'rm -rf "$LOGOS_KIT_HOME" "$B_HOME"' EXIT
# LEZ debug genesis account (vendor/lez/Justfile `wallet-import-test-accounts`).
export LK_GENESIS_KEY=7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb
field() { tail -1 | python3 -c "import sys,json; v=json.load(sys.stdin); print(eval('v'+sys.argv[1]))" "$1"; }
check() { [[ "$2" == "$3" ]] || { echo "FAIL $1: got $2, want $3" >&2; exit 1; }; echo "ok   $1 = $2"; }
refused() { # label, expected error text, command…
  local label="$1" want="$2"; shift 2
  local err
  if err=$("$@" 2>&1); then echo "FAIL $label: was accepted" >&2; exit 1; fi
  [[ "$err" == *"$want"* ]] || { echo "FAIL $label: $err" >&2; exit 1; }
  echo "ok   $label refused ($want)"
}

"$LK" init --json 2>/dev/null >/dev/null
DEPLOYER=$("$LK" account new --json | field "['accountId']")
A1=$("$LK" account new --json | field "['accountId']")
A2=$("$LK" account new --json | field "['accountId']")
PRIV=$("$LK" account new --private --json | field "['accountId']")
for acct in "$DEPLOYER" "$A1" "$A2"; do
  "$LK" faucet "$acct" --key-env LK_GENESIS_KEY --drop 2000000000 --yes --json >/dev/null
done

# Deploy (upgradeable, as staging would be) and check the header.
PROGRAM=$("$LK" testimonial deploy --payer "$DEPLOYER" --yes --json | field "['account']")
echo "info program $PROGRAM"
check "program name" "$("$LK" program "$PROGRAM" --json | field "['name']")" testimonial
check "program status" "$("$LK" program "$PROGRAM" --json | field "['status']")" verified_local

# Posts decode (the CLI would demand --ack-unknown otherwise).
POST=$("$LK" testimonial post --program "$PROGRAM" --from "$A1" --username alice \
  --text "I use Logos Kit to post on LEZ." --yes --json)
check "post outcome (read back from its record)" "$(echo "$POST" | field "['outcome']")" success
"$LK" testimonial post --program "$PROGRAM" --from "$A2" \
  --text $'Logos Kit wallet:\nconnect, approve, done.' --yes --json >/dev/null

refused "second post by the same account" "already posted" \
  "$LK" testimonial post --program "$PROGRAM" --from "$A1" --text "again" --yes --json
refused "post from a private account" "must be public" \
  "$LK" testimonial post --program "$PROGRAM" --from "$PRIV" --text "hidden" --yes --json
refused "text with a direction override" "text must be" \
  "$LK" testimonial post --program "$PROGRAM" --from "$A2" --text $'evil‮txt' --yes --json

# A second wallet posts too.
LOGOS_KIT_HOME="$B_HOME" "$LK" init --json 2>/dev/null >/dev/null
B1=$(LOGOS_KIT_HOME="$B_HOME" "$LK" account new --json | field "['accountId']")
LOGOS_KIT_HOME="$B_HOME" "$LK" faucet "$B1" --key-env LK_GENESIS_KEY --drop 1000000000 --yes --json >/dev/null
LOGOS_KIT_HOME="$B_HOME" "$LK" testimonial post --program "$PROGRAM" --from "$B1" \
  --username bob --text "Logos Kit made my first LEZ tx easy." --yes --json >/dev/null

# Read back from chain data alone.
LIST=$("$LK" testimonial list --program "$PROGRAM" --json)
check "list count" "$(echo "$LIST" | field ".__len__()")" 3
check "first author" "$(echo "$LIST" | field "[0]['author']")" "$A1"
check "first username" "$(echo "$LIST" | field "[0]['username']")" alice
check "second text" "$(echo "$LIST" | field "[1]['text']" | head -1)" "Logos Kit wallet:"
check "third author" "$(echo "$LIST" | field "[2]['author']")" "$B1"

SNAP="$LOGOS_KIT_HOME/snapshots"
EV=$("$LK" testimonial evidence --program "$PROGRAM" --snapshot "$SNAP" --json)
check "evidence distinct authors" "$(echo "$EV" | field "['distinctAuthors']")" 3
check "evidence tally consistent" "$(echo "$EV" | field "['programs'][0]['consistent']")" True
check "evidence months" "$(echo "$EV" | field "['months'].__len__()")" 1
check "evidence target met" "$(echo "$EV" | field "['target']['met']")" False
check "evidence author other txs" "$(echo "$EV" | field "['entries'][0]['otherTxs']")" 0
check "snapshot written" "$(ls "$SNAP" | wc -l | tr -d ' ')" 1

echo "OK: S5 testimonial deploy + posts + evidence (dev-mode proofs)"
