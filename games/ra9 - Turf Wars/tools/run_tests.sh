#!/usr/bin/env sh
# Runs every test outside Roblox: the rules and the maps (Formulas), then a whole match on the mock engine from the
# server's and the client's side, the bots (and their finding their way on every map at every size), every map, and what goes out to the Discord log and the analytics
# (LogSmoke), the tutorial and the leaderboards, and Capture the Flag (CtfSmoke). First it builds the small Luau runner in tools/luaurun.
set -e
cd "$(dirname "$0")/.."
cargo build --release --quiet --manifest-path tools/luaurun/Cargo.toml
R=tools/luaurun/target/release/luaurun
$R tests/Formulas.spec.luau
$R tests/ServerSmoke.spec.luau
$R tests/ClientSmoke.spec.luau
$R tests/BotSmoke.spec.luau
$R tests/BotNavSmoke.spec.luau
$R tests/PartySmoke.spec.luau
$R tests/AdminSmoke.spec.luau
$R tests/MapSmoke.spec.luau
$R tests/LogSmoke.spec.luau
$R tests/TutorialSmoke.spec.luau
$R tests/LeaderboardSmoke.spec.luau
$R tests/JoinSmoke.spec.luau
$R tests/FlairSmoke.spec.luau
$R tests/FxSmoke.spec.luau
$R tests/InviteSmoke.spec.luau
$R tests/GiftSmoke.spec.luau
$R tests/HookSmoke.spec.luau
$R tests/FeelSmoke.spec.luau
$R tests/CtfSmoke.spec.luau
