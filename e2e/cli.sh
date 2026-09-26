#!/usr/bin/env bash
# S3 exit proof: a public send and a shield (with progress) through the
# `logos-kit` CLI against the standalone sequencer (e2e/standalone.sh).
#
#   e2e/cli.sh               dev-mode proofs (fast; the sequencer doesn't verify)
#   LK_REAL_PROOF=1 e2e/cli.sh   real proofs (release build; ~5-6 min per shield)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE=debug
if [[ "${LK_REAL_PROOF:-}" == "1" ]]; then
  PROFILE=release
  unset RISC0_DEV_MODE
else
  export RISC0_DEV_MODE=1
fi
(cd "$ROOT" && cargo build -q -p logos-kit-cli $([[ $PROFILE == release ]] && echo --release))
LK="$ROOT/target/$PROFILE/logos-kit"

export LOGOS_KIT_HOME="$(mktemp -d)"
export LOGOS_KIT_PASSWORD=e2e-password LOGOS_KIT_ZONE=lez-local SUPPRESS_VERBOSE_PRINTS=1
trap 'rm -rf "$LOGOS_KIT_HOME"' EXIT
# LEZ prints some connect notices on stdout; JSON results are always the last line.
# LEZ debug genesis account (vendor/lez/Justfile `wallet-import-test-accounts`).
GENESIS_KEY=7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb
field() { tail -1 | python3 -c "import sys,json; print(json.load(sys.stdin)['$1'])"; }

"$LK" init --json 2>/dev/null >/dev/null
FUNDED=$(LOGOS_KIT_IMPORT_KEY=$GENESIS_KEY "$LK" account import --json | field accountId)
PUB=$("$LK" account new --json | field accountId)
PRIV=$("$LK" account new --private --json | field accountId)
echo "funded $FUNDED  public $PUB  private $PRIV"

"$LK" send --from "$FUNDED" --to "$PUB" --amount 500000 --yes
[[ "$("$LK" balance "$PUB" --json | field balance)" == 500000 ]] || { echo "public send: wrong balance" >&2; exit 1; }

"$LK" shield --from "$PUB" --to "$PRIV" --amount 1234 --yes
[[ "$("$LK" balance "$PRIV" --json | field balance)" == 1234 ]] || { echo "shield: wrong private balance" >&2; exit 1; }
echo "OK: public send + shield ($PROFILE, ${RISC0_DEV_MODE:+dev-mode }proofs)"
