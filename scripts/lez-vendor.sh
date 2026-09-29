#!/usr/bin/env bash
# Materialise vendor/lez (LEZ at LEZ_REV + vendor/lez-patches/*.patch) without
# building anything: the shell twin of `cargo xtask lez-vendor`, for clean
# clones and CI (xtask itself depends on LEZ crates, so it can't bootstrap).
# Same fixed committer identity/date as crates/xtask/src/lez.rs, so both
# paths produce the same tree. Leaves an existing clean checkout at the pin.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REV="$(sed -n 's/^pub const LEZ_REV: &str = "\([0-9a-f]\{40\}\)";/\1/p' "$ROOT/crates/xtask/src/main.rs")"
[[ -n "$REV" ]] || { echo "LEZ_REV not found in crates/xtask/src/main.rs" >&2; exit 1; }
DEST="$ROOT/vendor/lez"
export GIT_COMMITTER_NAME=logos-kit GIT_COMMITTER_EMAIL=vendor@logos-kit.invalid GIT_COMMITTER_DATE=2026-01-01T00:00:00Z
g() { git -C "$DEST" "$@"; }
if [[ -d "$DEST/.git" ]]; then
  [[ -z "$(g status --porcelain)" ]] || { echo "vendor/lez has uncommitted changes; commit + cargo xtask lez-export, or remove it" >&2; exit 1; }
else
  mkdir -p "$DEST"; g init -q; g remote add origin https://github.com/logos-blockchain/logos-execution-zone
fi
g fetch -q --depth 1 origin "$REV"
g checkout -q --detach "$REV"
g reset -q --hard "$REV"
shopt -s nullglob
patches=("$ROOT"/vendor/lez-patches/*.patch)
if (( ${#patches[@]} )); then
  g -c user.name=logos-kit -c user.email=vendor@logos-kit.invalid am -q --committer-date-is-author-date "${patches[@]}"
fi
echo "vendor/lez = LEZ ${REV:0:12} + ${#patches[@]} patch(es)"
