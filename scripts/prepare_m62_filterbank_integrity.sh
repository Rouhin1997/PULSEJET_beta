#!/usr/bin/env bash
# Prepare a separate read-only M62 extraction audit WITHOUT checking out a new branch.
# Does not submit jobs or modify original, background, or injected filterbanks.
set -euo pipefail
umask 077

REPO="${PULSEJET_REPO:-/home/rnag/PULSEJET_beta}"
WD="${AUDIT_WD:-/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029}"
MANIFEST="${AUDIT_MANIFEST:-/home/rnag/PULSEJET_validation/stage6_m62/m62_15m_windows/windows_manifest.json}"
REF="origin/dev/polynomial-search"

[[ -d "$REPO/.git" ]] || { echo "No git repository at $REPO" >&2; exit 2; }
[[ -r "$MANIFEST" ]] || { echo "Missing M62 manifest: $MANIFEST" >&2; exit 2; }
[[ ! -e "$WD/scripts/verify_m62_filterbank_integrity.py" ]] || { echo "Refusing to overwrite existing audit scripts in $WD" >&2; exit 2; }
mkdir -p "$WD/scripts" "$WD/tests" "$WD/logs" "$WD/results"

# Export committed code to a new WD; git show does not switch or touch the active checkout.
git -C "$REPO" show "$REF:scripts/verify_m62_filterbank_integrity.py" > "$WD/scripts/verify_m62_filterbank_integrity.py"
git -C "$REPO" show "$REF:scripts/extract_sigproc_windows.py" > "$WD/scripts/extract_sigproc_windows.py"
git -C "$REPO" show "$REF:tests/test_verify_m62_filterbank_integrity.py" > "$WD/tests/test_verify_m62_filterbank_integrity.py"
git -C "$REPO" show "$REF:tests/test_extract_sigproc_windows.py" > "$WD/tests/test_extract_sigproc_windows.py"
git -C "$REPO" show "$REF:scripts/run_m62_filterbank_integrity.slurm" > "$WD/run_m62_filterbank_integrity.slurm"

git -C "$REPO" rev-parse "$REF" > "$WD/code_commit.txt"
sha256sum "$WD/scripts/"*.py "$WD/tests/"*.py "$WD/run_m62_filterbank_integrity.slurm" > "$WD/code_checksums.sha256"

echo "== Isolated synthetic regressions =="
PYTHONNOUSERSITE=1 python3 -m unittest discover -s "$WD/tests" -p "test_extract_sigproc_windows.py" -v 2>&1 | tee "$WD/logs/test_original_extractor.txt"
PYTHONNOUSERSITE=1 python3 -m unittest discover -s "$WD/tests" -p "test_verify_m62_filterbank_integrity.py" -v 2>&1 | tee "$WD/logs/test_read_only_auditor.txt"

echo "== Verify existing manifest refers to original observation and completed backgrounds =="
python3 - "$MANIFEST" <<'PY'
import json, sys
from pathlib import Path
manifest = Path(sys.argv[1])
m = json.loads(manifest.read_text())
paths = [Path(m["source"])] + [Path(x["path"]) for x in m["segments"]]
for i, path in enumerate(paths):
    print(("SOURCE" if i == 0 else "WINDOW%d" % i) + " " + str(path) + " " + ("EXISTS" if path.is_file() else "MISSING"))
if len(m["segments"]) != 4 or not all(p.is_file() for p in paths):
    raise SystemExit("Missing/incorrect M62 inputs; no submission")
PY

echo "== Ready (no Slurm job has been submitted) =="
echo "Working directory: $WD"
echo "Input manifest: $MANIFEST"
echo "Check nodes: sinfo -N -n node11,node12 -o '%N %T %C %m'"
echo "Submit node11: sbatch --nodelist=node11 $WD/run_m62_filterbank_integrity.slurm"
echo "Fallback node12: sbatch --nodelist=node12 $WD/run_m62_filterbank_integrity.slurm"
