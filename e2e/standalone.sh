#!/usr/bin/env bash
# Start a local LEZ sequencer for E2E: standalone mode (mocked Bedrock), dev
# proofs (RISC0_DEV_MODE=1: the sequencer does not verify proofs), LEZ's debug
# genesis, a throwaway home, loopback only (the RPC has no auth).
#
#   e2e/standalone.sh            build if needed, start, wait until the RPC answers
#   e2e/standalone.sh stop       stop it
#
# Recipe mirrors LEZ's `just run-sequencer-standalone` and CI; the binary is
# built from vendor/lez (our pinned LEZ + patches) into target/lez-sequencer.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LEZ="$ROOT/vendor/lez"
TARGET="$ROOT/target/lez-sequencer"
BIN="$TARGET/release/sequencer_service"
STATE="${LK_E2E_STATE:-$ROOT/target/e2e-sequencer}"
PORT="${LK_E2E_PORT:-3040}"
URL="http://127.0.0.1:$PORT"

if [[ "${1:-}" == "stop" ]]; then
  [[ -f "$STATE/pid" ]] && kill "$(cat "$STATE/pid")" 2>/dev/null || true
  rm -f "$STATE/pid"
  exit 0
fi

# The sequencer runs guest programs through RISC Zero's r0vm, even in dev
# mode. Same install LEZ's base image uses (lez/docker/risc0-base.Dockerfile).
export PATH="$HOME/.risc0/bin:$PATH"
if ! command -v r0vm >/dev/null; then
  echo "r0vm missing: curl -L https://risczero.com/install | bash && rzup install r0vm 3.0.5" >&2
  exit 1
fi

[[ -d "$LEZ/.git" ]] || cargo xtask lez-vendor
if [[ ! -x "$BIN" ]]; then
  echo "building sequencer_service (standalone) from vendor/lez…"
  (cd "$LEZ" && CARGO_TARGET_DIR="$TARGET" cargo build --release --features standalone -p sequencer_service)
fi

rm -rf "$STATE"
mkdir -p "$STATE/home"
cd "$LEZ/lez/sequencer/service"
RISC0_DEV_MODE=1 RUST_LOG="${RUST_LOG:-info,kameo=warn}" nohup "$BIN" configs/debug/sequencer_config.json \
  --home "$STATE/home" --listen-address 127.0.0.1 --port "$PORT" >"$STATE/sequencer.log" 2>&1 &
echo $! >"$STATE/pid"

for _ in $(seq 1 120); do
  if curl -fsS -H 'content-type: application/json' \
      -d '{"jsonrpc":"2.0","id":1,"method":"getLastBlockId","params":[]}' "$URL" >/dev/null 2>&1; then
    echo "sequencer up at $URL (pid $(cat "$STATE/pid"), log $STATE/sequencer.log)"
    exit 0
  fi
  if ! kill -0 "$(cat "$STATE/pid")" 2>/dev/null; then
    echo "sequencer exited; last log lines:" >&2
    tail -20 "$STATE/sequencer.log" >&2
    exit 1
  fi
  sleep 1
done
echo "sequencer did not answer on $URL within 120 s" >&2
exit 1
