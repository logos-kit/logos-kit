#!/usr/bin/env bash
# Conformance in a real Basecamp: the dApp next to the FAKE wallet (core
# `logos_kit_wallet` on the fake engine + provider `logos_kit_wallet_fake`) in
# an isolated profile. Checks what the headless runner can't: the dApp loads
# in the sandbox, its calls reach the wallet with its attested identity, and a
# connect goes through the shell's chooser to the provider and back.
#
#   e2e/conformance-basecamp.sh <dapp dir> [scenario] [connect-button objectName]
#
# Needs the inspector build of Basecamp and lgpm (~/.local/share/logos-tools),
# like e2e/basecamp.sh. Refuses to run while another Basecamp is open.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DAPP="$(cd "${1:?usage: $0 <dapp dir> [scenario] [connect objectName]}" && pwd)"
SCENARIO="${2:-happy}"
CONNECT="${3:-connect}"
TOOLS="${LOGOS_TOOLS:-$HOME/.local/share/logos-tools}"
export PATH="/nix/var/nix/profiles/default/bin:$PATH"
APP=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['name'])" "$DAPP/metadata.json")
TITLE=$(python3 -c "import json,sys; m=json.load(open(sys.argv[1])); print(m.get('display_name') or m['name'])" "$DAPP/metadata.json")
OUT="$ROOT/target/conformance/$APP/basecamp"
DIR="${LK_CONF_DIR:-/tmp/lk-conformance-$APP}"
mkdir -p "$OUT"

if pgrep -f 'LogosBasecamp' >/dev/null; then
  echo "another Basecamp is running; close it first (this script never kills it)" >&2
  exit 2
fi

echo "• build: fake core, fake provider, $APP"
FAKE="$ROOT/modules/logos_kit_wallet_fake"
(cd "$FAKE/core" && nix build .#lgx-portable -o result-portable)
(cd "$FAKE/ui" && nix build .#lgx-portable -o result-portable)
(cd "$DAPP" && nix build .#lgx-portable -o "$OUT/dapp-lgx")

echo "• install into $DIR"
rm -rf "$DIR"; mkdir -p "$DIR"
for f in "$FAKE"/core/result-portable/*.lgx "$FAKE"/ui/result-portable/*.lgx "$OUT"/dapp-lgx/*.lgx; do
  "$TOOLS/lgpm-aarch64-macos/bin/lgpm" --modules-dir "$DIR/modules" --ui-plugins-dir "$DIR/plugins" \
    --allow-unsigned install --file "$f" >/dev/null
done

echo "• Basecamp (scenario $SCENARIO)"
LOGOS_KIT_FAKE_SCENARIO="$SCENARIO" "$TOOLS/basecamp-inspector/bin/LogosBasecamp" --user-dir "$DIR" > "$DIR/basecamp.log" 2>&1 &
BC=$!
trap 'kill $BC 2>/dev/null || true; sleep 1; pkill -9 -f "logos_host.*$DIR|ui-host.*$DIR" 2>/dev/null || true' EXIT
for _ in $(seq 1 90); do nc -z 127.0.0.1 3768 2>/dev/null && break; sleep 2; done
sleep 5
TITLE="$TITLE" APP="$APP" CONNECT="$CONNECT" DIR="$DIR" \
  node "$ROOT/tests/conformance-basecamp.mjs" --shots "$OUT"
