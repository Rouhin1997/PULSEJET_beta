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

## Preferred setup: one safe command

The preflight bootstrap is committed as
[`scripts/prepare_m62_injection_integrity.sh`](../scripts/prepare_m62_injection_integrity.sh).
It checks the existence of all four *completed* Stage 6 cases and their
configs, refuses to overwrite existing Stage 2 scripts, exports the exact
GitHub source into the independent working directory and runs the synthetic
regression. It does not submit Slurm jobs.

```bash
cd /home/rnag/PULSEJET_validation/PULSEJET_dev_source
git fetch origin
set -o pipefail
git show origin/dev/polynomial-search:scripts/prepare_m62_injection_integrity.sh | bash
```

If the preflight prints `READY`, the Stage 2 Slurm job is prepared. On
node11 it also fingerprints source code from the actual Singularity image
without running an injection, compares the image's injector and pulsar-model
hashes to the completed-case manifest hashes, and reports a separate
`MATCH` / `MISMATCH_OR_UNRECORDED` status for each window. This does
not silently equate the image with a newer GitHub checkout.

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

## Stage 2A cluster preflight — 2026-10-29

On `frontend2`, the user fetched PULSEJET `origin/dev/polynomial-search` through commit `5866a51` and ran the committed Stage 2A bootstrap:
`git show origin/dev/polynomial-search:scripts/prepare_m62_injection_integrity.sh | bash`.

**Observed preflight: PASS.** The regression `test_metadata_pass_and_header_corruption_fail` passed (1 test, 0.204 s), and the bootstrap printed `== READY: Stage 2 scripts and regression verified ==`, with existing original and injected files left unchanged. The bootstrap's presence checks for W1–W4 completed-case manifests and Stage 6 configurations passed. The separate WD is:
`/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029`.

A second, unnecessary execution of the one-time bootstrap printed `Refusing to overwrite: .../scripts/verify_m62_injection_case.py`. This is the **intended overwrite guard**, not a failed regression or a broken deployment. Do not run the bootstrap again or delete existing copies. The **real-data Stage 2A Slurm audit has not yet been submitted** at this checkpoint.

Next cluster action:
```bash
sbatch --nodelist=node11 \
  /home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/scripts/run_m62_injection_integrity.slurm
```


## Stage 2A real-data result — 2026-10-29, Slurm 66715

**Final result from the actual node11 cluster run: PASS_METADATA_AND_GEOMETRY for W1–W4.** This documents the operator-provided Slurm stdout and empty stderr; it is not a claim of independent access to the cluster.

- Slurm job: `66715`, host `node11.cluster`; start `2026-10-29T14:47:43+0100`; final log marker `STAGE2A FINISHED 2026-10-29T14:48:13+0100` (30 s wall-clock difference).
- Scope: existing five-source injections in completed Stage 6 `W1`–`W4` only, **20 injected pulsars total**; ongoing `stage10_ucb100` not accessed.
- All four case checks printed `RESULT PASS_METADATA_AND_GEOMETRY` and corresponding `Wk METADATA AND GEOMETRY PASS`.
- Source provenance from the executed INCEPTION-Lite SIF: `injector_script_sha256 MATCH` **4/4** and `pulsar_model_sha256 MATCH` **4/4** against the saved run manifests. This supports that these two key injector sources in the current SIF are byte-identical to those recorded during the completed Stage 6 injections; the runner does not yet attest the full transitive code dependency tree.
- The operator's `m62_inj_integrity_66715.err` output was empty.
- The underlying auditor checks exact SIGPROC header bytes and observation sample geometry, configuration/resolved-truth/report/manifest consistency, and deterministic spread-out **sampled** original-versus-injected payload differences. Acceptance does not require a nonzero change fraction; it is a metadata/geometry gate, not a proof of injected signal detection.
- The four individual JSON result bodies (including changed-byte fractions) have **not** been inspected in this report; their contents must be read before quoting any numerical injection-difference metrics.

**Preserved cluster results:**

```text
/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/injection_integrity_66715/inception_sif_source_sha256.json
/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/injection_integrity_66715/W1/injection_integrity_result.json
/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/injection_integrity_66715/W2/injection_integrity_result.json
/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/injection_integrity_66715/W3/injection_integrity_result.json
/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/injection_integrity_66715/W4/injection_integrity_result.json
/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/m62_inj_integrity_66715.out
```

**Stage 2A status: COMPLETE for executed existing-case metadata, filterbank geometry and two recorded runtime source hashes.** **Stage 2B not yet passed:** signal-phase/sign/epoch model fidelity, quantization physics and representative known-parameter folding must be checked separately before asserting scientific injection correctness. The full Keplerian UCB100 binaries require a distinct subsequent validation set after completion.


## Stage 2A sampled payload difference statistics — Slurm 66715

After the Stage 2A `PASS_METADATA_AND_GEOMETRY` result, the operator read the `data_sample_comparison` fields from the four JSON reports. Each window was sampled at 32 distributed 4096-time-sample blocks; for this 256-channel unsigned 8-bit file that is 33,554,432 compared bytes per window (per input/output file).

| Window | Observed changed bytes | Changed fraction | Positive differences | Negative differences | Maximum absolute byte difference |
|:--|--:|--:|--:|--:|--:|
| W1 | 75,228 | 0.224% | 75,228 | 0 | 1 |
| W2 | 68,469 | 0.204% | 68,469 | 0 | 1 |
| W3 | 65,834 | 0.196% | 65,834 | 0 | 1 |
| W4 | 42,295 | 0.126% | 42,295 | 0 | 1 |
| **Total** | **251,826** | **approx. 0.188% across 134,217,728 sampled bytes** | **251,826** | **0** | **1** |

All sampled changed pixels show `output = background + 1`; no sampled pixel decreased or changed by more than one ADC count. This is **consistent** with positive, low-amplitude Gaussian pulse profiles and the real-observation injector's truncated-normal de-digitization and integer rounding. A `0.1–0.2%` sampled-byte change fraction **is not** itself equivalent to 0.1–0.2% pulsar flux, calibrated S/N, sensitivity loss, or fractional pulse duty cycle. The four windows have intentionally different groups of five injected pulsars and input parameters; differing percentages are not evidence of a bug.

**Scientific follow-up:** independently phase-tag the changed input-versus-output pixels using the five truth models per window (including DM delays, midpoint A0/A1 acceleration and jerk), and compare coherence to deliberately incorrect frequency, acceleration/jerk signs and DM reference controls. This tests that the pixel changes occur along the prescribed dispersed pulse tracks, rather than merely matching file geometry. Pulse amplitude and folded S/N calibration remain separate.


## Stage 2B independent differential-pixel phase-track pilot

**Status: implementation committed; no actual M62 phase-track results yet.** The
Stage 2A `0.126–0.224%` changed-pixel fractions, all positive +1-count
changes, are consistent with the positive, low-amplitude default Gaussian
pulse model used in the completed pilot. The source implementation
(`injector/pulsar_emission.py`, `injector/signal_injector.py`) generates
nonnegative default profiles, re-digitizes active 8-bit pixels, adds pulse
amplitudes, rounds and clips; the exact change fraction is **not** S/N.

The independent model prediction for the **topocentric five-source pilot**
with `DM_ref=inf`, `ACCEPOCH=0.5`, and default `DM_const=exact` is:

```text
t_eff = t - DM*K_DM/f_channel^2 - (ACCEPOCH * T_obs)
phase(t, f_channel) = (1/P0) * [ t_eff - A0*t_eff^2/(2*c) - A1*t_eff^3/(6*c) ]
```

Here `A0` is in m/s², `A1` in m/s³; the injected clock convention gives
`d f_inst/dt = -(1/P0)*A0/c` at midpoint and
`d² f_inst/dt² = -(1/P0)*A1/c`.
The default `DM` is **additional synthetic DM**, not the total original M62
cluster DM. Absolute phase-origin offsets do not affect first-harmonic
coherence.

The new read-only
[`scripts/verify_m62_injection_phase_tracks.py`](../scripts/verify_m62_injection_phase_tracks.py)
builds a sparse event list of the pixels changed between the corresponding
background and injected filterbank. It independently calculates each truth
phase track (rather than calling the injector's model, PulsarX folds, or the
PULSEJET search code) and tests weighted circular first-harmonic coherence.
It reports comparisons to deliberately incorrect frequency values and,
where applicable, inverted acceleration, jerk, and DM signs and a
zero-motion model. The unit regression
[`tests/test_verify_m62_injection_phase_tracks.py`](test_verify_m62_injection_phase_tracks.py)
contains synthetic narrow-pulse events and analytically tests the
midpoint frequency derivative signs. The actual real-data scientific check
still requires running this code against completed observational injections.

This test samples 32 × 4096 time samples per window from **both** file
versions, i.e. 33.6 MB per file with 256 8-bit channels. It is a
**differential phase-concentration diagnostic**, not a blind search, formal
false-alarm p-value, folded S/N, nor a measurement of completeness.
A correct phase track should show preferential coherence against
off-frequency and physically wrong-model controls; strong coherence can
nevertheless appear for some incorrect signs over short baselines, or be
diluted by five simultaneous sources. Hence the output status is expressly
`DIAGNOSTIC_COMPLETE_NOT_SCIENCE_PASS`, not a blanket physics `PASS`.

**Deploy once on frontend2**, avoiding active Stage 10 files and GPUs:

```bash
cd /home/rnag/PULSEJET_validation/PULSEJET_dev_source
git fetch origin
set -o pipefail
git show origin/dev/polynomial-search:scripts/prepare_m62_injection_phase_tracks.sh | bash
```

The bootstrap exports three committed source/test/job files into the
independent working directory and executes **only synthetic regression
tests** with NumPy from the pinned INCEPTION SIF. It refuses overwrite on
repeated execution. Synthetic test success is a *preflight*, not the
real-data result.

After a green preflight, submit **W1 only** initially:

```bash
WD=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029
sbatch --nodelist=node11 "$WD/scripts/run_m62_injection_phase_tracks.slurm" 1
```

The Slurm launcher requests 4 CPUs, 16 GB RAM and 30 minutes; reads only
the existing completed Stage 6 W1 case and the verified W1 background;
writes a fresh per-job JSON report outside their directories. It uses the
real INCEPTION-Lite SIF only as a NumPy Python environment, **not**
for injection or scientific phase prediction.

After inspecting W1 truth/control coherence and exact source epochs,
expand to W2–W4 on separate job IDs, then move to full quantitative
known-truth folding and, separately, the completed full-Keplerian UCB100
cases. Do not declare Stage 2B complete merely from the synthetic tests,
the existence of a JSON file, or positive one-count pixel changes.


## Stage 2B cluster preflight — synthetic regressions passed

**Operator-observed run on frontend2 (2026-10-29):** the cluster fetched the
`dev/polynomial-search` branch through commit `1f7b28a` and executed the
committed `scripts/prepare_m62_injection_phase_tracks.sh` using
`git show origin/dev/polynomial-search:... | bash`.

Both regressions ran inside the existing INCEPTION-Lite Singularity image and
**passed**:

```text
test_polynomial_derivatives_have_intended_sign ... ok
test_truth_beats_wrong_motion_dispersion_and_frequency ... ok
Ran 2 tests in 0.014s
OK
== Stage 2B PILOT READY (no Slurm job submitted) ==
```

The separate Stage 2B W1 scientific audit **has not yet been run** at this
checkpoint. The regression only checks independently constructed synthetic
pulse events and the expected sign convention. It does not establish that
the real W1 injection is phase coherent. Submit the dedicated
`scripts/run_m62_injection_phase_tracks.slurm 1` on node11 to test W1
read-only, then inspect its truth-vs-control coherence report before
extending to W2–W4.


## Stage 2B W1 real-data differential phase-track pilot — 2026-10-29

**Observed operator result:** the W1 Stage 2B Slurm pilot completed at
`2026-10-29T15:17:27+0100` with the end marker
`STAGE2B PILOT FINISHED`. The independent differential-pixel first-harmonic
analysis reported:

| Source | Truth coherence | Maximum off-frequency control | Truth/off-frequency ratio |
|---|---:|---:|---:|
| M62_W1_I01 | 0.36111 | 0.03895 | 9.27 |
| M62_W1_I02 | 0.21270 | 0.03079 | 6.91 |
| M62_W1_I03 | 0.08546 | 0.01113 | 7.68 |
| M62_W1_I04 | 0.26713 | 0.03136 | 8.52 |
| M62_W1_I05 | 0.06358 | 0.00619 | 10.28 |

**Interpretation:** all five injected sources' prescribed time-frequency
phase tracks exhibit substantially greater weighted phase concentration in
the observed changed-pixel cloud than four deliberately shifted spin
frequencies. This is meaningful positive evidence that the injected
changes follow their intended periods and *combined* polynomial/dispersion
tracks. Because each window contains five sources and these are not
significance-calibrated controls, the ratios are not statistical
significances, recovered S/Ns or formal proof of unique orbital parameters.

**Still required before declaring a fully validated sign/DM convention:**
inspect the W1 `phase_track_result.json` fields
`counterfactual_coherence` for reversed acceleration (I02, I04, I05),
reversed jerk (I03, I04, I05), reversed DM (I02–I05), and no-motion tracks.
Only the shifted-frequency controls were included in the supplied stdout;
those additional control results are saved in the JSON but not yet
reported. Also inspect `event_cloud` change counts and any error log.
No independent folded-S/N or real-data recovery claim follows from this
diagnostic.

**W1 job number:** not included in the provided log fragment. The report
may be located without guessing its ID using
`/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/injection_phase_*/W1/phase_track_result.json`.
Work remains read-only and separate from Stage 10 UCB100.


## Stage 2B W1 counterfactual physics controls — Slurm 66727

**Confirmed operator-provided JSON excerpt, 2026-10-29:**
`/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/injection_phase_66727/W1/phase_track_result.json`

```text
STATUS: DIAGNOSTIC_COMPLETE_NOT_SCIENCE_PASS
EVENT CLOUD: 32 distributed blocks × 4096 time samples
bytes_compared_per_file: 33,554,432
changed_bytes: 75,228
increased: 75,228
decreased: 0
max_abs_delta: 1
```

The following table faithfully records the full **reported counterfactual phase coherence**, with all other injected parameters held at their truth values for each individual alternate model. `truth/control` is a normalized-coherence ratio, **not** a sigma significance, a likelihood ratio, or a fold S/N ratio.

| Source | Truth coherence | Alternate model | Alternate coherence | Truth/control |
|---|---:|---|---:|---:|
| W1 I01 | 0.36111 | No acceleration/jerk/DM sign controls applicable: all zero | — | — |
| W1 I02 | 0.21270 | Acceleration sign reversed | 0.04340 | 4.90× |
| W1 I02 | 0.21270 | No acceleration or jerk | 0.03415 | 6.23× |
| W1 I02 | 0.21270 | DM sign reversed | 0.00521 | 40.84× |
| W1 I03 | 0.08546 | Jerk sign reversed | 0.03554 | 2.40× |
| W1 I03 | 0.08546 | No acceleration or jerk | 0.03540 | 2.41× |
| W1 I03 | 0.08546 | DM sign reversed | 0.00505 | 16.92× |
| W1 I04 | 0.26713 | Acceleration sign reversed | 0.08032 | 3.33× |
| W1 I04 | 0.26713 | Jerk sign reversed | 0.09498 | 2.81× |
| W1 I04 | 0.26713 | No acceleration or jerk | 0.04752 | 5.62× |
| W1 I04 | 0.26713 | DM sign reversed | 0.00165 | 162.30× |
| W1 I05 | 0.06358 | Acceleration sign reversed | 0.00871 | 7.30× |
| W1 I05 | 0.06358 | Jerk sign reversed | 0.01128 | 5.64× |
| W1 I05 | 0.06358 | No acceleration or jerk | 0.00068 | 93.65× |
| W1 I05 | 0.06358 | DM sign reversed | 0.00204 | 31.19× |

**Interpretation:** in W1 the intended source models outperform all **14 tested** counterfactual sign/no-motion/DM controls. The weakest relative preference is the I03 jerk reversal (2.40×) and the strongest is I04 DM reversal (162.30×). These results, combined with the previous correct-versus-shifted-frequency comparisons (6.91×–10.28×), provide strong qualitative evidence that the altered input samples follow the intended **combined** period, additional dispersion, acceleration and jerk phase tracks, and evidence favoring the prescribed signs under the *specific* tested alternatives. Because five injected sources are superposed, and because no null distribution or systematic error budget was calibrated, this remains a differential-pixel diagnostic, not definitive model-parameter identifiability or independent S/N calibration.

**Status:** Stage 2A COMPLETE; Stage 2B W1 pilot OBSERVED / DIAGNOSTIC-COMPLETE, all five source tracks match their expected model preferentially over tested alternatives. Extend to W2–W4, and subsequently validate representative truth-fold coherence, before considering the 20-source polynomial pilot fully validated. Preserve the exact JSON results on the cluster; they contain richer precision and metadata than these copied summary values.

**Reproducibility note:** the W1 changed-byte count of 75,228 agrees with the independent Stage 2A W1 sampled-difference result, including strictly positive +1-count differences. The Stage 2B source and test code are already committed alongside this document.


## Stage 2B W2 submission — Slurm 66787

**Submission recorded (2026-10-29):** the operator submitted the existing
read-only W2 independent changed-pixel phase-track job with

```bash
sbatch --nodelist=node11 \
  /home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/scripts/run_m62_injection_phase_tracks.slurm 2
```

Slurm responded `Submitted batch job 66787`. This establishes **submission
only**, not runtime success, completion, or a W2 scientific pass.
Expected stdout/stderr:
```text
/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/m62_phase_track_66787.out
/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/m62_phase_track_66787.err
```
Expected report on success:
`/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/injection_phase_66787/W2/phase_track_result.json`.
The job audits only completed Stage 6 W2 against its original background;
the active Stage 10 UCB100 campaign remains outside scope.

**Status: SUBMITTED, RESULT PENDING.** When stdout and the JSON are available,
record all five W2 truth versus off-frequency coherence ratios, and the
acceleration/jerk/DM/no-motion counterfactuals, event-cloud statistics, and
any errors. Do not infer success from the existence of a Slurm job ID.
