#!/usr/bin/env bash
# Controlled Stage 7 acceleration-template recovery of M62 W1/I02.
# Truth: P0=1/263 s, additional DM=4, acceleration=+40 m/s^2, jerk=0.
# Search is blind in f and chooses between 5 acceleration templates, but
# DM and j are fixed and the template grid intentionally includes truth.
# Uses the existing pinned PULSEJET SIF WITHOUT altering its code.
# The unpatched PeakFinder has ~2x min-frequency bug; 128–270 Hz request
# probes approximately 256–270 Hz, containing I02 near 263 Hz.
set -euo pipefail

ROOT="${PULSEJET_VALIDATION_ROOT:-/home/rnag/PULSEJET_validation}"
SIF="${PULSEJET_SIF:-$ROOT/images/pulsejet_dev.sif}"
CASE="$ROOT/stage6_m62/m62_15m_injections/W1/case_0001"
BASE="$ROOT/stage7_m62_recovery"
TAG="w1_i02_dm4_acc_bank_center4m_v1"
OUT="$BASE/$TAG"
LOG="$BASE/$TAG.log"
META="$BASE/${TAG}_provenance.txt"
DMFILE="$BASE/${TAG}_dm.txt"
BANK="$BASE/${TAG}_bank.txt"

# W1 contains 14,821,351 samples. Analyze an exactly centered
# 2^22-sample subset; midpoint agrees with the INCEPTION injection epoch.
TOTAL=14821351
N=4194304
START=$(((TOTAL-N)/2))

shopt -s nullglob
filters=("$CASE"/*.fil)
if (( ${#filters[@]} != 1 )); then
  echo "Expected exactly one injected .fil in $CASE; found ${#filters[@]}" >&2
  exit 2
fi
FIL="${filters[0]}"
if [[ ! -s "$SIF" ]]; then echo "Missing PULSEJET image: $SIF" >&2; exit 2; fi
if ! command -v singularity >/dev/null; then echo "singularity not found" >&2; exit 2; fi
for target in "$OUT" "$LOG" "$META" "$DMFILE" "$BANK"; do
  if [[ -e "$target" ]]; then
    echo "Refusing to overwrite existing path: $target" >&2; exit 2
  fi
done
echo "GPU preflight via existing pinned image:"
singularity exec --nv "$SIF" nvidia-smi -L
mkdir -p "$BASE"

printf '4\n' > "$DMFILE"
printf '0 0\n20 0\n40 0\n60 0\n80 0\n' > "$BANK"
cmd=(
  singularity exec --nv "$SIF" peasoup
  -i "$FIL" -o "$OUT"
  --dm_file "$DMFILE" -P "$BANK"
  --start_sample "$START"
  --nsamples "$N" --fft_size "$N"
  -t 1 -n 4 -m 7
  --min_freq 128 --max_freq 270
  --candidate_diagnostics -v
)
{
  date -u '+UTC launch: %Y-%m-%dT%H:%M:%SZ'
  printf 'Injected file: %s\n' "$FIL"
  printf 'Pinned image (unpatched PeakFinder): %s\n' "$SIF"
  printf 'W1 total samples: %s; start sample: %s; real/FFT sample count: %s\n' "$TOTAL" "$START" "$N"
  printf 'I02 truth at full-window midpoint: f=263 Hz, DM=4, a=+40 m/s^2, j=0\n'
  printf 'DM fixed at 4; acceleration grid 0,20,40,60,80; jerk fixed at 0\n'
  printf 'Requested band 128–270 Hz; approximate effective band 256–270 Hz (unpatched PeakFinder)\n'
  printf 'Command: '; printf '%q ' "${cmd[@]}"; printf '\n'
} > "$META"
echo "Launching: ${cmd[*]}"
t0=$(date +%s)
if "${cmd[@]}" 2>&1 | tee "$LOG"; then status=0; else status=1; fi
t1=$(date +%s)
printf 'Exit status: %s; outer wall time: %s s\n' "$status" "$((t1-t0))" | tee -a "$LOG"
printf 'Exit status: %s; outer wall time: %s s\n' "$status" "$((t1-t0))" >> "$META"
if (( status != 0 )); then exit 1; fi
if [[ ! -s "$OUT/overview.xml" ]]; then
  echo "Search exited successfully but overview.xml is empty or missing: $OUT" >&2
  exit 1
fi
echo "Output XML: $OUT/overview.xml"
echo "Log: $LOG"
echo "Examine candidate f=1/period near 263 Hz and their acceleration values."
