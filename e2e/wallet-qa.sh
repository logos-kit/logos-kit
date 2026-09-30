#!/usr/bin/env bash
# The wallet UI QA walks (onboarding, wallet, private) in the dev harness on
# the local sequencer, each with a fresh data dir. Screenshots land in
# docs/reviews/s7/ (the wallet's screens). Needs `just qt-setup`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="$ROOT/.qt/q692/bin/python"
# The local sequencer runs with dev-mode proofs; the wallet must match.
export RISC0_DEV_MODE=1
H="$ROOT/modules/logos_kit_wallet_ui/dev"
for qa in ${LK_QA:-qa_onboarding qa_wallet qa_private}; do
  data="$(mktemp -d)"
  echo "== $qa"
  "$PY" "$H/harness.py" --data "$data" --script "$H/$qa.py" --shots "$ROOT/docs/reviews/s7" 2>&1 \
    | grep -E "^(SHOT|SCRIPT|OK|FAIL|Traceback|  File|[A-Za-z]*Error)|QML ERROR|TimeoutError" || true
  rm -rf "$data"
done
