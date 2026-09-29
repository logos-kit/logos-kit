#!/usr/bin/env bash
# The block signing key arrives as hex in LK_SEQ_SIGNING_KEY and never lands in
# the image or the config. It is written to tmpfs (/dev/shm, 0600) for the
# sequencer, which reads it once at startup (main.rs: `--signing-key` is loaded
# into the config before the node starts), then deleted.
# Accepted for the preview network: the key also stays in the container's
# environment (Coolify injects it), readable by whoever can `docker inspect` the
# box; that is the same person who holds the Coolify secret.
set -euo pipefail
[[ "${LK_SEQ_SIGNING_KEY:-}" =~ ^[0-9a-f]{64}$ ]] || { echo "LK_SEQ_SIGNING_KEY: 64 hex chars required" >&2; exit 1; }
umask 077
key="$(mktemp -p /dev/shm lk-seq-key.XXXXXX)"
printf '%b' "$(printf '%s' "$LK_SEQ_SIGNING_KEY" | sed 's/../\\x&/g')" > "$key"
unset LK_SEQ_SIGNING_KEY
# Gone once the sequencer has read it (it runs as this script's replacement).
( sleep 20; rm -f "$key" ) &
exec sequencer_service /etc/sequencer_service/sequencer_config.json \
  --home /var/lib/sequencer_service --listen-address 0.0.0.0 --port 3040 --signing-key "$key"
