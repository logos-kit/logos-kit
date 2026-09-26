<!-- DRAFT: upstream proposal. Needs maintainer approval before posting. -->

# Proposal: a compact private-actions feed for light wallets

## Problem
To learn private balances, a wallet scans blocks with `getBlockRange`. Every privacy-preserving transaction carries a ~225 KB proof the scanner doesn't need. It only needs about 12 KB of notes, nullifiers and commitments. That makes web and mobile sync bandwidth-bound.

## Proposal
An RPC on the indexer or sequencer, e.g.

```
getPrivateActionsRange(start, end) → [{ block, txHash, nullifiers[], commitments[], notes: [{ epk, ciphertext, viewTag }] }]
```

It would carry no proofs, and ideally would also offer nullifier-existence and block-height-by-timestamp queries.

## Prior art
- lightwalletd `CompactBlock` (Zcash)
- Penumbra `CompactBlockRange`

## Benefit
About 95% less sync bandwidth for every LEZ wallet, not just ours.
