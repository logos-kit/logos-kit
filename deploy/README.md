# Hosted services

The services Logos Kit runs for its networks. Each folder is a Docker Compose
project that Coolify deploys; Traefik in front of it routes the hostnames,
issues TLS certificates (Let's Encrypt) and adds CORS headers and rate limits.
Secrets come from Coolify's environment and never sit in this repository.

Nothing here is needed to use the wallet: Basecamp and the CLI talk to the
official sequencer directly, and the faucet is only called when someone asks
for test funds. Which network uses what: [Networks](https://logos-kit-docs.vercel.app/docs/concepts/networks).

## `testnet/`: for the official LEZ testnet

The official testnet's sequencer, `https://testnet.lez.logos.co` (LEZ
`v0.3.0`), is run by Logos. Logos Kit adds two services next to it.

| Service | Host | What it does |
|---|---|---|
| `drip` | `https://lez-testnet-drip.84.46.247.92.sslip.io` | The testnet faucet: [`logos-kit-drip`](../crates/logos-kit-drip), `POST /fund`. 1 LGO per request; each account once an hour, each IP five times an hour, 60 requests an hour in all. Pays from a treasury key (`LK_DRIP_KEY`) funded from the testnet's public genesis accounts |
| `rpc` | `https://lez-testnet.84.46.247.92.sslip.io` | A CORS relay: Caddy reverse-proxies the official RPC so web pages can read it (the official RPC sends no CORS headers). Rate-limited to 10 requests a second per client IP, bursts of 30 |

The wallet engine knows the drip's address as `TESTNET_FAUCET`
(`crates/wallet-engine/src/session.rs`). The relay is used only by web code
that chooses it, such as the docs site's live block height.

## `preview-net/`: Logos Kit's preview network (legacy)

Logos Kit's own LEZ 0.3 network, from before the official testnet moved to
0.3. Wallets that saved it still list it, and it serves as a rehearsal
network. Posts to its testimonial program don't count for LP-0021.

| Service | Host | What it does |
|---|---|---|
| `sequencer` | `https://lez.84.46.247.92.sslip.io` | A LEZ `v0.3.0-rc1` sequencer in standalone mode that verifies real proofs. The block signing key (`LK_SEQ_SIGNING_KEY`) goes to tmpfs at start and is deleted once read (`entrypoint.sh`); `sequencer_config.json` holds the genesis |
| `drip` | `https://lez-drip.84.46.247.92.sslip.io` | The same faucet with the preview's limits (1 LGO per request; each account once an hour, each IP five times an hour, 200 requests an hour in all) |

The binaries (`sequencer_service`, `r0vm` 3.0.5 and `logos-kit-drip`) come
from the repository's `preview-net-v0.1.0` GitHub release, and each
Dockerfile checks their SHA-256 before use.

## Run your own faucet

```sh
scripts/lez-vendor.sh                       # once: the pinned LEZ source into vendor/lez
cargo build --release -p logos-kit-drip
LK_DRIP_KEY=<funded key, hex> LK_DRIP_SEQUENCER=<sequencer url> target/release/logos-kit-drip
```

Every setting (`LK_DRIP_AMOUNT`, `LK_DRIP_EVERY_SECS`, `LK_DRIP_IP_PER_HOUR`,
`LK_DRIP_MAX_PER_HOUR`, `LK_DRIP_DATA`, `LK_DRIP_LISTEN`,
`LK_DRIP_TRUST_PROXY`) is described at the top of
[`crates/logos-kit-drip/src/main.rs`](../crates/logos-kit-drip/src/main.rs).
Point the CLI at it with `logos-kit faucet <account> --url <drip url>`.

The hosts are `sslip.io` names on one server, which had a multi-minute DNS
outage once. A real domain may be added later as an extra name; a zone's
sequencer URL never changes, because wallets refuse a saved zone whose address
changed.
