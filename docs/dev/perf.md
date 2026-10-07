# Performance budgets, measured

The budgets in `docs/dev/PLAN.md` ("Budgets"), measured on the real wallet. Machine: Apple M1 Pro, 10 cores, 16 GB, macOS, unless a row says otherwise. Re-measure with the commands in the last column.

| Budget | Target | Measured | Date | How |
|---|---|---|---|---|
| Basecamp first launch to the wallet open | none we control | **16–40 s** in the Basecamp GUI (once over 2 min on a flaky connection). The gap sits in Basecamp's dependency step (`package_downloader`), before our module loads | 2026-09-30 | `e2e/catalog-install-gui.sh`, Basecamp log |
| Our module load | — | **1.1 s** (`logosctl module load logos_kit_wallet` on a fresh catalog install); engine library load + init ~0.01 s warm, 1.9 s the first time macOS scans the new binary | 2026-09-30 | `e2e/catalog-install.sh` |
| Wallet UI: the core's status read (`ui_state`, polled every 2.5 s) | — | **< 0.1 ms** (p50 0.0, max 0.1 over 30 calls) | 2026-10-06 | `qa_perf.py` |
| Create a wallet (Argon2id + vaults) | — | **226 ms** | 2026-10-06 | `qa_perf.py` |
| Approval sheet paint | < 100 ms | **met**: Review tap to the sheet on screen 265 ms in the harness, of which 250 ms is the harness's fixed pause after a click and up to 100 ms its polling step, so the sheet appears within ~15–115 ms; the engine builds and decodes the transaction in 4 ms on a local network (it reads the chain, so add the network's round trips on the testnet) | 2026-10-06 | `QA_ZONE=lez-local qa_perf.py` |
| Account switch | — | **3 ms** (p50 of 6, store to header text) | 2026-10-06 | `qa_perf.py` |
| Sync catch-up, new wallet | — | **105 ms** on a local network. On the testnet: a new wallet starts its incoming scan at the tip, so first sync is one balance read per account; a restored wallet reads 1,000 blocks per sync (about 27 MB and 30 s for the whole testnet chain, the measurement behind docs/dev/PLAN-LP0001.md §3) | 2026-10-06 | `qa_perf.py` |
| Proving, shield (public → private) | shown up front | **481 s** wall, 3.3 GB peak resident, 9.9 GB peak footprint (counting compressed and swapped pages); earlier quiet-machine runs 267–337 s, 4.3 GB | 2026-10-06 | `/usr/bin/time -l logos-kit send … (shield)`, real proof, local sequencer |
| Proving, private send | shown up front | **469 s**, 4.26 GB resident, 9.92 GB footprint | 2026-09-26 | `docs/dev/pins.md` E2 |
| Proving, low-memory mode (segments of 2^18 cycles, LEZ patch 0008) | about half the memory | shield: **439 s** wall, 3.0 GB resident, **5.5 GB footprint** (from 9.9), 41% more CPU time; fully private (benchmark): 757 s, 2.26 GB resident, 5.09 GB footprint, ~1.6× the time on a quiet machine | 2026-10-06 | `logos-kit --low-memory send …`; `pins.md` E4 |
| Web modal time to interactive | — | not applicable yet: the web and React Native kits come after the Basecamp product | — | — |

**The figure the wallet shows** for a private transaction is "about 5–8 minutes" (`PROOF_TIME` in `crates/wallet-engine/src/service.rs`), used by the approval sheet, the faucet app, the README and the docs.

**Free memory before a proof** (`crates/wallet-engine/src/proving.rs`): below 4.6 GB free (3.0 GB in low-memory mode) the approval sheet warns and suggests low-memory proving; below 2.5 GB (1.5 GB) the wallet refuses and nothing is sent. macOS compresses and swaps, so a proof can finish with less free memory than its footprint, only slower; the floor is where it would very likely be killed instead.

## Commands

```sh
# UI and engine timings against a local sequencer
e2e/standalone.sh
QA_ZONE=lez-local HOME=$(mktemp -d) QT_QPA_PLATFORM=offscreen \
  uv run --python .qt/q692/bin/python modules/logos_kit_wallet_ui/dev/harness.py \
  --script modules/logos_kit_wallet_ui/dev/qa_perf.py
e2e/standalone.sh stop

# One real proof, default and low-memory (release CLI, local sequencer)
/usr/bin/time -l target/release/logos-kit send --from <public> --to <private> --amount 5000 --yes --json
/usr/bin/time -l target/release/logos-kit --low-memory send --from <public> --to <private> --amount 5000 --yes --json
```
