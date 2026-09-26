# Contributing

Thanks for helping build Logos Kit.

- Read `AGENTS.md` for the rules. They apply to humans too.
- One topic per PR; keep commits small.
- JS/TS: `pnpm check` (Biome) and `pnpm build` must pass. Add a changeset (`pnpm changeset`) for any user-facing package change.
- Rust: `cargo fmt`, `cargo clippy -- -D warnings`.
- Basecamp modules: build with `nix build .#lgx` in the module folder.
- Contributions are dual-licensed under MIT and Apache-2.0.
