#!/usr/bin/env bash
# The block signing key arrives as hex in LK_SEQ_SIGNING_KEY and never lands in
# the image or the config; the sequencer reads it from a 0600 file.
set -euo pipefail
[[ "${LK_SEQ_SIGNING_KEY:-}" =~ ^[0-9a-f]{64}$ ]] || { echo "LK_SEQ_SIGNING_KEY: 64 hex chars required" >&2; exit 1; }
umask 077
key="$(mktemp)"
printf '%b' "$(printf '%s' "$LK_SEQ_SIGNING_KEY" | sed 's/../\\x&/g')" > "$key"
unset LK_SEQ_SIGNING_KEY
exec sequencer_service /etc/sequencer_service/sequencer_config.json \
  --home /var/lib/sequencer_service --listen-address 0.0.0.0 --port 3040 --signing-key "$key"
