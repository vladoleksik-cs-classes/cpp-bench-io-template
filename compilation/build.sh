#!/usr/bin/env bash
set -euo pipefail

SRC="./main.cpp"
OUT="program"

echo "Compiling ${SRC} → ${OUT}..."
g++ -std=c++23 -O2 "$SRC" -o "$OUT"
echo "Done compiling."
