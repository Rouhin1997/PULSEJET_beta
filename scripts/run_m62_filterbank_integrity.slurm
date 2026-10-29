#!/usr/bin/env bash
#SBATCH --job-name=m62_fil_integrity
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --nice=1000
#SBATCH --output=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/%x_%j.out
#SBATCH --error=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/%x_%j.err

# Submit with: sbatch --nodelist=node11 --export=ALL,AUDIT_MANIFEST=... path/to/this/file
# Or change --nodelist=node12 if node11 is unavailable.
# The job reads existing .fil files and ONLY writes under the separate audit directory.
set -euo pipefail
umask 077

AUDIT_WD="${AUDIT_WD:-/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029}"
AUDIT_MANIFEST="${AUDIT_MANIFEST:-/home/rnag/PULSEJET_validation/stage6_m62/m62_15m_windows/windows_manifest.json}"
AUDIT_CODE="${AUDIT_WD}/scripts/verify_m62_filterbank_integrity.py"
REPORT_DIR="${AUDIT_WD}/results/${SLURM_JOB_ID:-manual}"

[[ -f "$AUDIT_MANIFEST" ]] || { echo "Missing manifest: $AUDIT_MANIFEST" >&2; exit 2; }
[[ -r "$AUDIT_CODE" ]] || { echo "Missing audit script: $AUDIT_CODE" >&2; exit 2; }
[[ ! -e "$REPORT_DIR" ]] || { echo "Refusing to reuse report directory: $REPORT_DIR" >&2; exit 2; }
mkdir -p "$REPORT_DIR"

echo "AUDIT START $(date --iso-8601=seconds)"
echo "HOST $(hostname)"
echo "JOB ${SLURM_JOB_ID:-manual}"
echo "CPUS ${SLURM_CPUS_PER_TASK:-unknown}"
echo "MANIFEST $AUDIT_MANIFEST"
echo "REPORT_DIR $REPORT_DIR"
echo "IO cap: 64 MiB/s aggregate source+window reads"
echo "NOTE: This job does NOT modify or regenerate source, background, or injected .fil files."
python3 -u "$AUDIT_CODE" \
  --manifest "$AUDIT_MANIFEST" \
  --report-dir "$REPORT_DIR" \
  --chunk-mib 4 \
  --max-io-mib-s 64
echo "AUDIT FINISHED $(date --iso-8601=seconds)"
