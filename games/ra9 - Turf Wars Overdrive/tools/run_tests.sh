#!/usr/bin/env sh
# Runs every test outside Roblox: the rules and the maps (Formulas), then a whole match on the mock engine from the
# server's side (ServerSmoke) and through the real client (ClientSmoke). Needs Rust (cargo) the first time, to
# build the small Luau runner in tools/luaurun.
set -e
cd "$(dirname "$0")/.."
cargo build --release --quiet --manifest-path tools/luaurun/Cargo.toml
R=tools/luaurun/target/release/luaurun
$R tests/Formulas.spec.luau
$R tests/ServerSmoke.spec.luau
$R tests/ClientSmoke.spec.luau
$R tests/BotSmoke.spec.luau
