# Testimonial program

The LEZ program behind Logos Kit Testimonials (λPrize LP-0021). It stores one
on-chain testimonial per account and per submission, with an optional public
name and a timestamp, and counts distinct authors per month.

| Network | Account | Image id | Status |
|---|---|---|---|
| `lez:testnet` (official) | `5YoH3xjhgeKt2mcJXW7c31bqDNCWWA4CRJxVdvzFvVef` | `61b2243645ead75c1aec2987bb3aac816e3a4def4c33d38640b55a0457e111a9` | Immutable, `verified_local`. Posts count for LP-0021 |
| `lez:preview` (legacy) | `4vjENywUCfC3h85mjNGFPV7R9DqvUjV2xhMkCZbJR8XK` | `8308e67d1f7d520f776736955514e3ddbae0aa6d8ce646e69a33da812f74337e` | Built for LEZ `v0.3.0-rc1`; posts don't count |

Both entries, with their source, are in
[`registry/programs.json`](../../registry/programs.json); the SDK lists them as
`TESTIMONIAL_PROGRAMS`.

## Rules

- `Post { submission, page, username?, text, timestamp_ms }`. The submission
  id is 1–32 printable ASCII characters (`LP-0021/logos-kit` for Logos Kit),
  the text 1–280 bytes, the name at most 32 bytes.
- One record per `(submission, author)`: an account posts once.
- The author must sign, and the post must be the transaction's top-level call.
  A signer's authorization reaches every program in a chained call, so another
  program could otherwise post in the user's name.
- The timestamp is the poster's claim, bound to the block's time by the
  transaction's validity window (at most 2 minutes early, 10 minutes late).
- Authors are listed on stats pages of 1,000, in posting order, with monthly
  tallies; page `p` opens once page `p − 1` is full.
- The wallet posts only from public accounts: a private author would publish
  its private account id in the record.

Layout and limits: [`core/src/lib.rs`](core/src/lib.rs). Guest:
[`methods/guest/src/lib.rs`](methods/guest/src/lib.rs).

## Reproducible build

The program is a RISC Zero guest built in the pinned docker builder
(`r0.1.91.1`). [`artifacts/build.json`](artifacts/build.json) records the
commit it was built from and its image id; `artifacts/testimonial.bin` is the
binary that was deployed.

```sh
logos-kit testimonial build                    # or: just build-testimonial; needs docker
logos-kit --zone lez-testnet verify-program 5YoH3xjhgeKt2mcJXW7c31bqDNCWWA4CRJxVdvzFvVef
```

`verify-program` rebuilds the source the registry names and compares it with
the deployed program. CI does the same: `guest-repro.yml` rebuilds the
recorded commit on every change to `programs/` and once a week, and reports
whether the current source still builds the same image (a change means a
redeploy).

## Deploy

```sh
logos-kit testimonial deploy --payer <public account>   # immutable; prints the registry entry
```

`--upgradeable` keeps an upgrade key, for staging only: the wallet trusts an
upgradeable copy only if the registry names it. Add the printed entry to
`registry/programs.json` and to `TESTIMONIAL_PROGRAMS` in
`packages/codec/src/programs.ts`.
