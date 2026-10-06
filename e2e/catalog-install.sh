#!/usr/bin/env bash
# Clean-machine install from the published catalog, the way a user's machine
# sees it: a stock logosctl, an empty session, our catalog URL and nothing else.
#
#   e2e/catalog-install.sh             # native (macOS arm64 or Linux)
#   e2e/catalog-install.sh --docker    # inside a fresh ubuntu:24.04 container
#   EXPECT_VERSION=0.3.0 e2e/catalog-install.sh   # also require that version
#
# Checks: the catalog resolves; installing the wallet UI pulls in the core;
# the testimonial and faucet apps install;
# both packages carry the release DID's signature; the core loads from its
# portable bundle (plugin + libwallet_engine) and answers.
set -euo pipefail

CATALOG_URL="${CATALOG_URL:-https://raw.githubusercontent.com/logos-kit/logos-kit-modules/refs/heads/main/logos-repo.json}"
RELEASE_DID="${RELEASE_DID:-did:jwk:eyJjcnYiOiJFZDI1NTE5Iiwia3R5IjoiT0tQIiwieCI6IkVGM0Vyb1kwUGN4OXpvTXpPT0w0YnhQNHI1Tk03UXc1X0x1aHl4TV9ZNVkifQ}"
LOGOSCTL_VERSION="${LOGOSCTL_VERSION:-0.3.0}"
EXPECT_VERSION="${EXPECT_VERSION:-}"

if [[ "${1:-}" == "--docker" ]]; then
  exec docker run --rm -i \
    -e CATALOG_URL="$CATALOG_URL" -e RELEASE_DID="$RELEASE_DID" -e LOGOSCTL_VERSION="$LOGOSCTL_VERSION" -e EXPECT_VERSION="$EXPECT_VERSION" \
    ubuntu:24.04 bash -s < "$0"
fi

step() { printf '\n==> %s\n' "$*"; }

if [[ "$(uname)" == "Linux" ]] && ! command -v curl >/dev/null; then
  step "base packages (a stock Ubuntu has none of these)"
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl jq >/dev/null
fi

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) asset=logosctl-aarch64-macos ;;
  Linux-x86_64) asset=logosctl-x86_64-linux ;;
  Linux-aarch64) asset=logosctl-aarch64-linux ;;
  *) echo "unsupported platform $(uname -sm)" >&2; exit 1 ;;
esac

work="$(mktemp -d)"
ctl=true
trap 'cd /; "$ctl" daemon stop >/dev/null 2>&1 || true; rm -rf "$work"' EXIT
cd "$work"

step "logosctl $LOGOSCTL_VERSION ($asset)"
curl -fsSL --retry 3 --connect-timeout 20 --max-time 300 -o ctl.tgz "https://github.com/logos-co/logos-logoscore-cli/releases/download/$LOGOSCTL_VERSION/$asset.tar.gz"
tar xzf ctl.tgz
# macOS ships bin/logosctl; Linux ships an AppImage. Containers have no FUSE,
# so the AppImage runs by extracting itself.
ctl="$(find "$work" \( -name logosctl -o -name 'logosctl-*.AppImage' \) -type f -perm -u+x | head -1)"
[[ -n "$ctl" ]] || { echo "FAIL: no logosctl in $asset.tar.gz" >&2; exit 1; }
export APPIMAGE_EXTRACT_AND_RUN=1
export LOGOSCTL_CONFIG_DIR="$work/session"
"$ctl" --version

step "daemon"
"$ctl" daemon start --detach

step "catalog add $CATALOG_URL"
"$ctl" catalog add "$CATALOG_URL"
"$ctl" catalog refresh
"$ctl" search logos_kit

step "trust the Logos Kit release key, then install the UI (pulls the core)"
# The default policy is WARN (an untrusted signer still installs), so the
# check is that what landed is signed by the release DID, not a refusal.
"$ctl" key add logos-kit --did "$RELEASE_DID" --display-name "Logos Kit release key"
"$ctl" install logos_kit_wallet_ui -y
# The mini-apps install on their own and depend on the wallet core.
"$ctl" install logos_kit_testimonial -y
"$ctl" install logos_kit_faucet -y
"$ctl" package ls
for m in logos_kit_wallet logos_kit_wallet_ui logos_kit_testimonial logos_kit_faucet; do
  "$ctl" --json package show "$m" > "show-$m.json"
  grep -q "$RELEASE_DID" "show-$m.json" || { cat "show-$m.json"; echo "FAIL: $m is not signed by the release DID" >&2; exit 1; }
  got="$(jq -r '[.. | objects | .version? // empty | strings] | first // "?"' "show-$m.json")"
  if [[ -n "$EXPECT_VERSION" && "$got" != "$EXPECT_VERSION" ]]; then
    cat "show-$m.json"; echo "FAIL: $m installed $got, expected $EXPECT_VERSION" >&2; exit 1
  fi
  echo "$m $got: signed by the Logos Kit release key"
done

step "load the core and call it"
"$ctl" module load logos_kit_wallet
caps="$("$ctl" --json call logos_kit_wallet lez_getCapabilities '{}')"
echo "$caps"
grep -q '"value"' <<<"$caps" || { echo "FAIL: no {\"value\"} from lez_getCapabilities" >&2; exit 1; }

echo
echo "CATALOG INSTALL OK ($(uname -sm))"
