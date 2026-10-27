#!/usr/bin/env bash
# Stage 8 scientific control: Does the harm-summing configuration account
# for strong PULSEJET spectral-S/N loss at small FUNDAMENTAL metric mismatch?
#
# Exact reference: W3/I15 f=383 Hz, DM=8, a=-235, j=-0.25.
# Off-grid B is selected from the actual SHA-verified externally generated
# 12-row bank: a=-230, j=-0.29166666666666669; mu_fundamental=0.164314.
#
# Four independent one-template runs on identical input/segment/DM/settings:
# 2 motion corrections x [-n 1, -n 4].
# In Peasoup, -n 1 searches un-summed fundamental and up to 2 harmonics;
# -n 4 searches fundamental and 2,4,8,16 harmonic-summing stages.
# It is NOT a controlled extraction of the fundamental alone.
# No PULSEJET code, container, original bank, or input data is changed.
set -euo pipefail

ROOT="${PULSEJET_VALIDATION_ROOT:-/home/rnag/PULSEJET_validation}"
SIF="${PULSEJET_SIF:-$ROOT/images/pulsejet_dev.sif}"
GEN="$ROOT/PULSEJET_templatebank_source"
BANK="$GEN/outputs/w3_i15_reference.txt"
REPORT="$GEN/outputs/w3_i15_reference.json"
BANK_SHA="969af3da3f5a271d36af4ed98808a6d68337592eaa1d127a5159faf95a02a29f"
CASE="$ROOT/stage6_m62/m62_15m_injections/W3/case_0001"
BASE="$ROOT/stage8_m62_generated_bank"
TAG="w3_i15_dm8_harmonic_sensitivity_pairs_center8m_v1"
META="$BASE/${TAG}_provenance.txt"
DMFILE="$BASE/${TAG}_dm.txt"
N=8388608
START=3216372
mkdir -p "$BASE"

shopt -s nullglob
files=("$CASE"/*.fil)
if (( ${#files[@]} != 1 )); then
  echo "Expected exactly one W3 injected .fil in $CASE, got ${#files[@]}" >&2
  exit 2
fi
FIL="${files[0]}"
[[ -s "$SIF" ]] || { echo "Pinned search SIF missing: $SIF" >&2; exit 2; }
command -v singularity >/dev/null || { echo "singularity missing" >&2; exit 2; }
[[ -s "$BANK" && -s "$REPORT" ]] || {
  echo "Original generated bank/report missing" >&2; exit 2;
}
for f in "$META" "$DMFILE"; do
  [[ ! -e "$f" ]] || { echo "Refusing to overwrite $f" >&2; exit 2; }
done
for mode in truth offgrid; do
  for n in 1 4; do
    for f in "$BASE/${TAG}_${mode}_n${n}" "$BASE/${TAG}_${mode}_n${n}.log" "$BASE/${TAG}_${mode}_n${n}_bank.txt"; do
      [[ ! -e "$f" ]] || { echo "Refusing to overwrite $f" >&2; exit 2; }
    done
  done
done
# Validate the bank content and select the nearest off-grid template
# with a=−230. PULSEJET XML candidate stores jerk in float precision.
OFFGRID=$(
python3 - "$BANK" "$REPORT" "$BANK_SHA" <<'PY'
import hashlib,json,math,sys
bank,report,expected=sys.argv[1:]
with open(bank,'rb') as f: raw=f.read()
sha=hashlib.sha256(raw).hexdigest()
if sha!=expected: raise SystemExit("Unexpected bank sha "+sha)
with open(report) as f: meta=json.load(f)
if meta["bank_sha256"]!=sha: raise SystemExit("Bank/report SHA mismatch")
if meta["template_count"]!=12 or meta["method"]!="grid":
    raise SystemExit("Not the saved 12-row metric grid")
g=meta["metric"]
rows=[line.split() for line in raw.decode("ascii").splitlines()]
if len(rows)!=12 or any(len(r)!=2 for r in rows):
    raise SystemExit("Malformed generated bank")
deltas=[]
for atext,jtext in rows:
    a,j=float(atext),float(jtext)
    mu=g["g_aa"]*(a+235.)**2+g["g_jj"]*(j+0.25)**2
    deltas.append((mu,a,j,atext,jtext))
mu,a,j,at,jt=min((r for r in deltas if math.isclose(r[1],-230.,abs_tol=1e-10)))
if not math.isclose(mu,0.16431401102179768,abs_tol=1e-10):
    raise SystemExit("Unexpected I15 nearest-mismatch value")
print(at,jt)
PY
)
echo "Verified actual off-grid template: $OFFGRID"
printf '8\n' > "$DMFILE"
{
  date -u '+UTC launch: %Y-%m-%dT%H:%M:%SZ'
  echo "Aim: harmonic-stage sensitivity of off-grid template bank on I15."
  echo "Input observational filterbank: $FIL"
  echo "Pinned search image: $SIF"
  echo "Generator bank: $BANK"
  echo "Generator bank SHA256: $BANK_SHA"
  echo "Generator commit: $(git -C "$GEN" rev-parse HEAD 2>/dev/null || echo unavailable)"
  echo "PULSEJET source commit: $(git -C "$ROOT/PULSEJET_dev_source" rev-parse HEAD 2>/dev/null || echo unavailable)"
  echo "Search DM=8; start_sample=$START; nsamples=fft_size=$N"
  echo "Search requested f=187-395Hz (effective lower ~374Hz due old PeakFinder bug)"
  echo "Source truth a=-235 j=-0.25, match baseline 36.15 at -n4"
  echo "Offgrid B template: $OFFGRID; predicted fundamental quadratic mu=0.164314"
  echo "Each template: separate -n1 (fundamental+2 harmonics) and -n4 (up to 16 harmonics)."
} > "$META"
singularity exec --nv "$SIF" nvidia-smi -L

for mode in truth offgrid; do
  if [[ "$mode" == truth ]]; then
    aj="-235 -0.25"
  else
    aj="$OFFGRID"
  fi
  for n in 1 4; do
    OUT="$BASE/${TAG}_${mode}_n${n}"
    LOG="$BASE/${TAG}_${mode}_n${n}.log"
    ONE="$BASE/${TAG}_${mode}_n${n}_bank.txt"
    printf '%s\n' "$aj" > "$ONE"
    cmd=(
      singularity exec --nv "$SIF" peasoup
      -i "$FIL" -o "$OUT" --dm_file "$DMFILE" -P "$ONE"
      --start_sample "$START" --nsamples "$N" --fft_size "$N"
      -t 1 -n "$n" -m 7 --min_freq 187 --max_freq 395
      --candidate_diagnostics -v
    )
    printf 'Control %s / harmonic n=%s: ' "$mode" "$n"
    printf '%q ' "${cmd[@]}"; printf '\n'
    { printf 'Control %s, n=%s: ' "$mode" "$n"; printf '%q ' "${cmd[@]}"; printf '\n'; } >> "$META"
    t0=$(date +%s)
    if "${cmd[@]}" 2>&1 | tee "$LOG"; then status=0; else status=1; fi
    dt=$(($(date +%s)-t0))
    printf 'Control %s n=%s exit=%s wall=%ss\n' "$mode" "$n" "$status" "$dt" | tee -a "$META" "$LOG"
    if (( status != 0 )); then exit 1; fi
    [[ -s "$OUT/overview.xml" ]] || { echo "Missing candidate XML for $mode $n" >&2; exit 1; }
  done
done

python3 - "$BASE/$TAG" <<'PY'
import sys,xml.etree.ElementTree as ET
p=sys.argv[1]
print("\nW3/I15 SEARCH HARMONIC-STAGE CONTROL — best candidate near 383 Hz")
print("Motion     -n  Recovered f(Hz)   delta f(Hz)   S/N     nh  interpretation")
print("-"*88)
found={}
for mode in ("truth","offgrid"):
    for n in (1,4):
        xml="{}_{}_n{}/overview.xml".format(p,mode,n)
        root=ET.parse(xml).getroot()
        hits=[]
        for c in root.findall(".//candidate"):
            period=float(c.findtext("period"))
            if period<=0: continue
            f=1./period
            if abs(f-383.)<=0.05:
                hits.append((float(c.findtext("snr")), f, int(c.findtext("nh"))))
        if not hits:
            print("{:<10} {:>2} No candidate returned within ±0.05 Hz".format(mode,n))
            continue
        snr,f,nh=max(hits)
        found[(mode,n)]=snr
        print("{:<10} {:>2} {:>16.6f} {:+13.6f} {:>7.2f} {:>5}  {}".format(
            mode,n,f,f-383.,snr,nh,"fundamental+2" if n==1 else "fundamental+2/4/8/16"))
for n in (1,4):
    if ("truth",n) in found and ("offgrid",n) in found:
        ratio=found[("offgrid",n)]/found[("truth",n)]
        print("n={} offgrid/truth search-SNR ratio {:.4f}; reduction {:.2%}".format(n,ratio,1-ratio))
print("Different -n settings change harmonic-search selection; not independent coherent-power measurements.")
PY
echo "Provenance: $META"
