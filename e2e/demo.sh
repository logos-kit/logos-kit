#!/usr/bin/env bash
# Logos Kit evaluator demo: every LP-0021 wallet flow, non-interactive, one
# pass/fail line per step and a summary. Run it unmodified from a clean clone.
#
#   e2e/demo.sh --local                 build + start a LEZ 0.3 sequencer from the
#                                       pinned source (standalone, dev proofs);
#                                       no dependency on our hosted services
#   e2e/demo.sh --local --real-proofs   same, the wallet makes real RISC Zero
#                                       proofs (~5-8 min each; release build)
#   e2e/demo.sh --testnet               the official LEZ testnet 0.3 (real
#                                       proofs, the Logos Kit drip faucet,
#                                       explorer links; ~40 min, mostly proving;
#                                       log in docs/reviews/demo/)
#   e2e/demo.sh --preview               the legacy Logos Kit preview network
#                                       (LEZ 0.3-rc1, real proofs, drip faucet)
#
# Environment: DEMO_PORT (local sequencer port, default 3040), DEMO_KEEP=1
# (keep the wallet dir and sequencer), DEMO_SKIP_BUILD=1 (reuse binaries).
# Exit status: 0 = every step passed, 1 = a step failed, 2 = prerequisites.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="" REAL=0
for a in "$@"; do
  case "$a" in
    --local) MODE=local ;;
    --preview) MODE=preview ;;
    --testnet) MODE=testnet ;;
    --real-proofs) REAL=1 ;;
    -h|--help) sed -n '2,21p' "$0"; exit 0 ;;
    *) echo "unknown argument: $a (see --help)" >&2; exit 2 ;;
  esac
done
[[ -n "$MODE" ]] || { sed -n '2,21p' "$0"; exit 2; }
[[ "$MODE" == preview || "$MODE" == testnet ]] && REAL=1   # public networks verify real proofs
if [[ "$MODE" == testnet ]]; then
  # Keep the run: the evaluator log (SR5) lives next to the code.
  mkdir -p "$ROOT/docs/reviews/demo"
  LOG="$ROOT/docs/reviews/demo/testnet-$(date -u +%Y%m%dT%H%MZ).log"
  exec > >(tee "$LOG") 2>&1
fi

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
say() { printf '  %s\n' "$*"; }

# -- 1. platform and prerequisites -------------------------------------------
bold "Logos Kit demo ($MODE, $([[ $REAL == 1 ]] && echo 'real proofs' || echo 'dev proofs'))"
os="$(uname -s)" arch="$(uname -m)"
case "$os/$arch" in
  Darwin/arm64|Linux/x86_64|Linux/aarch64) say "platform $os/$arch: supported" ;;
  *) say "platform $os/$arch: not tested (supported: macOS arm64, Linux x86_64/aarch64); continuing" ;;
esac

missing=()
need() { command -v "$1" >/dev/null 2>&1 || missing+=("$1|$2"); }
need git "install git from your package manager"
need curl "install curl from your package manager"
need python3 "install Python 3 (python3) from your package manager"
need cargo "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh   # rust-toolchain.toml then pins 1.98.1"
if [[ "$os" == Linux ]]; then
  need clang "sudo apt-get install -y clang libclang-dev cmake ninja-build pkg-config libssl-dev unzip"
  need cmake "sudo apt-get install -y cmake"
  need unzip "sudo apt-get install -y unzip"
elif [[ "$os" == Darwin ]]; then
  xcrun --find clang >/dev/null 2>&1 || missing+=("xcode-clt|xcode-select --install")
fi
export PATH="$HOME/.risc0/bin:$PATH"
# rzup keeps r0vm in ~/.risc0/extensions/v3.0.5-*/ and links it into ~/.cargo/bin.
r0vm_ok() { ls "$HOME"/.risc0/extensions/v3.0.5-*/r0vm >/dev/null 2>&1 || r0vm --version 2>/dev/null | grep -q '3\.0\.5'; }
for d in "$HOME"/.risc0/extensions/v3.0.5-*/; do [[ -x "$d/r0vm" ]] && PATH="$d:$PATH"; done
if [[ "$MODE" == local ]] && ! r0vm_ok; then
  missing+=("r0vm 3.0.5|curl -L https://risczero.com/install | bash && ~/.risc0/bin/rzup install r0vm 3.0.5")
fi
if (( ${#missing[@]} )); then
  bold "Missing prerequisites:"
  for m in "${missing[@]}"; do say "${m%%|*}:  ${m#*|}"; done
  exit 2
fi
say "prerequisites: ok"

# -- 2. build ------------------------------------------------------------------
[[ -d "$ROOT/vendor/lez/.git" ]] || "$ROOT/scripts/lez-vendor.sh" || exit 2
PROFILE=debug
if [[ $REAL == 1 ]]; then PROFILE=release; unset RISC0_DEV_MODE; else export RISC0_DEV_MODE=1; fi
if [[ "${DEMO_SKIP_BUILD:-}" != 1 ]]; then
  say "building logos-kit CLI ($PROFILE; first build takes a while)"
  (cd "$ROOT" && cargo build -q -p logos-kit-cli $([[ $PROFILE == release ]] && echo --release)) || { echo "build failed" >&2; exit 2; }
fi
BIN="$ROOT/target/$PROFILE/logos-kit"

export LOGOS_KIT_HOME="$(mktemp -d)" LOGOS_KIT_PASSWORD=demo-password SUPPRESS_VERBOSE_PRINTS=1
PORT="${DEMO_PORT:-3040}"
if [[ "$MODE" == local ]]; then
  URL="http://127.0.0.1:$PORT"
  ZONE=(--zone lez-demo --sequencer "$URL")
  export LK_E2E_PORT="$PORT" LK_E2E_STATE="$ROOT/target/demo-sequencer-$PORT"
  say "starting a local LEZ sequencer on $URL (standalone, pinned source)"
  "$ROOT/e2e/standalone.sh" >/dev/null || { echo "sequencer failed to start" >&2; exit 2; }
  # LEZ's debug genesis account: public test key, local chains only.
  export DEMO_GENESIS_KEY=7f273098f25b71e6c005a9519f2678da8d1c7f01f6a27778e2d9948abdf901fb
elif [[ "$MODE" == testnet ]]; then
  URL="https://testnet.lez.logos.co"
  ZONE=(--zone lez-testnet)
  EXPLORER="https://explorer.testnet.lez.logos.co"
else
  URL="https://lez.84.46.247.92.sslip.io"
  ZONE=(--zone lez-preview)
fi
EXPLORER="${EXPLORER:-}"
# Demo posts count under their own submission id, never the real one.
SUBMISSION=(--submission LP-0021/logos-kit-demo)
cleanup() {
  if [[ "${DEMO_KEEP:-}" == 1 ]]; then say "kept wallet at $LOGOS_KIT_HOME"; return; fi
  rm -rf "$LOGOS_KIT_HOME"
  [[ "$MODE" == local ]] && "$ROOT/e2e/standalone.sh" stop
}
trap cleanup EXIT

LK() { "$BIN" "${ZONE[@]}" "$@"; }
# A public network can drop out for a while ("can't reach …", a refused
# connection, a DNS failure). Those happen before anything is delivered, so
# the step is retried once, after a pause; any other failure stands.
LKR() {
  local out rc
  out="$(LK "$@" 2>&1)"; rc=$?
  # "can't reach", a refused connection or a DNS failure: nothing was delivered.
  if [[ "$out" == *"can't reach"* || "$out" == *"client error (Connect)"* || "$out" == *"dns error"* ]]; then
    say "network unreachable; retrying in 60 s" >&2
    sleep 60
    out="$(LK "$@" 2>&1)"; rc=$?
  fi
  printf '%s\n' "$out"
  return $rc
}
last() { tail -1; }
get() { python3 -c "import sys,json; v=json.loads(sys.stdin.read().strip().splitlines()[-1]); print(eval('v'+sys.argv[1]))" "$1" 2>/dev/null; }

# -- 3. steps --------------------------------------------------------------------
RESULTS=() FAILED=0 T0=$SECONDS
pass() { RESULTS+=("PASS|$1|$2"); printf '  \033[32mPASS\033[0m  %-34s %s\n' "$1" "$2"; }
fail() { RESULTS+=("FAIL|$1|$2"); FAILED=$((FAILED + 1)); printf '  \033[31mFAIL\033[0m  %-34s %s\n' "$1" "$2"; }
# ok_outcome <label> <json>: the transaction settled with outcome success
# (with an explorer link on networks that have one).
ok_outcome() {
  local o b h link=""; o="$(echo "$2" | get "['outcome']")"; b="$(echo "$2" | get "['block']")"
  h="$(echo "$2" | get "['txHash']")"
  [[ -n "$EXPLORER" && -n "$h" ]] && link="  $EXPLORER/transaction/${h#0x}"
  if [[ "$o" == success ]]; then pass "$1" "block $b$link"; else fail "$1" "$(echo "$2" | tail -1 | cut -c1-160)"; fi
}
# Wait until <account> holds more than 0 (a drip can answer before its
# transfer lands; the testnet sometimes takes minutes to include it).
wait_funded() {
  local i bal
  for i in $(seq 1 72); do
    bal="$(LK balance "$1" --json 2>/dev/null | get "['balance']")"
    [[ -n "$bal" && "$bal" != 0 ]] && { echo "$bal"; return 0; }
    sleep 5
  done
  return 1
}
# refused <label> <expected text[|alternative…]> <cmd…>: the wallet must refuse.
refused() {
  local label="$1" want="$2" out w; shift 2
  if out="$("$@" 2>&1)"; then fail "$label" "was accepted"; return; fi
  IFS='|' read -ra alts <<<"$want"
  for w in "${alts[@]}"; do
    [[ "$out" == *"$w"* ]] && { pass "$label" "refused: $w"; return; }
  done
  fail "$label" "$(echo "$out" | tail -1 | cut -c1-160)"
}

bold "Flows"
LK init --json >/dev/null 2>&1 && pass "init wallet" "$LOGOS_KIT_HOME" || { fail "init wallet" "logos-kit init failed"; exit 1; }
A=$(LK account new --json | get "['accountId']")
B=$(LK account new --json | get "['accountId']")
P=$(LK account new --private --json | get "['accountId']")
P2=$(LK account new --private --json | get "['accountId']")
[[ -n "$A" && -n "$B" && -n "$P" && -n "$P2" ]] && pass "accounts (2 public, 2 private)" "A=${A:0:8}… B=${B:0:8}… P=${P:0:8}… P2=${P2:0:8}…" || fail "accounts" "account new failed"

if [[ "$MODE" == local ]]; then
  F=$(LK faucet "$A" --key-env DEMO_GENESIS_KEY --drop 2000000000 --yes --json 2>&1 | last)
else
  F=$(LK faucet "$A" --yes --json 2>&1 | last)
fi
FS="$(echo "$F" | get "['status']")"
if [[ "$FS" == funded ]]; then pass "faucet -> A" "+$(echo "$F" | get "['amount']") lepta"
elif [[ "$FS" == outcome_unknown ]] && BAL=$(wait_funded "$A"); then pass "faucet -> A" "balance $BAL lepta (landed after the drip answered)"
else fail "faucet -> A" "$(echo "$F" | cut -c1-160)"; bold "Cannot continue without funds."; exit 1; fi
# A public network has several sequencers; the one the wallet reads can lag
# the one that included the drop. Spend only once A's balance shows it.
if [[ "$MODE" != local ]] && ! wait_funded "$A" >/dev/null; then
  fail "faucet -> A visible" "the drop never showed in A's balance"; exit 1
fi

ok_outcome "public send A -> B" "$(LKR send --from "$A" --to "$B" --amount 1000 --yes --json 2>&1 | last)"
ok_outcome "shield A -> private P" "$(LKR send --from "$A" --to "$P" --amount 5000 --yes --json 2>&1 | last)"
ok_outcome "private send P -> public B" "$(LKR send --from "$P" --to "$B" --amount 100 --yes --json 2>&1 | last)"
ok_outcome "private send P -> private P2" "$(LKR send --from "$P" --to "$P2" --amount 100 --yes --json 2>&1 | last)"

T=$(LKR token create --name DEMO --supply 1000000 --holder "$A" --yes --json 2>&1 | last)
DEF=$(echo "$T" | get "['definition']")
[[ -n "$DEF" ]] && pass "token create (holder A)" "definition ${DEF:0:8}…" || fail "token create" "$(echo "$T" | cut -c1-160)"
if [[ -n "$DEF" ]]; then
  ok_outcome "token send A -> B (public)" "$(LKR send --from "$A" --to "$B" --amount 250 --token "$DEF" --yes --json 2>&1 | last)"
  ok_outcome "token send A -> P (private)" "$(LKR send --from "$A" --to "$P" --amount 10 --token "$DEF" --yes --json 2>&1 | last)"
  ok_outcome "token send P -> B (from private)" "$(LKR send --from "$P" --to "$B" --amount 4 --token "$DEF" --yes --json 2>&1 | last)"
fi

PROGRAM_ARGS=()
if [[ "$MODE" == local ]]; then
  D=$(LK testimonial deploy --payer "$A" --yes --json 2>&1 | last)
  PROG=$(echo "$D" | get "['account']")
  if [[ -n "$PROG" ]]; then pass "testimonial program deploy" "immutable ${PROG:0:8}…"; PROGRAM_ARGS=(--program "$PROG")
  else fail "testimonial program deploy" "$(echo "$D" | cut -c1-160)"; fi
fi
ok_outcome "testimonial post (A)" "$(LKR testimonial post ${PROGRAM_ARGS[@]+"${PROGRAM_ARGS[@]}"} "${SUBMISSION[@]}" --from "$A" --username demo \
  --text "Logos Kit demo: every wallet flow end to end." --yes --json 2>&1 | last)"

SNAP="$LOGOS_KIT_HOME/snapshots"
EV=$(LKR testimonial evidence ${PROGRAM_ARGS[@]+"${PROGRAM_ARGS[@]}"} "${SUBMISSION[@]}" --snapshot "$SNAP" --json 2>&1 | last)
N=$(echo "$EV" | get "['distinctAuthors']")
[[ -n "$N" && "$N" -ge 1 ]] && pass "evidence export" "$N distinct author(s); snapshot $(ls "$SNAP" 2>/dev/null | head -1)" || fail "evidence export" "$(echo "$EV" | cut -c1-160)"

bold "Refusals"
refused "second post by the same account" "already posted" \
  LKR testimonial post ${PROGRAM_ARGS[@]+"${PROGRAM_ARGS[@]}"} "${SUBMISSION[@]}" --from "$A" --text "again with Logos Kit" --yes --json
refused "post from a private account" "must be public" \
  LK testimonial post ${PROGRAM_ARGS[@]+"${PROGRAM_ARGS[@]}"} "${SUBMISSION[@]}" --from "$P" --text "hidden Logos Kit" --yes --json
refused "send more than the balance" "Can not pay|not enough|Not enough" \
  LK send --from "$B" --to "$A" --amount 999999999999999 --yes --json
if [[ "$MODE" == local ]]; then
  # A stale approval: another wallet moves the nonce after approval (engine test).
  if (cd "$ROOT" && RISC0_DEV_MODE=1 LK_E2E_SEQUENCER="$URL" cargo test -q -p wallet-engine --test authz \
      e2e_status_is_private_and_stale_approvals_are_refused >/dev/null 2>&1); then
    pass "stale approval refused (6106)" "engine authz E2E"
  else fail "stale approval refused (6106)" "cargo test --test authz failed"; fi
fi

# -- 4. summary --------------------------------------------------------------------
bold "Summary"
say "$(( ${#RESULTS[@]} - FAILED ))/${#RESULTS[@]} steps passed in $(( SECONDS - T0 ))s against $URL"
if (( FAILED )); then
  for r in "${RESULTS[@]}"; do [[ "$r" == FAIL* ]] && say "failed: $(echo "$r" | cut -d'|' -f2)"; done
  exit 1
fi
bold "DEMO OK"
