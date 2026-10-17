#!/usr/bin/env sh
# Builds every place of the universe (Data/Modes) with Rojo: TurfWars.rbxl from default.project.json (the turf
# place, as always), and Lobby.rbxl, CTF.rbxl, Brawl.rbxl and Tycoon.rbxl from places/*.project.json (the same src tree, plus
# the Mode value under ReplicatedStorage that tells the code which place it is). Each goes up to its own place in
# the Creator Dashboard (other/ra9/PLAN.md, "Places"). ROJO=/path/to/rojo picks the binary (default: rojo on PATH).
set -e
cd "$(dirname "$0")/.."
ROJO="${ROJO:-rojo}"
"$ROJO" build default.project.json -o TurfWars.rbxl
"$ROJO" build places/lobby.project.json -o Lobby.rbxl
"$ROJO" build places/ctf.project.json -o CTF.rbxl
"$ROJO" build places/brawl.project.json -o Brawl.rbxl
"$ROJO" build places/tycoon.project.json -o Tycoon.rbxl
ls -la TurfWars.rbxl Lobby.rbxl CTF.rbxl Brawl.rbxl Tycoon.rbxl
