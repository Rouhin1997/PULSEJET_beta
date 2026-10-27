#!/usr/bin/env bash
# PeakFinder regression: the legacy image could crash at requested 200–350 Hz
# because it internally began near 400 Hz. New image MUST search 200–350 Hz
# correctly at harmonic levels nh=0..4 and recover known injected W1 pulsars.
#
# This is NOT a new injection or a bank-coverage experiment. The two cases use
# fixed DM and known a/j to isolate frequency selection and GPU stability.
#
# Usage (from an allocated A40 node):
#   PULSEJET_PATCHED_SIF=/home/rnag/PULSEJET_validation/images/NEW_PINNED.sif \
#     bash scripts/run_m62_w1_peakfinder_fixed_band_regression.sh
#
# Never reuse the unpatched /images/pulsejet_dev.sif and never overwrite
# earlier stage6/7/8 observations, logs, or results.
set -euo pipefail

ROOT="${PULSEJET_VALIDATION_ROOT:-/home/rnag/PULSEJET_validation}"
SIF="${PULSEJET_PATCHED_SIF:?Set PULSEJET_PATCHED_SIF to the newly built, version-pinned SIF}"
OLD="$ROOT/images/pulsejet_dev.sif"
CASE="$ROOT/stage6_m62/m62_15m_injections/W1/case_0001"
BASE="$ROOT/stage9_peakfinder_regression"
TAG="w1_fixed_min200_max350_v1"
[[ -s "$SIF" ]] || { echo "Patched image does not exist: $SIF" >&2; exit 2; }
if [[ -e "$OLD" && "$(readlink -f "$SIF")" == "$(readlink -f "$OLD")" ]]; then
  echo "Refusing to use old pinned image, which retains the frequency-bound bug" >&2
  exit 2
fi
command -v singularity >/dev/null || { echo "singularity unavailable" >&2; exit 2; }
shopt -s nullglob
files=("$CASE"/*.fil)
if (( ${#files[@]} != 1 )); then
  echo "Expected exactly one previously injected W1 .fil; found ${#files[@]}" >&2
  exit 2
fi
FIL="${files[0]}"
mkdir -p "$BASE"

# No rewrite of any existing experiment and do not leave partially written
# config files when an already-existing destination was detected.
for t in w1_i01_dm0_stationary w1_i02_dm4_acc40; do
  for suffix in "" ".log" "_dm.txt" "_bank.txt" "_provenance.txt"; do
    path="$BASE/${TAG}_${t}${suffix}"
    [[ ! -e "$path" ]] || { echo "Refusing to overwrite: $path" >&2; exit 2; }
  done
done
echo "A40 GPU check:"
singularity exec --nv "$SIF" nvidia-smi -L
echo "Patched SIF sha256:"
sha256sum "$SIF"

for label in w1_i01_dm0_stationary w1_i02_dm4_acc40; do
  OUT="$BASE/${TAG}_${label}"
  LOG="${OUT}.log"
  META="${OUT}_provenance.txt"
  DMFILE="${OUT}_dm.txt"
  BANK="${OUT}_bank.txt"
  if [[ "$label" == w1_i01_dm0_stationary ]]; then
    expected_f=247
    printf '0\n' > "$DMFILE"
    printf '0 0\n' > "$BANK"
    START=0
  else
    expected_f=263
    printf '4\n' > "$DMFILE"
    printf '40 0\n' > "$BANK"
    START=5313523
  fi
  N=4194304
  cmd=(
    singularity exec --nv "$SIF" peasoup
    -i "$FIL" -o "$OUT" --dm_file "$DMFILE" -P "$BANK"
    --start_sample "$START" --nsamples "$N" --fft_size "$N"
    -t 1 -n 4 -m 7 --min_freq 200 --max_freq 350
    --candidate_diagnostics -v
  )
  {
    date -u '+UTC launch: %Y-%m-%dT%H:%M:%SZ'
    echo "PeakFinder corrected-band GPU regression for: $label"
    echo "Image: $SIF"
    sha256sum "$SIF"
    echo "Input: $FIL"
    echo "Requested frequency band: [200,350] Hz inclusive, NO old workaround"
    echo "Known injected source frequency: $expected_f Hz"
    echo "Segment: start_sample=$START; nsamples=fft_size=$N; DM and motion fixed to truth"
    printf 'Command: '; printf '%q ' "${cmd[@]}"; printf '\n'
  } > "$META"
  echo "Executing $label with original formerly failing 200–350Hz user band"
  t0=$(date +%s)
  if "${cmd[@]}" 2>&1 | tee "$LOG"; then status=0; else status=1; fi
  wall=$(($(date +%s)-t0))
  printf 'Status: %s, wall: %ss\n' "$status" "$wall" | tee -a "$LOG" "$META"
  (( status == 0 )) || exit 1
  [[ -s "$OUT/overview.xml" ]] || { echo "Missing XML: $OUT/overview.xml" >&2; exit 1; }

  python3 - "$OUT/overview.xml" "$expected_f" "$label" <<'PY'
import sys,xml.etree.ElementTree as ET
path,truth,label=sys.argv[1],float(sys.argv[2]),sys.argv[3]
xml=ET.parse(path).getroot()
cands=[]
for c in xml.findall(".//candidate"):
    try:
        period=float(c.findtext("period"))
        if period<=0: continue
        f=1./period
        snr=float(c.findtext("snr"))
        cands.append((snr,f,c.findtext("nh"),c.findtext("acc"),c.findtext("jerk")))
    except (TypeError,ValueError,ZeroDivisionError):
        pass
hits=sorted((c for c in cands if abs(c[1]-truth)<0.05),reverse=True)
print("\nFrequency-bound regression:",label)
print("XML candidate count:",len(cands))
if not hits:
    raise SystemExit("FAIL: injected signal missing from corrected [200,350] Hz band")
snr,f,nh,a,j=hits[0]
print("PASS: f={:.6f} Hz, delta_f={:+.6f} Hz, S/N={:.2f}, nh={}, a={}, j={}".format(
    f,f-truth,snr,nh,a,j))
if snr<7:
    raise SystemExit("FAIL: recovered candidate below controlled search S/N threshold")
PY
done
echo "PeakFinder corrected [200,350]Hz GPU regression: both injected sources RECOVERED."
echo "Results under: $BASE"
