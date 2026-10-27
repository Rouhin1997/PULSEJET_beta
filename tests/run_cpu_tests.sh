#!/usr/bin/env bash
# Compile and execute CPU-only characterization tests without CUDA or dedisp.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CXX="${CXX:-g++}"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

for name in test_polynomial_distiller test_candidate_grouping test_candidate_populations test_candidate_diagnostics test_candidate_diagnostics_cli test_polynomial_timing test_polynomial_templatebank test_peakfinder_bounds; do
    echo "=== Compiling ${name} ==="
    "$CXX" -std=c++17 -O2 -Wall -Wextra -pedantic \
        -I"$ROOT/include" -I"$ROOT/tests" \
        "$ROOT/tests/${name}.cpp" -o "$BUILD_DIR/${name}"
    echo "=== Running ${name} ==="
    "$BUILD_DIR/${name}"
done
