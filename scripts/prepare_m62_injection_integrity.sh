#!/usr/bin/env bash
# Safely deploy Stage 2 scripts to the EXISTING independent verification WD.
# No checkout switch, injector invocation, Slurm submission or .fil modification.
set -euo pipefail
umask 077

ROOT=/home/rnag/PULSEJET_validation
REPO="${PULSEJET_REPO:-$ROOT/PULSEJET_dev_source}"
WD="${AUDIT_WD:-$ROOT/m62_filterbank_validation_20261029}"
REF=origin/dev/polynomial-search
[[ -d "$REPO/.git" ]] || { echo "Missing PULSEJET repository: $REPO" >&2; exit 2; }
repo_git() ( cd "$REPO" && git "$@" )
files=(
  scripts/verify_m62_injection_case.py
  scripts/run_m62_injection_integrity.slurm
  scripts/inspect_inception_runtime.py
  tests/test_verify_m62_injection_case.py
)
for file in "${files[@]}"; do
  [[ ! -e "$WD/$file" ]] || { echo "Refusing to overwrite: $WD/$file" >&2; exit 2; }
  repo_git cat-file -e "$REF:$file" || { echo "Missing in GitHub-fetched branch: $file" >&2; exit 2; }
done
for n in 1 2 3 4; do
  [[ -s "$ROOT/stage6_m62/m62_15m_injections/W$n/case_0001/run_manifest.json" ]] || {
     echo "Stage 6 W$n not complete; refusing automated verification preflight" >&2; exit 2;
  }
  [[ -s "$ROOT/stage6_m62/weekend_configs/m62_weekend_20_w$n.json" ]] || {
     echo "Missing original W$n configuration" >&2; exit 2;
  }
done
mkdir -p "$WD/scripts" "$WD/tests" "$WD/logs" "$WD/results"
for file in "${files[@]}"; do
  repo_git show "$REF:$file" > "$WD/$file"
done
test ! -e "$WD/results/stage2_code_checksums.sha256" || {
  echo "Refusing to overwrite existing Stage 2 provenance record" >&2; exit 2;
}
sha256sum "${files[@]/#/$WD/}" > "$WD/results/stage2_code_checksums.sha256"
echo "== Stage 2 isolated synthetic regression =="
python3 -m unittest discover -s "$WD/tests" -p test_verify_m62_injection_case.py -v
echo "== READY: Stage 2 scripts and regression verified =="
echo "WD $WD"
echo "Job (node11): sbatch --nodelist=node11 $WD/scripts/run_m62_injection_integrity.slurm"
echo "Job (node12): sbatch --nodelist=node12 $WD/scripts/run_m62_injection_integrity.slurm"
echo "Original and injected files have not been modified."
