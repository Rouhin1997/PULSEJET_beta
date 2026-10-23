#!/usr/bin/env bash
# Compile and run a CPU-vs-PULSEJET GPU resampler test on one A40 compute node.
# Usage: bash scripts/run_polynomial_cuda_parity.sh /absolute/path/pulsejet_dev.sif [output_directory]
# Requires an allocated GPU and the pinned PULSEJET development SIF.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: bash $0 /absolute/path/pulsejet_dev.sif [output_directory]" >&2
  exit 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
image="$(readlink -f "$1")"
outdir="${2:-$HOME/PULSEJET_validation/stage2}"
mkdir -p "$outdir"
outdir="$(cd "$outdir" && pwd -P)"
test -f "$image" || { echo "Missing SIF: $image" >&2; exit 2; }
test -f "$root/tests/test_polynomial_cuda_parity.cu" || {
  echo "Missing CUDA parity source file on development branch" >&2; exit 2;
}

echo "=== Source and runtime ==="
echo "Host: $(hostname)"
echo "SIF: $image"
echo "Test source: $root/tests/test_polynomial_cuda_parity.cu"
echo "Output: $outdir"
if git -C "$root" rev-parse --short HEAD >/dev/null 2>&1; then
  echo "Host test branch: $(git -C "$root" branch --show-current)"
  echo "Host test commit: $(git -C "$root" rev-parse HEAD)"
fi

# The original image has already compiled /software/peasoup/obj/kernels.o;
# use THIS object rather than accidentally compiling a copied test kernel.
singularity exec --nv "$image" test -r /software/peasoup/obj/kernels.o || {
  echo "The pinned image is missing its production kernels.o; do not replace it silently" >&2
  exit 2
}

echo "=== Compile CUDA test against production kernels.o (no PULSEJET rebuild) ==="
singularity exec --nv "$image" /usr/local/cuda/bin/nvcc \
  -std=c++17 -O2 \
  -gencode arch=compute_86,code=sm_86 \
  "$root/tests/test_polynomial_cuda_parity.cu" \
  /software/peasoup/obj/kernels.o \
  -L/usr/local/cuda/lib64 -lcudart -lcufft \
  -L/usr/local/lib -ldedisp -lnvToolsExt \
  -lpthread \
  -o "$outdir/polynomial_cuda_parity"

echo "=== Execute real production CUDA polynomial resampler on A40 ==="
singularity exec --nv "$image" "$outdir/polynomial_cuda_parity" \
  | tee "$outdir/polynomial_cuda_parity.log"

echo "Completed. Log: $outdir/polynomial_cuda_parity.log"
