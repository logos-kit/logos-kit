<!-- DRAFT: upstream proposal (LEZ issue + forum). Needs maintainer approval before posting. -->

# Proposal: signature-authorized private spends (separate spend authority from proving)

## Problem
Today a private spend is authorized by the spend secret `ask` **inside the proof witness** (`lee/state_machine/core/src/execution_state.rs:212-224`). Whoever generates the proof must therefore hold `ask`, and so gains spend authority.

As a result, private spends can't be proved by:
- a helper device;
- a user-owned server;
- a hardware wallet host.

Only the wallet process itself can prove them. That blocks good private-account UX on phones and in browsers.

## Prior art
Every privacy wallet we studied separates the two:
- **Zcash Sapling/Orchard.** The circuit proves a re-randomised `rk` derived from `ak`, and a spend-auth signature under `rk` is checked outside the circuit (Protocol Spec §4.15).
- **Aleo.** A signed Authorization; the prover gets a compute key only.
- **Namada** (Ledger signs, browser proves) and **Miden**.

## Sketch for LEZ
1. `npk` commits to a spend-auth public key `ak` (derived from `ask`).
2. The circuit outputs a re-randomised `rk`.
3. The sequencer verifies a signature under `rk` over the message hash, alongside the existing public-signer check (`validated_state_diff/mod.rs:385`).
4. A delegated prover receives `nsk` (linkage) but never `ask`, so it cannot spend.

This is a breaking key/circuit change: new account IDs and a new circuit ID. PR #669 (`ssk → ask → nsk`) is a natural precursor.

## Benefit
It enables non-custodial remote proving, hardware wallets and passkey-authorized private spends.
