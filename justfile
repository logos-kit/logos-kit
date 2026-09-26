# Logos Kit task runner. `just --list` to see everything.
# Nix lives in the default profile on this machine; make sure it is on PATH.
export PATH := "/nix/var/nix/profiles/default/bin:" + env_var('PATH')

default:
    @just --list

# JS/TS: format + lint (Biome), monorepo hygiene (sherif)
check:
    pnpm check
    pnpm check:repo

# Rust: fmt + clippy
check-rust:
    cargo fmt --check
    cargo clippy --workspace --all-targets -- -D warnings

# Identify the LEZ protocol version a sequencer runs (default: public testnet)
fingerprint url="https://testnet.lez.logos.co":
    cargo xtask fingerprint {{url}}

# Build one Basecamp module's portable .lgx (e.g. `just lgx logos_kit_wallet`)
lgx module:
    cd modules/{{module}} && nix build .#lgx-portable -L -o result-portable

# Build a module's dev .lgx (for local Basecamp installs)
lgx-dev module:
    cd modules/{{module}} && nix build .#lgx -L -o result-dev

# Build every Basecamp module
build-modules:
    for m in logos_kit_wallet logos_kit_wallet_ui; do just lgx $m; done

# Hard-reset local Basecamp module installs (logos-module-build-loop procedure; `;` not `&&`)
basecamp-reset userdir="/tmp/lk-bc":
    -pkill -9 -f 'logos_host|logos-basecamp|LogosBasecamp|\.logos_host\.elf'; rm -rf {{userdir}}/modules/logos_kit_* {{userdir}}/plugins/logos_kit_* {{userdir}}/modules/probe_dapp {{userdir}}/plugins/probe_dapp

# E2E against a local LEZ 0.3 sequencer (standalone, dev proofs). Starts it, runs the E2E tests, stops it.
e2e:
    e2e/standalone.sh
    LK_E2E_SEQUENCER=http://127.0.0.1:3040 cargo test -p wallet-engine --test e2e_sync -- --nocapture; status=$?; e2e/standalone.sh stop; exit $status

# S3 exit proof: public send + shield through the CLI on the standalone sequencer.
e2e-cli:
    e2e/standalone.sh
    e2e/cli.sh; status=$?; e2e/standalone.sh stop; exit $status
