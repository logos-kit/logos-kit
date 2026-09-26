# Pins

Every pinned revision and version used by Logos Kit. Update this file whenever anything is re-pinned, and say why in `PROGRESS.md`.

Recorded 2026-09-26 (S0).

## Logos / LEZ upstream

| Component | Repo | Rev | Date | Notes |
|---|---|---|---|---|
| LEZ | `logos-blockchain/logos-execution-zone` | `f7fda38a4428b9989f1db1dbf5d2411484848fd4` | 2026-09-26 | `dev`, one merge after `v0.3.0-rc1`. **Re-pin to `v0.3.0` final when it is tagged** |
| Basecamp | `logos-co/logos-basecamp` | `2c2022762b397e5c5657a480bab9981466211e35` | 2026-09-22 | Tag `0.3.0`. Pinned because some public releases did not discover user modules. **Installed locally:** release asset `LogosBasecamp-Desktop-v0.3.0-bbe5da-aarch64.dmg` (sha256 `82ea4cbdf6b32a7a04610a422f1326347b994984d5a07ef474c4968d2edd6d53`) at `~/Applications/LogosBasecamp.app`. The QML Inspector needs a source dev build at the same rev |
| logos-module-builder | `logos-co/logos-module-builder` | `4b7998272c5ec014bcac4bf1c7dbe7602c63a3c1` | 2026-09-23 | `mkLogosModule` / `mkLogosQmlModule` |
| logos-rust-sdk | `logos-co/logos-rust-sdk` | `bcc36420d7a15fb39cbf8079c85a18650cdae968` | 2026-09-24 | `current_caller()`, codegen trait |
| logos-modules-release-base | `logos-co/logos-modules-release-base` | `33fb564d2069be388ef53724bd5b0a6d026b2250` | 2026-09-21 | Our catalog (`logos-kit-modules`) is a fork of this |
| logos-modules-release-action | `logos-co/logos-modules-release-action` | `bbdc52871dc4305c8007923e1b08738ad2dd6b50` | 2026-09-23 | Called as `@v1` |

## Proving and toolchain

| Item | Value | Source |
|---|---|---|
| Rust toolchain | `1.98.1` | LEZ `rust-toolchain.toml` |
| risc0-zkvm | `3.0.5` | LEZ `Cargo.lock` |
| RISC Zero guest docker builder | `r0.1.91.1` | LEZ `Justfile:27` (`RISC0_DOCKER_CONTAINER_TAG`) |
| Nix | `2.35.2` | `/nix/var/nix/profiles/default/bin/nix` (flakes enabled) |
| Qt (Basecamp desktop) | `6.9.2` | note 11 |
| Qt (mobile Basecamp, and the open desktop bump PR) | `6.11.1` | logos-nix #7/#8 |

## JavaScript (latest on 2026-09-26; pinned through pnpm `catalog:`)

| Package | Version |
|---|---|
| next | 16.3.x |
| react / react-dom | 19.3.x |
| react-native | 0.87.x |
| expo | 57.x |
| react-native-passkeys | 0.4.2 |
| fumadocs-core / fumadocs-ui | 16.15.x |
| fumadocs-mdx | 15.4.x |
| fumadocs-twoslash | 4.x |
| fumadocs-typescript | 5.x |
| tsdown | 0.23.x |
| @changesets/cli | 3.x |
| @biomejs/biome | 2.5.x |
| vitest | 5.x |
| zustand | 5.x |
| @tanstack/react-query | 5.104.x |
| @noble/curves, @noble/hashes | 2.4.x |
| @noble/post-quantum | 0.7.x |
| ox | 1.8.x |
| typebox | 1.3.x (the new package name; not `@sinclair/typebox`) |
| @wallet-standard/app | 1.1.x |
| tailwindcss | 4.3.x |

## Benchmarks (proving on this machine)

To be filled in S0 by note 08 §c experiments E1–E4 and the `RISC0_KECCAK_PO2` test.

| Experiment | Result | Date |
|---|---|---|
| E1 cycles/segments | — | — |
| E2 real proving time + peak RSS | — | — |
| E3 thread counts | — | — |
| E4 segment size vs RAM | — | — |
| `RISC0_KECCAK_PO2` memory | — | — |

Host: Apple M1 Pro, 16 GB.
