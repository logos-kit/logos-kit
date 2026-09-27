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

# S7: the approval authorization path through the module's service (connect,
# app proposal, id dedupe, handle isolation, signature, shield, lock).
e2e-service:
    e2e/standalone.sh
    RISC0_DEV_MODE=1 LK_E2E_SEQUENCER=http://127.0.0.1:3040 cargo test -p wallet-engine --test e2e_service -- --nocapture; status=$?; e2e/standalone.sh stop; exit $status

# S7: the prize's core flow in a real Basecamp (dApp → connect → send → approve → status).
bc-flow:
    just lgx logos_kit_wallet
    just lgx logos_kit_wallet_ui
    just lgx probe_dapp
    e2e/basecamp.sh

# S7 exit: install from the published catalog with a stock logosctl (`--docker`: fresh Ubuntu).
catalog-install *args:
    e2e/catalog-install.sh {{args}}

# S7 exit: the user's install path in a real Basecamp with an empty profile.
catalog-install-gui:
    e2e/catalog-install-gui.sh

# S3 exit proof: public send + shield through the CLI on the standalone sequencer.
e2e-cli:
    e2e/standalone.sh
    e2e/cli.sh; status=$?; e2e/standalone.sh stop; exit $status

# S4 exit proof: faucet, demo token on every route, private payment to another wallet, backup.
e2e-tokens:
    e2e/standalone.sh
    e2e/tokens.sh; status=$?; e2e/standalone.sh stop; exit $status

# Rebuild the LEZ builtins in the pinned docker builder; refresh the evidence file.
verify-builtins:
    cargo run -q -p logos-kit-cli -- verify-program --builtins > registry/builtins.json

# S5 exit proof: deploy the testimonial program, post from 3 accounts, read evidence.
e2e-testimonial:
    e2e/standalone.sh
    e2e/testimonial.sh; status=$?; e2e/standalone.sh stop; exit $status

# S8: the testimonial app's flow (app + wallet windows, real engine, local chain).
e2e-testimonial-app:
    e2e/standalone.sh
    e2e/testimonial-app.sh; status=$?; e2e/standalone.sh stop; exit $status

# Rebuild the testimonial program at HEAD in the pinned docker builder (artifacts/).
build-testimonial:
    cargo run -q -p logos-kit-cli -- testimonial build

# One-time: PySide6 envs for the QML engine gate (Basecamp desktop 6.9.2, mobile 6.11.1).
qt-setup:
    mkdir -p .qt && cd .qt && uv venv -q -p 3.12 q692 && VIRTUAL_ENV=q692 uv pip install -q "PySide6-Essentials==6.9.2" && uv venv -q -p 3.12 q611 && VIRTUAL_ENV=q611 uv pip install -q "PySide6-Essentials==6.11.1"

# Build the QML SDK (sdk/qml/LogosKit) from the TS packages.
qml-sdk:
    pnpm --filter @logos-kit/protocol --filter @logos-kit/codec --filter @logos-kit/client --filter @logos-kit/theme build
    pnpm --filter @logos-kit/qml-bundle build

# Copy the QML SDK (LogosKit/ + LogosKitUi/) into every app that vendors it.
qml-vendor:
    for d in modules/probe_dapp modules/logos_kit_testimonial; do rm -rf $d/qml/LogosKit $d/qml/LogosKitUi; cp -R sdk/qml/LogosKit sdk/qml/LogosKitUi $d/qml/; done

# QML engine gate: the SDK suite in Node vs Qt 6.9.2 vs Qt 6.11.1 (needs `just qt-setup`).
qml-gate: qml-sdk
    pnpm --filter @logos-kit/qml-bundle gate

# S6 exit proof: a transfer built and signed in TypeScript lands on the standalone sequencer.
e2e-client:
    e2e/standalone.sh
    node e2e/ts/client.ts; status=$?; e2e/standalone.sh stop; exit $status
