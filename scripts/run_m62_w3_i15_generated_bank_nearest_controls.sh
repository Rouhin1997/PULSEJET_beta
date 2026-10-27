#!/usr/bin/env bash
# Stage 8: verify two EQUI-METRIC nearest off-grid templates independently.
# These are selected from the ACTUAL saved generator bank, NOT hardcoded.
# The two nearest predicted mismatch points for I15 tie at mu=0.164314,
# but can give different PULSEJET spectral S/N on the same noise realization.
#
# Both independent one-template searches have identical settings to the
# successful 12-row generated-bank and exact-truth experiments.
# This isolates bank distillation from per-template GPU response.
set -euo pipefail
ROOT="${PULSEJET_VALIDATION_ROOT:-/home/rnag/PULSEJET_validation}"
GEN="$ROOT/PULSEJET_templatebank_source"
BANK="$GEN/outputs/w3_i15_reference.txt"
REPORT="$GEN/outputs/w3_i15_reference.json"
EXPECTED_SHA="969af3da3f5a271d36af4ed98808a6d68337592eaa1d127a5159faf95a02a29f"
SIF="${PULSEJET_SIF:-$ROOT/images/pulsejet_dev.sif}"
CASE="$ROOT/stage6_m62/m62_15m_injections/W3/case_0001"
BASE="$ROOT/stage8_m62_generated_bank"
TAG="w3_i15_dm8_nearest_grid_pair_center8m_v1"
META="$BASE/${TAG}_provenance.txt"
DMFILE="$BASE/${TAG}_dm.txt"
N=8388608
START=3216372

# Fail before touching results if any output path is occupied.
[[ -s "$BANK" && -s "$REPORT" ]] || {
  echo "Missing saved generated bank or its JSON report" >&2; exit 2;
}
[[ -s "$SIF" ]] || { echo "Missing pinned image $SIF" >&2; exit 2; }
command -v singularity >/dev/null || { echo "singularity missing" >&2; exit 2; }
shopt -s nullglob
files=("$CASE"/*.fil)
if (( ${#files[@]} != 1 )); then
  echo "Expected one W3 injected filterbank in $CASE; got ${#files[@]}" >&2
  exit 2
fi
FIL="${files[0]}"
mkdir -p "$BASE"
for f in "$META" "$DMFILE"; do
  [[ ! -e "$f" ]] || { echo "Would overwrite $f" >&2; exit 2; }
done
for label in nearest_a nearest_b; do
  for f in "$BASE/${TAG}_${label}" "$BASE/${TAG}_${label}.log" "$BASE/${TAG}_${label}_bank.txt"; do
    [[ ! -e "$f" ]] || { echo "Would overwrite $f" >&2; exit 2; }
  done
done

# Locate the two nearest cells without modifying generator output.
# Export a compact list with precise original 17-digit bank row values.
# Note expected tie and reject a bank that is no longer the reference grid.
PAIR=$(
  python3 - "$BANK" "$REPORT" "$EXPECTED_SHA" <<'PY'
import hashlib,json,math,sys
path,rpath,expected=sys.argv[1:]
with open(path,'rb') as f: content=f.read()
sha=hashlib.sha256(content).hexdigest()
if sha!=expected: raise SystemExit("Unexpected bank SHA: "+sha)
with open(rpath) as f: report=json.load(f)
if report["bank_sha256"]!=sha: raise SystemExit("Bank/report SHA mismatch")
g=report["metric"]
rows=[]
for line in content.decode("ascii").splitlines():
    fields=line.split()
    if len(fields)!=2: raise SystemExit("Bad bank row")
    a,j=map(float,fields)
    mu=g["g_aa"]*(a+235)**2+g["g_jj"]*(j+0.25)**2
    rows.append((mu,a,j,fields[0],fields[1]))
rows.sort()
if len(rows)!=12: raise SystemExit("Expected 12 saved generator bank rows")
first,second=rows[:2]
if not math.isclose(first[0],second[0],rel_tol=0,abs_tol=1e-12):
    raise SystemExit("Nearest pair no longer equivalent in quadratic metric")
if not math.isclose(first[0],0.16431401102179768,rel_tol=0,abs_tol=1e-10):
    raise SystemExit("Mismatch changed from documented test")
for row in (first,second):
    print(row[3],row[4])
PY
)
mapfile -t NEAREST <<< "$PAIR"
(( ${#NEAREST[@]} == 2 )) || { echo "Two nearest rows not identified" >&2; exit 2; }
printf '8\n' > "$DMFILE"
{
  date -u '+UTC launch: %Y-%m-%dT%H:%M:%SZ'
  echo "Purpose: independent one-template responses for two equal metric-distance generator cells"
  echo "Source data: $FIL"
  echo "Generator bank SHA256: $EXPECTED_SHA"
  echo "Pinned SIF: $SIF"
  echo "DM=8; START=$START; nsamples=fft_size=$N; CLI --min_freq 187 --max_freq 395"
  echo "Truth W3/I15: 383Hz; a=-235; j=-0.25; exact-template S/N=36.15"
  echo "Full generated 12-cell bank top S/N=25.15 (a=-230, j≈-0.2916667)"
} > "$META"
echo "GPU preflight:"
singularity exec --nv "$SIF" nvidia-smi -L

idx=0
for label in nearest_a nearest_b; do
  BANKONE="$BASE/${TAG}_${label}_bank.txt"
  OUT="$BASE/${TAG}_${label}"
  LOG="$BASE/${TAG}_${label}.log"
  printf '%s\n' "${NEAREST[$idx]}" > "$BANKONE"
  printf '%s one-template coordinates: %s\n' "$label" "${NEAREST[$idx]}" | tee -a "$META"
  cmd=(
    singularity exec --nv "$SIF" peasoup
    -i "$FIL" -o "$OUT"
    --dm_file "$DMFILE" -P "$BANKONE"
    --start_sample "$START" --nsamples "$N" --fft_size "$N"
    -t 1 -n 4 -m 7 --min_freq 187 --max_freq 395
    --candidate_diagnostics -v
  )
  printf 'Launching: '; printf '%q ' "${cmd[@]}"; printf '\n'
  t0=$(date +%s)
  if "${cmd[@]}" 2>&1 | tee "$LOG"; then status=0; else status=1; fi
  dt=$(($(date +%s)-t0))
  printf '%s exit=%s, external wall=%ss\n' "$label" "$status" "$dt" | tee -a "$META" "$LOG"
  if (( status != 0 )); then exit 1; fi
  [[ -s "$OUT/overview.xml" ]] || {
    echo "Missing or empty candidate XML: $OUT/overview.xml" >&2; exit 1;
  }
  idx=$((idx+1))
done

python3 - "$BASE/${TAG}_nearest_a/overview.xml" "$BASE/${TAG}_nearest_b/overview.xml" "$REPORT" <<'PY'
import json,sys,xml.etree.ElementTree as ET
with open(sys.argv[3]) as f: metric=json.load(f)["metric"]
print("\nINDEPENDENT NEAREST-TEMPLATE CONTROLS near injected 383 Hz")
print("label      ID   f(Hz)        delta_f       a          j        S/N   nh   metric_mu")
print("-"*90)
best={}
for label,path in zip(("nearest_a","nearest_b"),sys.argv[1:3]):
    root=ET.parse(path).getroot()
    matches=[]
    for c in root.findall(".//candidate"):
        period=float(c.findtext("period"))
        if period<=0: continue
        f=1.0/period
        if abs(f-383)>0.05: continue
        snr=float(c.findtext("snr"))
        a=float(c.findtext("acc"))
        j=float(c.findtext("jerk"))
        mu=metric["g_aa"]*(a+235)**2 + metric["g_jj"]*(j+0.25)**2
        matches.append((snr,c.get("id"),f,a,j,c.findtext("nh"),mu))
    if not matches:
        print("{}: no candidate returned within ±0.05 Hz".format(label))
        continue
    matches.sort(reverse=True)
    best[label]=matches[0]
    for snr,cid,f,a,j,nh,mu in matches:
        print("{:<10} {:>2} {:>12.6f} {:+12.6f} {:>8.2f} {:>10.6f} "
              "{:>8.2f} {:>3} {:>10.6f}".format(label,cid,f,f-383,a,j,snr,nh,mu))
print("\nContext: matched-truth standalone S/N = 36.15; generated 12-cell bank S/N = 25.15")
if best:
    for label,x in best.items():
        print("{}: relative spectral S/N loss vs truth = {:.4%}".format(label,1-x[0]/36.15))
print("This does not measure true coherent-power loss or end-to-end completeness.")
PY
echo "Provenance: $META"
