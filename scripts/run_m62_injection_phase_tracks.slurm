#!/usr/bin/env bash
#SBATCH --job-name=m62_phase_track
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --nice=1000
#SBATCH --output=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/%x_%j.out
#SBATCH --error=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/%x_%j.err
# Stage 2B pilot: independent sparse differential-pixel phase matching.
# Exactly ONE completed Stage 6 W1-W4 case; no active Stage 10 reads/writes.
set -euo pipefail
umask 077
W="${1:-1}"
case "$W" in 1|2|3|4) ;; *) echo "Expected W 1-4" >&2; exit 2 ;; esac
ROOT=/home/rnag/PULSEJET_validation
WD="$ROOT/m62_filterbank_validation_20261029"
SIF="$ROOT/images/inception_lite.sif"
SCRIPT="$WD/scripts/verify_m62_injection_phase_tracks.py"
CASE="$ROOT/stage6_m62/m62_15m_injections/W$W/case_0001"
CONFIG="$ROOT/stage6_m62/weekend_configs/m62_weekend_20_w$W.json"
REPORT="$WD/results/injection_phase_${SLURM_JOB_ID:?Slurm required}/W$W"
[[ -s "$SIF" && -r "$SCRIPT" && -s "$CASE/run_manifest.json" && -s "$CONFIG" ]] ||
    { echo "Missing Stage 6 case/config, SIF, or independent verifier" >&2; exit 3; }
[[ ! -e "$REPORT" ]] || { echo "Report already exists; refusing overwrite: $REPORT" >&2; exit 3; }
mkdir -p "$REPORT"
echo "STAGE2B PILOT START $(date --iso-8601=seconds)"
echo "NODE $(hostname) JOB $SLURM_JOB_ID W$W"
echo "READ ONLY: source+completed injected .fil; sample 32x4096; no new injection or folding"
singularity exec --cleanenv "$SIF" env PYTHONNOUSERSITE=1 \
    python3 -u "$SCRIPT" --case-dir "$CASE" --config "$CONFIG" \
    --report-dir "$REPORT" --blocks 32 --samples-per-block 4096
echo "STAGE2B PILOT FINISHED $(date --iso-8601=seconds)"
echo "NOTE: this is differential-pixel phase coherence, not calibrated SNR or full-model certification"
