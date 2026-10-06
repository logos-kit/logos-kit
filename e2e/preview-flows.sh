#!/usr/bin/env bash
# The LP-0021 user flows against the public preview network (lez-preview,
# LEZ 0.3-rc1), as a fresh wallet, with REAL proofs (the network verifies
# them). Takes ~15-20 min on an M-series Mac (three private proofs).
#   e2e/preview-flows.sh [--tokens-only]   (LK_ZONE=lez-preview by default)
# --tokens-only skips the native public/private steps (two of the proofs).
set -euo pipefail
NATIVE=1; [[ "${1:-}" == --tokens-only ]] && NATIVE=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
(cd "$ROOT" && cargo build -q --release -p logos-kit-cli)
LK="$ROOT/target/release/logos-kit"
export LOGOS_KIT_HOME="$(mktemp -d)" LOGOS_KIT_PASSWORD=preview-flows SUPPRESS_VERBOSE_PRINTS=1
export LOGOS_KIT_ZONE="${LK_ZONE:-lez-preview}"
trap 'rm -rf "$LOGOS_KIT_HOME"' EXIT
last() { tail -1; }
get() { python3 -c "import sys,json; v=json.load(sys.stdin); print(eval('v'+sys.argv[1]))" "$1"; }
ok() { # label, json
  local out; out=$(echo "$2" | get "['outcome']" 2>/dev/null || echo "?")
  [[ "$out" == success ]] || { echo "FAIL $1: $2" >&2; exit 1; }
  echo "ok   $1 ($(echo "$2" | get "['block']" 2>/dev/null || echo -) )"
}
t0=$SECONDS; step() { echo "---- $1  [$(( SECONDS - t0 ))s]"; }

"$LK" init --json >/dev/null 2>&1
A=$("$LK" account new --json | last | get "['accountId']")
B=$("$LK" account new --json | last | get "['accountId']")
P=$("$LK" account new --private --json | last | get "['accountId']")
echo "info zone $LOGOS_KIT_ZONE  A=$A  B=$B  P=$P"

step "faucet (drip) -> A"
F=$("$LK" faucet "$A" --yes --json | last); echo "$F"
S=$(echo "$F" | get "['status']")
# A slow network can include the drop after the drip stops watching
# ("outcome_unknown"): then the balance is the proof, as in the wallet.
if [[ $S == outcome_unknown ]]; then
  for _ in $(seq 1 60); do
    [[ $("$LK" balance "$A" --json | last | get "['balance']") != 0 ]] && S=funded && break
    sleep 15
  done
fi
[[ $S == funded ]] || { echo "FAIL faucet ($S)" >&2; exit 1; }

if (( NATIVE )); then
step "public send A -> B"
ok "public send" "$("$LK" send --from "$A" --to "$B" --amount 1000 --yes --json | last)"

step "shield A -> private P (real proof)"
ok "shield" "$("$LK" send --from "$A" --to "$P" --amount 5000 --yes --json | last)"

step "private P -> public B (real proof)"
ok "private send" "$("$LK" send --from "$P" --to "$B" --amount 100 --yes --json | last)"
fi

step "token create (holder A)"
T=$("$LK" token create --name KIT --supply 1000000 --holder "$A" --yes --json | last); echo "$T"
DEF=$(echo "$T" | get "['definition']")
ok "token create" "$(echo "$T" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['status']))")"

step "token send A -> B (public)"
ok "token public send" "$("$LK" send --from "$A" --to "$B" --amount 250 --token "$DEF" --yes --json | last)"

step "token send A -> private P (real proof)"
ok "token private send" "$("$LK" send --from "$A" --to "$P" --amount 10 --token "$DEF" --yes --json | last)"

step "testimonial post from A (registered program)"
ok "testimonial" "$("$LK" testimonial post --from "$A" --username preview-e2e --text "Logos Kit end to end on the LEZ 0.3 preview network." --yes --json | last)"

step "balances"
"$LK" balance "$B" --json | last
"$LK" balance "$P" --json | last
"$LK" token list --json | last | head -c 600; echo
echo "OK preview flows on $LOGOS_KIT_ZONE in $(( SECONDS - t0 ))s"
