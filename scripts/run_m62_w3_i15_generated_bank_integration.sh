#!/usr/bin/env bash
# Stage 8: first generated-bank-to-GPU integration test (not a blind survey).
#
# Run the ACTUAL externally-generated, SHA-pinned, 12-row midpoint bank on
# existing injected M62 W3/I15 observation. The injected truth is deliberately
# absent from the bank. Independent benchmark: Stage7 single-template matched
# a=-235,j=-0.25 gives search S/N 36.15 at f=382.999908 Hz.
#
# Hold fixed: same W3 .fil, DM=8, physical segment START=3216372,
# N=FFT=8388608 (~505.29 s), PULSEJET SIF and all CLI knobs from Stage7.
# Only change the a/j template bank. Existing PeakFinder bug requires half
# the desired minimum frequency (requested min=187, effective ~374 Hz).
# No injected files, images or old experiment outputs are modified.
set -euo pipefail

ROOT="${PULSEJET_VALIDATION_ROOT:-/home/rnag/PULSEJET_validation}"
SIF="${PULSEJET_SIF:-$ROOT/images/pulsejet_dev.sif}"
GEN="$ROOT/PULSEJET_templatebank_source"
BANK="$GEN/outputs/w3_i15_reference.txt"
REPORT="$GEN/outputs/w3_i15_reference.json"
CASE="$ROOT/stage6_m62/m62_15m_injections/W3/case_0001"
BASE="$ROOT/stage8_m62_generated_bank"
TAG="w3_i15_dm8_generated_grid12_center8m_v1"
OUT="$BASE/$TAG"
LOG="$BASE/$TAG.log"
META="$BASE/${TAG}_provenance.txt"
DMFILE="$BASE/${TAG}_dm.txt"
EXPECTED_SHA="969af3da3f5a271d36af4ed98808a6d68337592eaa1d127a5159faf95a02a29f"
N=8388608
START=3216372

if [[ ! -s "$BANK" || ! -s "$REPORT" ]]; then
  echo "Generator bank/report not found. Complete bank-generation Step 2 first." >&2
  echo "Missing: $BANK or $REPORT" >&2
  exit 2
fi
# Read-only audit BEFORE GPU launch. Independent of pulsejet_bank package.
python3 - "$BANK" "$REPORT" "$EXPECTED_SHA" <<'PY'
import hashlib
import json
import math
import sys

bank_file, report_file, expected = sys.argv[1:]
with open(bank_file, "rb") as stream:
    content = stream.read()
sha = hashlib.sha256(content).hexdigest()
if sha != expected:
    raise SystemExit("Bank SHA mismatch: " + sha + " != " + expected)
with open(report_file, "r", encoding="utf-8") as stream:
    report = json.load(stream)
if report["bank_sha256"] != sha:
    raise SystemExit("Generator report bank_sha256 does not match actual file")
d = report["design"]
checks = {
    "frequency_hz": 383.0, "duration_s": 505.2902701172523,
    "a_min": -255.0, "a_max": -215.0,
    "j_min": -0.4, "j_max": 0.25, "max_mismatch": 0.30,
}
if any(not math.isclose(d[k], v, abs_tol=1e-10, rel_tol=0)
       for k,v in checks.items()):
    raise SystemExit("Generated bank report design does not match this test")
if report["method"] != "grid" or report["template_count"] != 12:
    raise SystemExit("Expected precisely the 12-row deterministic grid")
rows = []
for line in content.decode("ascii").splitlines():
    parts = line.split()
    if len(parts) != 2:
        raise SystemExit("Template must have exactly two numeric columns")
    a,j = map(float,parts)
    if not (math.isfinite(a) and math.isfinite(j)):
        raise SystemExit("Non-finite template")
    rows.append((a,j))
if len(rows) != 12:
    raise SystemExit("Expected 12 rows; found " + str(len(rows)))
truth_a, truth_j = -235.0, -0.25
if (truth_a,truth_j) in rows:
    raise SystemExit("Injection truth appears in template bank; not off-grid!")
gaa,gjj = report["metric"]["g_aa"],report["metric"]["g_jj"]
def mismatch(row):
    return gaa * (row[0] - truth_a)**2 + gjj * (row[1] - truth_j)**2
ranking = sorted((mismatch(row),row) for row in rows)
print("BANK PREFLIGHT — PASS")
print("Bank SHA256:", sha)
print("Rows:",len(rows))
print("Truth a,j:",truth_a,truth_j,"(off-grid)")
for mu,row in ranking[:2]:
    print("Nearest template a,j:",row,"predicted quadratic mismatch:",format(mu,".12f"))
if not ranking[0][0] < d["max_mismatch"]:
    raise SystemExit("Truth is not covered within target metric mismatch")
PY

shopt -s nullglob
files=("$CASE"/*.fil)
if (( ${#files[@]} != 1 )); then
  echo "Expected precisely one injected W3 .fil in $CASE; found ${#files[@]}" >&2
  exit 2
fi
FIL="${files[0]}"
[[ -s "$SIF" ]] || { echo "Pinned SIF missing: $SIF" >&2; exit 2; }
command -v singularity >/dev/null || { echo "singularity unavailable" >&2; exit 2; }
mkdir -p "$BASE"
for f in "$OUT" "$LOG" "$META" "$DMFILE"; do
  if [[ -e "$f" ]]; then
    echo "Refusing to overwrite existing output: $f" >&2
    exit 2
  fi
done

echo "GPU preflight:"
singularity exec --nv "$SIF" nvidia-smi -L

printf '8\n' > "$DMFILE"
cmd=(
  singularity exec --nv "$SIF" peasoup
  -i "$FIL" -o "$OUT"
  --dm_file "$DMFILE" -P "$BANK"
  --start_sample "$START" --nsamples "$N" --fft_size "$N"
  -t 1 -n 4 -m 7 --min_freq 187 --max_freq 395
  --candidate_diagnostics -v
)
{
  date -u '+UTC launch: %Y-%m-%dT%H:%M:%SZ'
  printf 'PULSEJET source commit: '
  git -C "$ROOT/PULSEJET_dev_source" rev-parse HEAD || true
  printf 'Bank generator commit: '
  git -C "$GEN" rev-parse HEAD || true
  printf 'Pinned PULSEJET image: %s\n' "$SIF"
  printf 'Input injected W3 filterbank: %s\n' "$FIL"
  printf 'Generator bank: %s\n' "$BANK"
  printf 'Bank SHA256: %s\n' "$EXPECTED_SHA"
  printf 'Bank report: %s\n' "$REPORT"
  printf 'W3/I15 truth: f=383 Hz; a=-235 m/s^2; j=-0.25 m/s^3; DM=8\n'
  printf 'Centered segment start=%s, n=fft=%s (sample dt ~60.235 microseconds)\n' "$START" "$N"
  printf 'Requested band 187–395 Hz, effective ~374–395 Hz owing to PeakFinder bug\n'
  printf 'Matched single-template baseline: search S/N=36.15, f=382.999908 Hz, nh=3\n'
  printf 'Command: '; printf '%q ' "${cmd[@]}"; printf '\n'
} > "$META"

echo "Launching generated-grid GPU search:"
printf '%q ' "${cmd[@]}"
printf '\n'
t0=$(date +%s)
if "${cmd[@]}" 2>&1 | tee "$LOG"; then
  status=0
else
  status=1
fi
duration=$(($(date +%s)-t0))
printf 'Exit status: %s; outer wall time: %s s\n' "$status" "$duration" | tee -a "$LOG" "$META"
if (( status != 0 )); then exit 1; fi
if [[ ! -s "$OUT/overview.xml" ]]; then
  echo "Missing or empty overview.xml: $OUT/overview.xml" >&2
  exit 1
fi

python3 - "$OUT/overview.xml" "$REPORT" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET

root=ET.parse(sys.argv[1]).getroot()
with open(sys.argv[2],encoding="utf-8") as f:
    g=json.load(f)["metric"]
gaa,gjj=g["g_aa"],g["g_jj"]
rows=[]
for cand in root.findall(".//candidate"):
    try:
        p=float(cand.findtext("period"))
        if p<=0: continue
        freq=1.0/p
        dm=float(cand.findtext("dm"))
        acc=float(cand.findtext("acc"))
        jerk=float(cand.findtext("jerk"))
        snr=float(cand.findtext("snr"))
        nh=int(cand.findtext("nh"))
        assoc=int(cand.findtext("nassoc"))
        mu=gaa*(acc+235.0)**2+gjj*(jerk+0.25)**2
        rows.append((snr,cand.get("id"),freq,dm,acc,jerk,nh,assoc,mu))
    except (ValueError,TypeError,ZeroDivisionError) as exc:
        print("Invalid XML candidate:",exc,file=sys.stderr)
rows.sort(reverse=True)
print("\nGENERATED-BANK CANDIDATES (all, sorted by search S/N)")
print("id  freq(Hz)   Δf(Hz)     DM      a       j       S/N  nh  assoc  pred. μ")
print("-"*92)
for snr,cid,f,dm,a,j,nh,assoc,mu in rows:
    print(f"{cid:>2}  {f:>10.6f} {f-383:+10.6f} {dm:>5.1f} "
          f"{a:>7.1f} {j:>8.4f} {snr:>8.2f} {nh:>3} {assoc:>6} {mu:>9.4f}")
matches=[r for r in rows if abs(r[2]-383.0)<=0.05]
if matches:
    hit=matches[0]
    ratio=hit[0]/36.15
    print("\nI15 recovery near 383 Hz: found candidate")
    print("Recovered f:",format(hit[2],".6f"),"Hz; bank template a,j:",(hit[4],hit[5]))
    print("Metric-predicted coherent power mismatch:",format(hit[8],".6f"))
    print("Off-grid search S/N:",format(hit[0],".2f"))
    print("Matched truth-template Stage7 search S/N: 36.15")
    print("Observed search-S/N ratio:",format(ratio,".4f"))
    print("Observed search-S/N fractional reduction:",format(1-ratio,".4f"))
else:
    print("\nNo returned candidate within ±0.05 Hz of I15; inspect threshold and diagnostics.")
print("CAUTION: search-S/N loss and quadratic coherent-power mismatch are distinct metrics.")
PY

echo "Output XML: $OUT/overview.xml"
echo "GPU log: $LOG"
echo "Provenance: $META"
