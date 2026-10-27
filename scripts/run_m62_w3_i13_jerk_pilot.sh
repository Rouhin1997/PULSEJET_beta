#!/usr/bin/env bash
# M62 W3/I13: first controlled jerk-template selection on real MeerKAT background.
# INCEPTION truth (W3 midpoint): f=317 Hz, additional DM=20 pc/cc,
# a=0 m/s^2, jerk=+0.18 m/s^3, target integrated SNR=50.
#
# IMPORTANT: use a 2^23 sample segment centered within the ACTUAL
# 14,821,352 sample injected file, with nsamples = fft_size.
# No FFT zero-padding: the polynomial kernel's midpoint is the physical
# injection midpoint (to < one time sample). A 2^24 padded full-window run
# would silently move its polynomial reference epoch ~59 s later.
#
# Old immutable PULSEJET SIF PeakFinder min-frequency bug persists:
# requested min=154, max=325 => effective ~308-325 Hz, including 317 Hz.
# DM is fixed to truth and bank includes truth; this is controlled
# discrete (a,j) template selection, not unconstrained blind recovery.
set -euo pipefail

ROOT="${PULSEJET_VALIDATION_ROOT:-/home/rnag/PULSEJET_validation}"
SIF="${PULSEJET_SIF:-$ROOT/images/pulsejet_dev.sif}"
CASE="$ROOT/stage6_m62/m62_15m_injections/W3/case_0001"
BASE="$ROOT/stage7_m62_recovery"
TAG="w3_i13_dm20_aj_bank_center8m_v1"
OUT="$BASE/$TAG"
LOG="$BASE/$TAG.log"
META="$BASE/${TAG}_provenance.txt"
DMFILE="$BASE/${TAG}_dm.txt"
BANK="$BASE/${TAG}_bank.txt"

TOTAL=14821352
N=8388608
START=$(((TOTAL-N)/2))
shopt -s nullglob
filters=("$CASE"/*.fil)
if (( ${#filters[@]} != 1 )); then
    echo "Expected exactly one injected .fil in $CASE; found ${#filters[@]}" >&2
    exit 2
fi
FIL="${filters[0]}"
if [[ ! -s "$SIF" ]]; then
    echo "Missing PULSEJET image: $SIF" >&2; exit 2
fi
if ! command -v singularity >/dev/null; then
    echo "singularity not found" >&2; exit 2
fi
for f in "$OUT" "$LOG" "$META" "$DMFILE" "$BANK"; do
    if [[ -e "$f" ]]; then
        echo "Refusing to overwrite existing output: $f" >&2; exit 2
    fi
done
echo "GPU preflight via existing pinned image:"
singularity exec --nv "$SIF" nvidia-smi -L

mkdir -p "$BASE"
printf '20\n' > "$DMFILE"
# Fifteen 2-D templates: three accelerations, five jerks.
# Include stationary, acceleration-only, wrong-sign jerk, true jerk
# and a nearby jerk alternative. No source code/distiller modifications.
for a in -20 0 20; do
    for j in -0.18 0 0.09 0.18 0.27; do
        printf '%s %s\n' "$a" "$j"
    done
done > "$BANK"

cmd=(
    singularity exec --nv "$SIF" peasoup
    -i "$FIL" -o "$OUT"
    --dm_file "$DMFILE" -P "$BANK"
    --start_sample "$START"
    --nsamples "$N" --fft_size "$N"
    -t 1 -n 4 -m 7
    --min_freq 154 --max_freq 325
    --candidate_diagnostics -v
)
{
    date -u '+UTC launch: %Y-%m-%dT%H:%M:%SZ'
    printf 'Input injected filterbank: %s\n' "$FIL"
    printf 'Pinned search image (unpatched PeakFinder): %s\n' "$SIF"
    printf 'W3 total sample count: %s; start sample: %s; segment/FFT samples: %s\n' "$TOTAL" "$START" "$N"
    printf 'Truth f=317 Hz, DM=20 pc/cc, a=0 m/s^2, j=+0.18 m/s^3 (W3 midpoint)\n'
    printf 'Template bank: 3 acceleration x 5 jerk, containing truth\n'
    printf 'Requested frequency band 154–325 Hz; effective ~308–325 Hz due to existing bug\n'
    printf 'No padding; segment midpoint matches full-window reference midpoint\n'
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
    echo "Search exited successfully but overview.xml is missing/empty: $OUT" >&2
    exit 1
fi
echo "Output XML: $OUT/overview.xml"
echo "Log: $LOG"
echo "Inspect candidate frequency near 317 Hz, DM=20, a=0 and j=+0.18."
echo "After checking the bank's winner, run single-template j=0 versus j=+0.18 controls for an independent S/N comparison."
