#!/usr/bin/env sh
# Runs every test outside Roblox on the mock engine (tests/mock/Engine.luau): the server and the client booting
# together (BootSmoke), then each system's own suite as it lands. First it builds the small Luau runner in
# tools/luaurun.
set -e
cd "$(dirname "$0")/.."
cargo build --release --quiet --manifest-path tools/luaurun/Cargo.toml
R=tools/luaurun/target/release/luaurun
$R tests/BootSmoke.spec.luau
$R tests/FarmSmoke.spec.luau
$R tests/AnimalSmoke.spec.luau
$R tests/OrderSmoke.spec.luau
$R tests/WarehouseSmoke.spec.luau
$R tests/HubSmoke.spec.luau
