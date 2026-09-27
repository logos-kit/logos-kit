#!/usr/bin/env bash
# S7 integration flow in a real Basecamp (tests/intent-flow.mjs): installs the
# three modules into an isolated user dir, starts the standalone sequencer and
# the inspector build of Basecamp, then drives connect → send → status.
#
#   e2e/basecamp.sh            (expects modules/*/result-portable built: `just lgx <module>`)
# Tools: ~/.local/share/logos-tools/{lgpm-aarch64-macos,basecamp-inspector,logos-qt-mcp} (docs/dev/pins.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${LOGOS_TOOLS:-$HOME/.local/share/logos-tools}"
DIR="${LK_BC_DIR:-/tmp/lk-bc}"
pkill -9 -f 'logos_host|LogosBasecamp|ui-host' 2>/dev/null || true
rm -rf "$DIR"; mkdir -p "$DIR"
for m in logos_kit_wallet logos_kit_wallet_ui probe_dapp; do
  "$TOOLS/lgpm-aarch64-macos/bin/lgpm" --modules-dir "$DIR/modules" --ui-plugins-dir "$DIR/plugins" \
    --allow-unsigned install --file "$ROOT"/modules/$m/result-portable/*.lgx >/dev/null
done
"$ROOT/e2e/standalone.sh"
export RISC0_DEV_MODE=1
"$TOOLS/basecamp-inspector/bin/LogosBasecamp" --user-dir "$DIR" > "$DIR/basecamp.log" 2>&1 &
BC=$!
[[ "${LK_KEEP:-}" == 1 ]] || trap 'kill $BC 2>/dev/null; pkill -9 -f "logos_host|ui-host" 2>/dev/null; "$ROOT/e2e/standalone.sh" stop' EXIT
for _ in $(seq 1 120); do nc -z 127.0.0.1 3768 2>/dev/null && break; sleep 2; done
sleep 5
node "$ROOT/tests/intent-flow.mjs" --shots "$ROOT/docs/reviews/s7/basecamp"
