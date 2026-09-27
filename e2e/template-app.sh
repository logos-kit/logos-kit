#!/usr/bin/env bash
# S8: the dApp template (templates/basecamp-dapp) end to end in the two-window
# dev harness on the standalone sequencer. Screenshots: docs/reviews/s8/template/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export RISC0_DEV_MODE=1
(cd "$ROOT" && cargo build -q --release -p wallet-engine)
cd "$ROOT"
uv run -q --python .qt/q692/bin/python modules/logos_kit_wallet_ui/dev/app_harness.py \
  --app my_lez_dapp --qml templates/basecamp-dapp/qml/Main.qml --prop chain=lez:local \
  --width 480 --height 760 --script e2e/qa_template.py \
  --shots docs/reviews/s8/template 2>&1 | grep -v "usedbeforedeclared"
