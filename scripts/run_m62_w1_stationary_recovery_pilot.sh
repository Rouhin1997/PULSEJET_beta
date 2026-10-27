#!/usr/bin/env bash
# First controlled search of an existing observational M62 injection.
# W1/I01 injection truth: f=247 Hz, additional DM=0, a=j=0, target SNR 100.
# This is blind in frequency only, NOT in DM/acceleration/jerk.
# Intentionally uses the UNPATCHED pinned PULSEJET image's known PeakFinder
# minimum-frequency workaround: requested 110-260 Hz => effective ~220-260 Hz.
# Do not interpret 110-220 Hz as searched or report calibrated sensitivity.
#
# Usage on an allocated A40 node:
#   bash scripts/run_m62_w1_stationary_recovery_pilot.sh
# Optional override: PULSEJET_VALIDATION_ROOT=/other/path bash ...
set -euo pipefail

ROOT="${PULSEJET_VALIDATION_ROOT:-/home/rnag/PULSEJET_validation}"
SIF="${PULSEJET_SIF:-$ROOT/images/pulsejet_dev.sif}"
CASE="$ROOT/stage6_m62/m62_15m_injections/W1/case_0001"
BASE="$ROOT/stage7_m62_recovery"
OUT="$BASE/w1_i01_dm0_a0j0_4m_v1"
LOG="$BASE/w1_i01_dm0_a0j0_4m_v1.log"
BANK="$BASE/w1_i01_stationary_bank.txt"
DMFILE="$BASE/w1_i01_dm0_trials.txt"
META="$BASE/w1_i01_dm0_a0j0_4m_v1_provenance.txt"

if [[ ! -f "$SIF" ]]; then echo "Missing PULSEJET SIF: $SIF" >&2; exit 2; fi
shopt -s nullglob
filterbanks=("$CASE"/*.fil)
if (( ${#filterbanks[@]} != 1 )); then
  echo "Expected one injected .fil in $CASE; found ${#filterbanks[@]}" >&2
  exit 2
fi
FIL="${filterbanks[0]}"
if [[ -e "$OUT" || -e "$LOG" || -e "$META" ]]; then
  echo "Refusing to overwrite an existing run: $OUT, $LOG, or $META" >&2
  exit 2
fi
if ! command -v singularity >/dev/null; then
  echo "singularity not found" >&2
  exit 2
fi
echo "Checking GPU availability via pinned PULSEJET image..."
singularity exec --nv "$SIF" nvidia-smi -L
mkdir -p "$BASE"
# These are reproducible configuration inputs for this one-source pilot.
# Do not clobber an existing bank or DM file from another run.
if [[ -e "$BANK" || -e "$DMFILE" ]]; then
  echo "Existing pilot bank/DM files; refusing to overwrite: $BANK or $DMFILE" >&2
  exit 2
fi
printf '0 0\n' > "$BANK"
printf '0\n' > "$DMFILE"

cmd=(
  singularity exec --nv "$SIF" peasoup
  -i "$FIL"
  -o "$OUT"
  --dm_file "$DMFILE"
  -P "$BANK"
  --start_sample 0
  --nsamples 4194304
  --fft_size 4194304
  -t 1 -n 4 -m 7
  --min_freq 110 --max_freq 260
  --candidate_diagnostics -v
)

{
  printf 'UTC launch: '; date -u '+%Y-%m-%dT%H:%M:%SZ'
  printf 'Input: %s\n' "$FIL"
  printf 'PULSEJET image: %s\n' "$SIF"
  printf 'PULSEJET SIF note: original pinned, PeakFinder min-frequency bug UNFIXED\n'
  printf 'Stage 6 injection truth: I01 f=247 Hz DM=0 a=0 j=0\n'
  printf 'Read length: 4194304 samples (~252.65 seconds); FFT: 4194304; segment start: 0\n'
  printf 'Frequency range: requested 110–260 Hz, effective approximately 220–260 Hz\n'
  printf 'DM and polynomial parameters FIXED to truth; frequency searched inside band\n'
  printf 'Command: '
  printf '%q ' "${cmd[@]}"
  printf '\n'
} > "$META"

echo "Running: ${cmd[*]}"
t0=$(date +%s)
if "${cmd[@]}" 2>&1 | tee "$LOG"; then
  status=0
else
  status=1
fi
t1=$(date +%s)
echo "Exit status: $status; outer wall time: $((t1-t0)) s" | tee -a "$LOG"
printf 'Exit status: %s; wall time: %s s\n' "$status" "$((t1-t0))" >> "$META"
if (( status != 0 )); then exit 1; fi
if [[ ! -s "$OUT/overview.xml" ]]; then
  echo "Search completed but overview.xml is missing/empty in $OUT" >&2
  exit 1
fi
echo "Search XML: $OUT/overview.xml"
echo "Run log: $LOG"
echo "Provenance: $META"
echo "NEXT: inspect candidate frequencies and S/N near f=247 Hz before any further searches."
