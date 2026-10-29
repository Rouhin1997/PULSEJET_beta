#!/usr/bin/env bash
#SBATCH --job-name=m62_inj_integrity
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --nice=1000
#SBATCH --output=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/%x_%j.out
#SBATCH --error=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/%x_%j.err
# Stage 2A: READ-ONLY metadata, SIGPROC header and deterministic payload checks.
# Audit ONLY completed 20-source pilot outputs; NEVER stage10_ucb100 active jobs.
set -euo pipefail
umask 077
ROOT=/home/rnag/PULSEJET_validation
WD="$ROOT/m62_filterbank_validation_20261029"
CODE="$WD/scripts/verify_m62_injection_case.py"
REPORT="$WD/results/injection_integrity_${SLURM_JOB_ID:?Submit using sbatch}"
[[ -r "$CODE" ]] || { echo "Missing code: $CODE" >&2; exit 2; }
[[ ! -e "$REPORT" ]] || { echo "Refusing to overwrite report directory: $REPORT" >&2; exit 2; }
mkdir -p "$REPORT"
echo "STAGE2 START $(date --iso-8601=seconds)"
echo "NODE $(hostname) JOB $SLURM_JOB_ID"
echo "AUDIT SCOPE: completed stage6_m62 W1-W4 only; stage10_ucb100 untouched"
for i in 1 2 3 4; do
    case_dir="$ROOT/stage6_m62/m62_15m_injections/W${i}/case_0001"
    config="$ROOT/stage6_m62/weekend_configs/m62_weekend_20_w${i}.json"
    [[ -s "$case_dir/run_manifest.json" ]] || { echo "No completed case W$i: $case_dir" >&2; exit 3; }
    [[ -s "$config" ]] || { echo "Missing original W$i config: $config" >&2; exit 3; }
    echo "===== CHECK W${i} ====="
    python3 -u "$CODE" --case-dir "$case_dir" --config "$config" \
        --report-dir "$REPORT/W${i}" --blocks 32 --samples-per-block 4096
    echo "===== W${i} METADATA AND GEOMETRY PASS ====="
done
echo "STAGE2A FINISHED $(date --iso-8601=seconds)"
