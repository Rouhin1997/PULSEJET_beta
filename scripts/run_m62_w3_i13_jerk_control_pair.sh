#!/usr/bin/env bash
# Scientific control: isolate the jerk contribution in the same existing
# M62 W3/I13 2^23-sample segment as the 15-template Stage 7 pilot.
#
# Two independent single-template runs, with everything identical except:
#   control A: a=0, j=0
#   control B: a=0, j=+0.18 m/s^3 (injection truth)
#
# Search frequency is free; DM is fixed to 20. This is not a blind DM test.
# Both use exactly the same segment and frequency workaround as the bank run.
# No changes to PULSEJET search engine, injected .fil, or original input.
set -euo pipefail

ROOT="${PULSEJET_VALIDATION_ROOT:-/home/rnag/PULSEJET_validation}"
SIF="${PULSEJET_SIF:-$ROOT/images/pulsejet_dev.sif}"
CASE="$ROOT/stage6_m62/m62_15m_injections/W3/case_0001"
BASE="$ROOT/stage7_m62_recovery"
TAG="w3_i13_dm20_center8m_jerk_controls_v1"
META="$BASE/${TAG}_provenance.txt"
DMFILE="$BASE/${TAG}_dm.txt"
START=3216372
N=8388608

shopt -s nullglob
files=("$CASE"/*.fil)
if (( ${#files[@]} != 1 )); then
  echo "Expected exactly one W3 injected .fil; found ${#files[@]}" >&2
  exit 2
fi
FIL="${files[0]}"
if [[ ! -s "$SIF" ]]; then
  echo "PULSEJET image missing: $SIF" >&2; exit 2
fi
if ! command -v singularity >/dev/null; then
  echo "singularity is not on PATH" >&2; exit 2
fi
for f in "$META" "$DMFILE"; do
  if [[ -e "$f" ]]; then echo "Refusing to overwrite $f" >&2; exit 2; fi
done
for label in zero true; do
  for f in "$BASE/${TAG}_${label}" "$BASE/${TAG}_${label}.log" "$BASE/${TAG}_${label}_bank.txt"; do
    if [[ -e "$f" ]]; then echo "Refusing to overwrite $f" >&2; exit 2; fi
  done
done
singularity exec --nv "$SIF" nvidia-smi -L
mkdir -p "$BASE"
printf '20\n' > "$DMFILE"
{
  date -u '+UTC launch: %Y-%m-%dT%H:%M:%SZ'
  printf 'PULSEJET image: %s (original pinned PeakFinder bug remains)\n' "$SIF"
  printf 'Input: %s\n' "$FIL"
  printf 'W3/I13 truth: 317 Hz; DM=20; a=0; jerk=+0.18 m/s^3 at W3 midpoint\n'
  printf 'Both controls: start_sample=%s; nsamples=fft_size=%s\n' "$START" "$N"
  printf 'Requested band: 154–325 Hz; effective ~308–325 Hz due to known bug\n'
  printf 'Both runs use one identical DM=20 and a=0, with jerk=0 versus +0.18\n'
} > "$META"

for label in zero true; do
  if [[ "$label" == zero ]]; then jerk=0; else jerk=0.18; fi
  BANK="$BASE/${TAG}_${label}_bank.txt"
  OUT="$BASE/${TAG}_${label}"
  LOG="$BASE/${TAG}_${label}.log"
  printf '0 %s\n' "$jerk" > "$BANK"
  cmd=(
    singularity exec --nv "$SIF" peasoup
    -i "$FIL" -o "$OUT"
    --dm_file "$DMFILE" -P "$BANK"
    --start_sample "$START" --nsamples "$N" --fft_size "$N"
    -t 1 -n 4 -m 7 --min_freq 154 --max_freq 325
    --candidate_diagnostics -v
  )
  printf '\nControl %s: ' "$label"
  printf '%q ' "${cmd[@]}"
  printf '\n'
  { printf 'Control %s: ' "$label"; printf '%q ' "${cmd[@]}"; printf '\n'; } >> "$META"
  start=$(date +%s)
  if "${cmd[@]}" 2>&1 | tee "$LOG"; then
    status=0
  else
    status=1
  fi
  runtime=$(($(date +%s)-start))
  printf 'Control %s exit=%s, external wall=%ss\n' "$label" "$status" "$runtime" | tee -a "$LOG" "$META"
  if (( status != 0 )); then exit 1; fi
  if [[ ! -s "$OUT/overview.xml" ]]; then
    echo "No valid overview.xml at $OUT" >&2
    exit 1
  fi
done

python3 - "$BASE/${TAG}_zero/overview.xml" "$BASE/${TAG}_true/overview.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET

print("\nCONTROL RESULTS — candidates within 0.05 Hz of injected 317 Hz")
print("control   ID       frequency       delta_f      a       j       S/N      nh")
print("-" * 78)
for label, path in zip(("j=0", "j=+0.18"), sys.argv[1:]):
    root = ET.parse(path).getroot()
    matches = []
    for c in root.findall("./candidates/candidate"):
        p = float(c.findtext("period"))
        if p <= 0:
            continue
        f = 1.0 / p
        if abs(f - 317.0) <= 0.05:
            matches.append((float(c.findtext("snr")), c, f))
    if not matches:
        print(f"{label:8s}  NO OUTPUT CANDIDATE within ±0.05 Hz (search threshold may have suppressed it)")
        continue
    for snr, c, f in sorted(matches, key=lambda x: -x[0]):
        print(f"{label:8s}  {c.get('id'):>2s}  {f:>14.6f}  {f-317:+11.6f} "
              f"{float(c.findtext('acc')):>7.1f} {float(c.findtext('jerk')):>7.3f}"
              f" {snr:>8.2f} {c.findtext('nh'):>7s}")
print("\nA higher S/N for j=+0.18 at the same frequency would support a real jerk correction gain.")
print("Candidate S/N values are pipeline spectral statistics, not calibrated end-to-end completeness.")
PY

echo "Provenance: $META"
