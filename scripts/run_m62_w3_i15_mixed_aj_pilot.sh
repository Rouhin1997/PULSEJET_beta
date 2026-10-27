#!/usr/bin/env bash
# Stage 7 controlled *mixed* acceleration and jerk injection recovery.
# Target INCEPTION W3/I15: f=383 Hz; DM=8 pc/cm^3;
# a=-235 m/s^2, j=-0.25 m/s^3 at the full W3 midpoint;
# injected full-observation SNR target 65.
#
# Search existing W3 .fil in an exactly centered ~505.2-s (2^23-sample)
# segment, without extra FFT length padding. The pinned PULSEJET image
# remains unchanged, including the PeakFinder minimum-frequency bug.
# Old CLI 187-395 Hz corresponds to effective ~374-395 Hz.
#
# DM fixed, frequency blind in selected band; 15 a/j templates include
# the truth and mismatched options. Do not claim a blind DM or continuous
# motion estimate from this controlled bank.
set -euo pipefail

ROOT="${PULSEJET_VALIDATION_ROOT:-/home/rnag/PULSEJET_validation}"
SIF="${PULSEJET_SIF:-$ROOT/images/pulsejet_dev.sif}"
CASE="$ROOT/stage6_m62/m62_15m_injections/W3/case_0001"
BASE="$ROOT/stage7_m62_recovery"
TAG="w3_i15_dm8_mixed_aj_center8m_v1"
OUT="$BASE/$TAG"
LOG="$BASE/$TAG.log"
META="$BASE/${TAG}_provenance.txt"
DMFILE="$BASE/${TAG}_dm.txt"
BANK="$BASE/${TAG}_bank.txt"
TOTAL=14821352
N=8388608
START=$(((TOTAL-N)/2))

shopt -s nullglob
files=("$CASE"/*.fil)
if (( ${#files[@]} != 1 )); then
  echo "Expected exactly one injected W3 .fil; found ${#files[@]}" >&2
  exit 2
fi
FIL="${files[0]}"
if [[ ! -s "$SIF" ]]; then echo "Missing PULSEJET image: $SIF" >&2; exit 2; fi
if ! command -v singularity >/dev/null; then
  echo "singularity not found" >&2; exit 2
fi
for f in "$OUT" "$LOG" "$META" "$DMFILE" "$BANK"; do
  if [[ -e "$f" ]]; then echo "Refusing to overwrite $f" >&2; exit 2; fi
done
echo "GPU preflight:"
singularity exec --nv "$SIF" nvidia-smi -L
mkdir -p "$BASE"
printf '8\n' > "$DMFILE"
for a in -255 -235 -215; do
  for j in -0.40 -0.25 -0.10 0 0.25; do
    printf '%s %s\n' "$a" "$j"
  done
done > "$BANK"

cmd=(
  singularity exec --nv "$SIF" peasoup
  -i "$FIL" -o "$OUT"
  --dm_file "$DMFILE" -P "$BANK"
  --start_sample "$START" --nsamples "$N" --fft_size "$N"
  -t 1 -n 4 -m 7
  --min_freq 187 --max_freq 395
  --candidate_diagnostics -v
)
{
  date -u '+UTC launch: %Y-%m-%dT%H:%M:%SZ'
  printf 'Input (unchanged): %s\n' "$FIL"
  printf 'Pinned search image: %s; PeakFinder lower-frequency bug remains unfixed\n' "$SIF"
  printf 'W3 total samples=%s, centered start=%s, nsamples=FFT size=%s\n' "$TOTAL" "$START" "$N"
  printf 'W3/I15 injection truth: 383 Hz; DM=8, a=-235 m/s^2, j=-0.25 m/s^3\n'
  printf 'Controlled trial grid: a={-255,-235,-215}; j={-0.40,-0.25,-0.10,0,+0.25}\n'
  printf 'Requested frequencies 187-395 Hz, effective ~374-395 Hz (PeakFinder bug)\n'
  printf 'Command: '; printf '%q ' "${cmd[@]}"; printf '\n'
} > "$META"

echo "Launching: ${cmd[*]}"
t0=$(date +%s)
if "${cmd[@]}" 2>&1 | tee "$LOG"; then
  status=0
else
  status=1
fi
runtime=$(($(date +%s)-t0))
printf 'Exit status: %s; external wall: %s s\n' "$status" "$runtime" | tee -a "$LOG" "$META"
if (( status != 0 )); then exit 1; fi
if [[ ! -s "$OUT/overview.xml" ]]; then
  echo "Search completed without nonempty overview.xml at $OUT" >&2
  exit 1
fi

python3 - "$OUT/overview.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
print("\nCANDIDATES — mixed acceleration–jerk bank, injection I15 f=383 Hz")
print("id     frequency     delta_f     DM        a        j      S/N   nh  nassoc")
print("-" * 86)
for c in root.findall("./candidates/candidate"):
    try:
        p = float(c.findtext("period"))
        if p <= 0: continue
        f = 1.0 / p
        print(f"{c.get('id'):>2}  {f:>12.6f}  {f-383:+10.6f} "
              f"{float(c.findtext('dm')):>6.1f} "
              f"{float(c.findtext('acc')):>8.1f} "
              f"{float(c.findtext('jerk')):>8.3f} "
              f"{float(c.findtext('snr')):>8.2f} "
              f"{c.findtext('nh'):>4} {c.findtext('nassoc'):>7}")
    except (TypeError, ValueError, ZeroDivisionError) as exc:
        print(f"Could not interpret candidate {c.get('id')}: {exc}", file=sys.stderr)
PY
echo "Results: $OUT/overview.xml"
echo "Log: $LOG"
echo "Provenance: $META"
echo "Next: verify f close to 383 Hz, a=-235, j=-0.25; do not declare success merely from execution."
