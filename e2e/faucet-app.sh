#!/usr/bin/env bash
# S8: the faucet app end to end against the standalone sequencer (local
# genesis-key faucet, 60 s per-account limit), in the two-window dev harness:
# public funded → rate-limited countdown → private funded via a shield the
# user approves in the wallet. Screenshots go to docs/reviews/s8/faucet/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export RISC0_DEV_MODE=1
(cd "$ROOT" && cargo build -q --release -p wallet-engine)
cd "$ROOT"
uv run -q --python .qt/q692/bin/python modules/logos_kit_wallet_ui/dev/app_harness.py \
  --app logos_kit_faucet --qml modules/logos_kit_faucet/qml/Main.qml \
  --script modules/logos_kit_faucet/dev/qa_faucet.py \
  --shots docs/reviews/s8/faucet 2>&1 | grep -v "usedbeforedeclared"
