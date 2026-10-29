#!/usr/bin/env bash
# Stage 2B: export independent phase-tracking code without changing active jobs.
# Fetch/pin code outside this script; old cluster Git supported (no git -C).
set -euo pipefail
umask 077
ROOT=/home/rnag/PULSEJET_validation
REPO="${PULSEJET_REPO:-$ROOT/PULSEJET_dev_source}"
WD="${AUDIT_WD:-$ROOT/m62_filterbank_validation_20261029}"
SIF="$ROOT/images/inception_lite.sif"
REF=origin/dev/polynomial-search
[[ -d "$REPO/.git" && -s "$SIF" ]] || {
  echo "Missing local PULSEJET repository or INCEPTION image" >&2; exit 2;
}
repo_git() ( cd "$REPO" && git "$@" )
files=(scripts/verify_m62_injection_phase_tracks.py
       scripts/run_m62_injection_phase_tracks.slurm
       tests/test_verify_m62_injection_phase_tracks.py)
for item in "${files[@]}"; do
  [[ ! -e "$WD/$item" ]] || { echo "Refusing overwrite: $WD/$item" >&2; exit 2; }
  repo_git cat-file -e "$REF:$item"
done
[[ -r "$WD/scripts/verify_m62_injection_case.py" ]] || {
  echo "Requires already verified Stage 2A code in WD" >&2; exit 2;
}
[[ -s "$ROOT/stage6_m62/m62_15m_injections/W1/case_0001/run_manifest.json" ]] || {
  echo "Stage 6 W1 not completed; no phase-track audit will be prepared" >&2; exit 2;
}
mkdir -p "$WD/scripts" "$WD/tests" "$WD/logs" "$WD/results"
for item in "${files[@]}"; do
    repo_git show "$REF:$item" > "$WD/$item"
done
echo "== Test Stage 2B analytic truth-vs-wrong-motion/DM controls inside INCEPTION image =="
singularity exec --cleanenv "$SIF" env PYTHONNOUSERSITE=1 \
  python3 -m unittest discover -s "$WD/tests" -p test_verify_m62_injection_phase_tracks.py -v
echo "== Stage 2B PILOT READY (no Slurm job submitted) =="
echo "Run: sbatch --nodelist=node11 $WD/scripts/run_m62_injection_phase_tracks.slurm 1"
echo "Read-only against W1 Stage 6; Stage 10 active files will not be read"
