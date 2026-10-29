# M62 Stage 2 — INCEPTION-Lite injection-integrity verification

**Started 2026-10-29. Current status: CODE PREPARED; no observational Stage 2 result yet.**

## Scope and safety

Stage 1 is closed: the four M62 observational windows have already been
byte-verified against the original SIGPROC observation. This Stage 2 work
intentionally does **not** re-split, re-inject, fold, replace, or rewrite any
original, background, or injected filterbank.

Only the four **completed** Stage 6, five-pulsar-per-window cases are inspected
at first. Do **not** point the job at the in-progress
`/home/rnag/PULSEJET_validation/stage10_ucb100` injection campaign. Stage 2
writes only to the existing separate validation working directory:

`/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029`

Use 4 CPUs, 16 GB RAM, no GPU, node11 (node12 fallback). The case comparison
reads 32 × 4096 samples per window from the background and injection output
(32 MiB per window per side, or 128 MiB across four windows per side, for 256 8-bit channels);
the metadata and headers require negligible additional I/O.

## Source-code provenance

The actual original and extended INCEPTION-Lite source is tracked in its
**separate GitHub repository**:
[INCEPTION-Lite development branch](https://github.com/Rouhin1997/inception_injection_test_tool/tree/dev/pulsejet-injections).
In particular:

- [`inception_lite/runner.py`](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/inception_lite/runner.py):
  case planning, deterministic case seed, injector subprocess, completed
  `run_manifest.json`, software and source hashes, truth folding.
- [`injector/signal_injector.py`](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/injector/signal_injector.py):
  signal synthesis, addition, read-only input, parallel chunk offsets,
  stochastic de-digitization of affected samples and output finalization.
- [`injector/io_tools.py`](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/injector/io_tools.py):
  SIGPROC reader/writer and bit-range clipping.
- [`injector/pulsar_model.py`](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/injector/pulsar_model.py)
  and [`injector/binary_model.py`](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/injector/binary_model.py):
  signal phase and orbital parameter models.

**Important:** the Python implementation does *not* preserve byte identity
within every sample affected by pulsar synthesis. In real-data mode, it starts
from each background block, zeros signal in channels of zero measured variance,
locates active signal samples, stochastically de-digitizes them, adds the model,
rounds and clips to the 8-bit channel range. Unaffected samples are copied as
is. We should not impose a blanket requirement that input and output pixels
be identical. A purely statistical changed-byte map does not prove model
physics or quantify S/N calibration.

The INCEPTION-Lite source is already version-controlled in its **own repo**.
For exact source provenance of the *executed Singularity image* rather than
just the current repo checkout, use the new read-only
[`scripts/inspect_inception_runtime.py`](../scripts/inspect_inception_runtime.py).
The `run_manifest.json` also contains the executable injector script and
pulsar-model source SHA256 digests. Compare the **SIF hashes** with those
manifest values; do not assume the current Git checkout is identical to
the image.

## Stage 2A: independent completed-case geometry and provenance checks

[Auditor](../scripts/verify_m62_injection_case.py),
[synthetic regression](test_verify_m62_injection_case.py),
[Slurm launcher](../scripts/run_m62_injection_integrity.slurm).

For each completed case the auditor:
1. Refuses absent `run_manifest.json` or a stray `*.fil.part`.
2. Reads `resolved_injection.json`, injector `report_*.json`, original
   configuration and final `run_manifest.json`; compares case names,
   source and output paths, pulsar identities, truth dictionaries, derived
   case seed, input mode and original background origin.
3. Requires no `generate_fb` (synthetic Gaussian input), and five positive-S/N
   sources in a `mode=together` observational case.
4. Independently parses both SIGPROC headers and requires **identical raw
   header bytes**, unchanged observation epoch, channel count, sample rate,
   bit depth, sample count, and full payload geometry.
5. Compares corresponding background and output **distributed samples**,
   reporting modified-byte fraction, positive/negative changes and saturation
   diagnostic fractions. It does not assert a calibrated change fraction.
6. Checks file stat metadata remains stable during reads. Writes a standalone
   JSON result with explicit `PASS_METADATA_AND_GEOMETRY` or
   `FAIL_OR_INCOMPLETE`.

Sampling is NOT exhaustive injection payload verification, cannot diagnose
all potential lost-written-block faults, and is NOT independent signal truth
reconstruction. That is handled in Stage 2B with controlled phase/model
and folding checks.

## Deploy to the existing isolated working directory

On frontend2 (old Git; do **not** use `git -C`):

```bash
cd /home/rnag/PULSEJET_validation/PULSEJET_dev_source
git fetch origin
WD=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029
mkdir -p "$WD/scripts" "$WD/tests" "$WD/logs" "$WD/results"

# Refuse to overwrite anything already deployed:
for spec in \
    scripts/verify_m62_injection_case.py \
    scripts/run_m62_injection_integrity.slurm \
    scripts/inspect_inception_runtime.py \
    tests/test_verify_m62_injection_case.py; do
    test ! -e "$WD/$spec" || { echo "Already exists: $WD/$spec"; break; }
    git show "origin/dev/polynomial-search:$spec" > "$WD/$spec" || exit 1
done

python3 -m unittest discover -s "$WD/tests" \
    -p 'test_verify_m62_injection_case.py' -v
```

The Slurm script is placed under `$WD/scripts/`, whereas the logs and results
remain under `$WD/logs/` and `$WD/results/`.

Inspect the required Stage 6 files before submission:

```bash
ROOT=/home/rnag/PULSEJET_validation
for i in 1 2 3 4; do
  ls -lh "$ROOT/stage6_m62/m62_15m_injections/W$i/case_0001/run_manifest.json" \
         "$ROOT/stage6_m62/weekend_configs/m62_weekend_20_w$i.json"
done
```

Optionally capture SIF engine SHA256 **without running any injection**:

```bash
WD=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029
SIF=/home/rnag/PULSEJET_validation/images/inception_lite.sif
test ! -e "$WD/results/inception_runtime_code_sha256.json" &&
singularity exec --cleanenv "$SIF" env PYTHONNOUSERSITE=1 \
  python3 "$WD/scripts/inspect_inception_runtime.py" \
  > "$WD/results/inception_runtime_code_sha256.json"
```

Only after preflight files and the synthetic regression exist and pass,
submit the read-only 20-source case audit:

```bash
WD=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029
sbatch --nodelist=node11 "$WD/scripts/run_m62_injection_integrity.slurm"
# node12 is equivalent when preferable.
```

Monitor with the returned numeric job ID:

```bash
tail -f /home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/m62_inj_integrity_JOBID.out
```

Do not replace `JOBID` with literal angle brackets. A successful Stage 2A
will print `PASS_METADATA_AND_GEOMETRY` for W1 through W4 and an
`STAGE2A FINISHED` line; full JSON output appears at
`$WD/results/injection_integrity_JOBID/W1..W4/injection_integrity_result.json`.

## Stage 2B: independent injected-signal model checks — PENDING

After Stage 2A, verify the physical truth by independently folding selected
stationary, positive/negative acceleration, positive/negative jerk and mixed
20-source signals using the recorded source epoch and the PulsarX midpoint
`PEPOCH`. Check phase coherence and the expected signs of the first- and
second-order spin-frequency derivatives. Separately investigate full
Keplerian injections from *completed* UCB100 batches after their batch jobs
are finished. Compare the actual Singularity engine source hashes to the
manifest to establish precisely which code produced the results.

**Explicitly deferred:** requested nominal injector S/N versus independently
measured S/N, RFI-conditioned completeness, false alarms and blind-search
selection effects — these belong to the pipeline-paper tests.
