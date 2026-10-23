#!/usr/bin/env bash
# Runs the lune test suite from the game folder (any working directory works).
set -euo pipefail
cd "$(dirname "$0")/.."
exec lune run tests/run.luau "$@"
