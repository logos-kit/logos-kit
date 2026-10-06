#!/usr/bin/env bash
# The user's install path in a real Basecamp: an empty profile, our catalog
# URL added in Settings, the wallet installed from Applications
# (tests/catalog-install-gui.mjs). Nothing local is preinstalled.
#
#   e2e/catalog-install-gui.sh
# Tools: ~/.local/share/logos-tools/{basecamp-inspector,logos-qt-mcp} (docs/dev/pins.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${LOGOS_TOOLS:-$HOME/.local/share/logos-tools}"
DIR="${LK_BC_DIR:-/tmp/lk-bc-catalog}"
pkill -9 -f 'logos_host|LogosBasecamp|ui-host' 2>/dev/null || true
rm -rf "$DIR"; mkdir -p "$DIR"
"$TOOLS/basecamp-inspector/bin/LogosBasecamp" --user-dir "$DIR" > "$DIR/basecamp.log" 2>&1 &
BC=$!
[[ "${LK_KEEP:-}" == 1 ]] || trap 'kill $BC 2>/dev/null; pkill -9 -f "logos_host|ui-host" 2>/dev/null' EXIT
for _ in $(seq 1 120); do nc -z 127.0.0.1 3768 2>/dev/null && break; sleep 2; done
sleep 5
node "$ROOT/tests/catalog-install-gui.mjs" --shots "${LK_SHOTS:-$ROOT/docs/reviews/s7/catalog}"
