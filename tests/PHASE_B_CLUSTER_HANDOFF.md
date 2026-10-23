# PULSEJET / INCEPTION-Lite — RESUME CHECKPOINT (2026-10-20)

**Status at pause:** Both Docker Hub images have been built and published. The user plans to return **tomorrow in a new chat in the same ChatGPT project**, beginning with **cluster container verification (Stage 1)**. No Singularity SIF has yet been pulled or executed on the user's A40 cluster as part of these phases. **Do not start by rebuilding or changing the algorithms.**

This is a durable handoff recording established results, the exact next commands, scientific concerns, and milestones. Treat the immutable image tags and past GitHub Actions as the build evidence; branch HEAD may be later than either built image.

## Repository / branch policy

- PULSEJET source: https://github.com/Rouhin1997/PULSEJET_beta/tree/dev/polynomial-search
- INCEPTION-Lite source: https://github.com/Rouhin1997/inception_injection_test_tool/tree/dev/pulsejet-injections
- Preserve PULSEJET historical \`master\` and the original Peasoup acceleration-only, Keplerian and circular search methods; preserve original INCEPTION fork's \`main\` and upstream Python injection physics.
- PULSEJET development branch HEAD at checkpoint (before this handoff commit): \`bbc60c01cf647a6a9e710fc4189325dc8d415f00\`.
- INCEPTION-Lite development branch HEAD at checkpoint: \`c5cf8728d4bd504ce3a958026519af4bd769a50f\`.
- Development work and tests only on named \`dev/*\` branches. Do not overwrite working images or claim results not yet measured.

## Images already published and tested — pin these exact versions

**PULSEJET (CUDA search + PulsarX):**

    docker://rouhin1997/pulsejet:dev-polynomial-513e80d1ace21868fd3d3d37734bcd79782abce3

- Source commit in image: \`513e80d1ace21868fd3d3d37734bcd79782abce3\`.
- Successful GPU-code compilation in GitHub Docker CI (not yet A40 runtime): https://github.com/Rouhin1997/PULSEJET_beta/actions/runs/39408031261
- OCI manifest-list digest: \`sha256:7d60ac506e48af31ad9dfbb4cb9c2a206d585156ce56333c818ef8ecf9b9a53c\`.
- Includes compiled CUDA 12.3.2 \`sm_86\` PULSEJET, dedisp, \`peasoup\`, PulsarX \`psrfold_fil\` / \`psrfold_fil2\`, filterbank utilities, XML-to-candidate converter \`pulsejet_xml_to_pulsarx\`, Python scientific tools.

**INCEPTION-Lite (injection + actual PulsarX folding; extends PULSEJET base):**

    docker://rouhin1997/pulsejet:inception-lite-5a9cd1c9b252ffd1797575267c4528fa5b8e81c5

- Source commit in image: \`5a9cd1c9b252ffd1797575267c4528fa5b8e81c5\`.
- Successful integrated Docker build, real synthetic injection, actual \`psrfold_fil\` folding, archive and PNG rendering test: https://github.com/Rouhin1997/PULSEJET_beta/actions/runs/39423881379
- OCI manifest-list digest: \`sha256:18ea34b27e387e4cfebe987b19cdf0b8cf39fd11382bf996b37e6fbe9305d29f\`.
- Native PulsarX made a nonempty \`.ar\` archive; its PlotX failed to output PNG in headless CI. INCEPTION-Lite rendered a valid fallback PNG *from the real folded archive*; that functionality was tested. It is a basic phase-profile quicklook, not a scientific recovery metric.
- Provides \`python3 -m inception_lite --config plan.json --perform-folds yes|no\` and \`--dry-run\`, plus single/together/separate/grid/random experiments. Python CLI is inside the image. Original \`injector/\` implementation preserved.
- Contains PULSEJET as the base, but for independent regression testing use distinct SIFs pinned to the tags above. Mutable \`dev-polynomial-latest\` / \`inception-lite-latest\` are also on Docker Hub; prefer immutable commits.

**No Docker rebuild needed for first cluster preflight.** Docker compile/test is not GPU runtime verification.

## Cluster environment from earlier user checks

- HPC uses SingularityCE \`3.11.3-1.el7\`, NVIDIA driver \`545.23.08\`, two NVIDIA A40 GPUs (~46 GB each), CUDA driver supports CUDA 12.3. Image uses \`sm_86\`.
- GPUs may require access through an allocated compute node / SLURM; do not assume login nodes see the A40s.
- No prior usable SIF on this cluster when the project was paused; check that scratch/storage has space for OCI→SIF conversion, caches and temporary files.
- Verify the compute node has AVX2/FMA CPU features because PulsarX was compiled using \`-mavx2 -mfma\`.
- Use read-only SIFs, no writable sandbox required. For GPU PULSEJET commands use Singularity \`--nv\`; CPU injection/folding does not require \`--nv\`.
- If scratch binds are not automatically visible, set \`--bind /path/on/host:/path/on/host\`. Avoid recording private host paths in source configuration.
- Cluster runtime has NOT yet been tested with either SIF.

## Exact starting point: STAGE 1 — pull + verify two containers

Run on the appropriate cluster storage or compute allocation (replace working directory if needed):

    singularity pull pulsejet_dev.sif \
      docker://rouhin1997/pulsejet:dev-polynomial-513e80d1ace21868fd3d3d37734bcd79782abce3

    singularity pull inception_lite.sif \
      docker://rouhin1997/pulsejet:inception-lite-5a9cd1c9b252ffd1797575267c4528fa5b8e81c5

    singularity exec --nv pulsejet_dev.sif \
      bash -lc 'nvidia-smi; peasoup --help'

    singularity exec inception_lite.sif \
      python3 -m inception_lite --help

    singularity exec inception_lite.sif \
      psrfold_fil --help

Optionally inspect versions, \`nvidia-smi\`, \`nvcc --version\`, \`lscpu | grep -i -E "avx2|fma"\`, \`df -h\`; test with **one A40** first. Ask the user to share actual output/errors and host storage conventions before composing production-sized commands.

**Stage 1 exit criteria:** successful SIF conversion, runtime startup and CUDA dependency initialization, required executables located, successful data bind/write test, no CPU instruction incompatibility. Do not confuse \`--help\` with exercising a real CUDA kernel.

## PULSEJET development recap — what is already completed

Detailed reports:
- https://github.com/Rouhin1997/PULSEJET_beta/blob/dev/polynomial-search/tests/PHASE_A_FINDINGS.md
- https://github.com/Rouhin1997/PULSEJET_beta/blob/dev/polynomial-search/tests/STEP2_FINDINGS.md
- https://github.com/Rouhin1997/PULSEJET_beta/blob/dev/polynomial-search/tests/PHASE_B_TOOLBOX.md

- Phase A shared midpoint acceleration–jerk arrival-time convention and independent CPU time-series injection validated. \`include/transforms/polynomial_timing.hpp\` and dedicated \`polynomial_resampler.hpp\` connect the CUDA polynomial path. Template reader validation and XML metadata refined; input a, j, dt double through resampler, candidate metadata still float.
- 95 C++ CPU assertions and 16 Python static wiring checks at Phase A baseline; later diagnostic/converter tests also passed CI. PULSEJET Docker CUDA compilation and PulsarX CLI smoke checks passed CI, but no A40 kernel evaluation on cluster.
- Polynomial model for output index i, FFT length N, sample interval dt, acceleration a and jerk j, speed of light c:

      i_in = i + [a dt/(2c)] * (i-N/2)^2 + [j dt^2/(6c)] * (i-N/2)^3.

  Positive a/j means added line-of-sight delay, relative v=0 at segment midpoint. Nearest-even sample rounding and zero padding on GPU; intended for nonrelativistic, monotonic short-duration polynomial approximation, not full Keplerian motion.
- Historical polynomial acceleration formula \`i*(i-N/2)\` differs by a *linear* timing term, which a frequency search may absorb. Old-vs-new fixed-frequency Fourier coherence alone does NOT establish a drop in maximum-search S/N. Scan/re-optimize frequency and compare peak detections and biases before quantitative sensitivity claims.
- Candidate-distillation diagnosis: currently active polynomial branch uses \`Template_Bank_Polynomial_DopplerDistiller\` per DM; user-created \`Template_Bank_Polynomial_Distiller\` exists but is inactive. Cross-DM DMDistiller and global harmonic grouping also affect counts and can produce false merges. \`--candidate_diagnostics\` logs pre/post counts but has not been verified in actual GPU search. Keep upstream algorithms unchanged until injected observations demonstrate defects; distinguish top-level representatives from nested associations.

## INCEPTION-Lite recap — what is already completed

- Documentation: https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/INCEPTION_LITE.md
- Python-driven, NO Nextflow or MPIfR-specific cluster dependencies for the new runner. \`mode: together\` combines multiple injected sources into one .fil; \`separate\`, \`grid\`, and \`random\` generate distinct .fil observations. Explicit input file path and output directory in JSON; \`--dry-run\` prints cases only, no injection or writes. Optional \`--perform-folds yes|no\` overrides JSON flag.
- Supports SIGPROC \`.fil\` only; direct search-mode \`.fits\` injection is not implemented.
- Requires explicit random seed and explicit \`frame\` (use \`topo\` for initial tests); for validated simple a/j experiments use \`ACCEPOCH: 0.5\` and do **not** also specify \`PEPOCH\` (source epoch could otherwise be double-shifted).
- Original injector models first-order Doppler phase \`phi=f0*[tau-a*tau²/(2c)-j*tau³/(6c)]\`; truth-fold F1=-a*f0/c and F2=-j*f0/c. Phase A PULSEJET exact inverse arrival-time mapping has order (v/c)^2 differences from this first-order model. Quantify for extreme a/j tests.
- Real injection tests passed: seed reproducibility, unchanged filterbank metadata, single/multiple injected sources, coherent stationary profile, deliberate extreme-jerk sign/coherence regression. Real PulsarX on Docker produced \`.ar\` and archive-derived \`.png\` eye-check profile.
- Folding known truth is NOT proof of PULSEJET recovery. For scientific recovery, compare an **independent truth fold** with a **recovered-candidate fold**.
- A format/epoch-aware PULSEJET XML → PulsarX 7-column candidate file converter already exists, but first cluster search must verify its handling of real XML and exact FFT segment boundaries.

## Ordered remaining work and exit gates

### STAGE 1 — Cluster runtime preflight (next session, about 1–2 hours if straightforward)

Pull pinned SIFs, verify CPU/GPU runtime, mounts, A40 visibility, nvidia-smi/peasoup/psrfold_fil. Resolve Singularity cache and scratch complications.

### STAGE 2 — GPU polynomial kernel parity (about 3–6 hours if no major driver/build surprise)

A purpose-built GPU-vs-independent CPU harness is STILL REQUIRED; no existing end-to-end GPU proof. Compare output sample indices and values for a=j=0, both signs of a and j, mixed motion, negative/out-of-bounds indices and endpoint zero padding. Verify rounding, numerical tolerances and reproducibility. Test frequency scanning (do not overinterpret a single fixed frequency). Record exact binary/tag and GPU.

### STAGE 3 — First full synthetic injection → PULSEJET search → fold recovery (about 4–7+ hours; initial pilot)

Use a small compatible SIGPROC input (.fil), high-S/N pulsar (baseline a=j=0, then ±a, ±j, then mixed). Observe the exact Tobs, tsamp, FFT size and epoch. Make a tiny 2-column \`acc jerk\` polynomial bank containing the injected values plus near neighbors; full scientifically designed bank generator not yet validated. Run a noise-only control. Enable \`--candidate_diagnostics\`. Locate real PULSEJET \`overview.xml\`; convert it via \`pulsejet_xml_to_pulsarx\`; validate the converter's XML schema against actual runtime output before interpreting failures. Fold EXACT SAME searched segment, using correct midpoint \`--pepoch\`. Compare truth and recovered fold coherence, spin frequency, DM, acceleration, jerk and measured S/N. Beware differences in spin epoch and first-order Doppler model.

### STAGE 4 — Small A/J/DM/SNR sweeps (pilot possible in 2–3 days; full survey later)

Use explicit seed, source truth manifests, controlled parameter grids at multiple lengths/periods, with a/j positive and negative. Search with original acceleration-only mode and polynomial mode at comparable parameter coverage and false-positive settings. Measure detection fractions, maxima after Fourier-frequency optimization, fold S/N, f/DM/a/j bias, wall time and GPU memory. Distinguish template discretization/coverage from algorithmic loss. A rigorous bank mismatch/coverage generator and calibrated sensitivity analysis are not finished.

### STAGE 5 — Candidate grouping/distillation diagnosis

Use multi-source injections with intentionally close spin frequencies and distinct motion. Inspect \`--candidate_diagnostics\` before and after template/DM/harmonic grouping and candidate limit; track unique recovered source IDs, false merges, splits, duplicate associations. Only change polynomial-specific grouping if data justify it, retain original Peasoup methods as regression baselines.

### STAGE 6 — Scientific-grade comparison & scale-up

Large sample/population completeness, S/N threshold curves and uncertainties, acceleration-only vs polynomial vs (optionally later) PRESTO independent baselines, calibrated runtime, memory use, scaling, real survey search and publication-quality figures. Needs substantial experiment design and reproducibility: not honestly complete in 10–18 working hours.

## Realistic scheduling

The user asked whether 2–3 days × 5–6 hours/day (=10–18 h) can complete *all* stages. **Best case:** Stages 1–3 and a small Stage 4 pilot if no GPU/build/epoch surprises. **Unlikely:** statistically robust Stages 4–6; full candidate refinement, false-alarm/sensitivity curves and real survey benchmarks generally require additional days/weeks. Do not equate an initial proof-of-principle with scientifically completed benchmarking.

## Data provenance, reproducibility and caution

For EVERY experiment preserve:
- image version/tag/digest, GitHub source SHA, GPU model and driver, SLURM job ID
- input .fil header, duration, tsamp, MJD, FFT/padding/segment boundaries, DM list
- injection JSON, resolved manifest/seed, injected truth F0/DM/a/j, source ID
- template bank and search flags, \`--candidate_diagnostics\` output, XML result
- truth fold and recovered fold archive+PNG, profile/S/N, timings, failure modes.

Open technical questions to revisit AFTER first tests:
- old-vs-new polynomial mapping can shift recovered frequency without reducing optimized S/N;
- legacy \`get_segment_pepoch_accel_search\` correctness for multi-segment data;
- GPU parity/nearest-even rounding/boundary treatment;
- some old PulsarX \`get_ffold\` reported-frequency expression appears inconsistent with its correct cubic phase; independent injection fold check needed;
- output a/j candidate precision float;
- XML conversion exact input schema + time/FFT-segment matching;
- polynomial template coverage/generator not yet audited;
- candidate groupings false merges/splits, resource use and independent external comparison.

## What the user should say in the next chat

> Resume the PULSEJET + INCEPTION-Lite project from the 2026-10-20 cluster handoff. We are starting Stage 1: pull and verify both immutable Singularity SIFs on my A40 cluster. Read the GitHub \`tests/PHASE_B_CLUSTER_HANDOFF.md\` on the PULSEJET \`dev/polynomial-search\` branch and guide me through the first verification commands, one at a time.

**Checkpoint rule:** No unpublished GPU or large-population results should be implied by this note; it is a plan and verified history, not completion of all phases.


## Live cluster progress: 2026-10-23

User successfully pulled BOTH pinned SIF images on frontend2 to
\`/home/rnag/PULSEJET_validation/images/\`, each reported ~4.0 GB:

- \`pulsejet_dev.sif\`, created 09:45.
- \`inception_lite.sif\`, created 10:07.

Host reports SingularityCE 3.11.5-1.el7; node2 has 2×A40 visible,
driver 545.23.08, CUDA supported 12.3. \`singularity exec --nv
pulsejet_dev.sif nvidia-smi -L\` saw both GPUs. The existing
\`peasoup --help\` showed \`-P\` and \`--candidate_diagnostics\`;
\`which\` found \`/usr/local/bin/peasoup\`,
\`/usr/local/bin/psrfold_fil\`, and
\`/usr/local/bin/pulsejet_xml_to_pulsarx\`.
\`ldd\` resolved \`libcudart.so.12\`, \`libcufft.so.11\`,
and \`libdedisp.so.1\`. This is environment/binary preflight,
**not GPU kernel parity nor injector SIF execution verification**.

User supplied a real MeerKAT filterbank for subsequent controlled tests:

    /archive1/ridolfi/DATA/MeerKAT/ALL_TRAPUM_GC_CENTRAL_BEAMS/M62_18U-trapum-pgb_cfbf00001sub_CB.fil

Never inject directly into this archive path; use a copy or small selected
segment after verifying header/permissions/size.

**New Stage 2 test code committed exclusively to dev/polynomial-search:**

- \`tests/test_polynomial_cuda_parity.cu\`: 13 cases, independent
  long-double CPU source-time reference, zero motion, ±acc, ±jerk,
  mixed-sign combinations, source-index under/overflow, nearest-even
  sampling, zero padding; compares every output against **actual**
  compiled CUDA production resampler.
- \`scripts/run_polynomial_cuda_parity.sh\`: invokes the CUDA 12.3 nvcc
  within the pinned existing SIF and links against the already-built
  \`/software/peasoup/obj/kernels.o\` binary. Does not rebuild PULSEJET
  or alter the SIF. Runs test on A40 and writes a parity log.
- These tests are **not yet executed**. First run will verify whether
  the SIF retained \`kernels.o\` and whether the CUDA parity harness
  compiles successfully.

Next cluster steps: verify INCEPTION-Lite python CLI inside SIF, clone
the explicit \`dev/polynomial-search\` source branch to host shared space
(from frontend2 if necessary), execute
\`bash scripts/run_polynomial_cuda_parity.sh
/home/rnag/PULSEJET_validation/images/pulsejet_dev.sif
/home/rnag/PULSEJET_validation/stage2\` on node2/SLURM-approved GPU
allocation. Inspect all output before declaring Stage 2 passed.


## Live Stage 2 result: 2026-10-23

GPU compute node `node2.cluster` successfully ran
`bash scripts/run_polynomial_cuda_parity.sh` on the
`dev/polynomial-search` host checkout
(`ab5c36277ed44718c203bbfd33c5cfd146fc4e93`), using the
immutable `pulsejet_dev.sif`. The runner linked the original production
`/software/peasoup/obj/kernels.o` (2.0 MB in SIF) and compiled the test
against it with container nvcc; **the production binary was not rebuilt**.

- GPU: NVIDIA A40, compute capability 8.6; 2 detected.
- Input: N=32768, sample interval 0.016 s; unique positive float sample data.
- 13 scenarios passed: zero motion, ±acc, ±jerk, mixed sign combinations,
  strong signs/zero padding.
- **425,984 compared samples; exactly 0 mismatches.**
- Zero padding was observed for positive and negative out-of-range
  source indices, and a nearest-neighbor index that rounded beyond the end.
- Every case reported `near-half=0`: this does **not yet explicitly
  validate exact tie-to-even rounding boundary behavior**. Add an
  intentional boundary/tie-focused test before marking Stage 2 exhaustive.
- Run log:
  `/home/rnag/PULSEJET_validation/stage2/polynomial_cuda_parity.log`.

This proves pointwise CPU/GPU agreement for the tested configurations,
not the full injection/search/folding chain, sensitivity, FFT recovery,
candidate grouping, or candidate-parameter accuracy. Those still await
Stages 3+.


## Stage 2 final A40 validation: 2026-10-23

INCEPTION-Lite SIF successfully ran `python3 -m inception_lite --help`,
and `which psrfold_fil` returned `/usr/local/bin/psrfold_fil` on
`frontend2`.

The user fast-forward pulled `dev/polynomial-search` to
`10aa6fd0cab97246e830b5bb292733f1e16246d0` and reran
`bash scripts/run_polynomial_cuda_parity.sh` on the A40 of
`node2.cluster`, linking the *unchanged production CUDA* `kernels.o`
from `pulsejet_dev.sif`. Results:

- **PASS 15/15 cases; 491,520 sample comparisons, 0 mismatches.**
- Includes zero motion; positive/negative acceleration and jerk;
  mixed-sign combinations; underflow/overflow/rounded-out zero padding;
  positive/negative exact nearest-even tie cases.
- Exact half-sample cases: 16,384 per sign, 32,768 total
  (`exact-half=16384` for each of the last two test cases).
- The extreme `a=±299792458 m/s²` values in tie tests are mathematical
  stress cases, not astrophysical parameter choices.
- Log path: `/home/rnag/PULSEJET_validation/stage2/polynomial_cuda_parity.log`.
- **Stage 2 sample-level kernel parity gate passed.** No scientific
  inference about search sensitivity, recovered candidates, template
  coverage, false grouping or full-chain precision is yet justified.

Next Stage 3: start with a small, wholly synthetic SIGPROC noise
filterbank and a bright stationary pulsar injection for baseline
search/fold recovery, then +/- acceleration and jerk, then test a
read-only copied/truncated segment of the M62 archive filterbank.


## Stage 3 blocker: malformed generated SIGPROC header (2026-10-23)

First synthetic Stage 3 data (generated on node2 using published
`inception_lite.sif`):

    /home/rnag/PULSEJET_validation/stage3/noise_baseline.fil

Command used 1048576 samples × 16 8-bit channels, 0.00025 s,
seed 771. File 16,777,475 bytes. First injection attempt (stationary
P=0.02 s, DM=10, SNR=80, a=j=0; truth folds enabled) stopped
**BEFORE injection or output directory creation** with
`Invalid SIGPROC header string length`.

Read-only diagnostic showed `HEADER_START`, `source_name`,
`telescope_id`, `machine_id`, `data_type`, followed by
`tstart` at offset 109 with an impossible 8-byte float and next
field misaligned. Root cause identified in INCEPTION-Lite
`make_filterbank.py`: `argparse` defaults `--tstart=60000` and
`--fch1=1400` remain Python ints; writer previously chose 4-byte
int serialization by `isinstance(value, int)` even though
SIGPROC header requires 8-byte float for **both** fields. Header
therefore 8 bytes too short (259 instead of 267); data untouched.

Fixed in **INCEPTION-Lite `dev/pulsejet-injections` only**:
- `inception_lite/make_filterbank.py`: serialize by SIGPROC field
  wire types rather than Python value type; float defaults set to
  60000.0/1400.0.
- `tests/test_inception_lite.py`: new CLI defaults/header parser
  regression and explicit integer-typed float field regression.
- Fix source commit `c99d8fe96fd4a09d6d18156f422bda91ceb81d66`;
  test source commit `076de52ae19aea210360f03694794e1eb98ff04d`.
- Regression tests have not yet been executed and the published
  immutable SIF still has the original source. **No new SIF built yet.**

Safe immediate workaround inside existing SIF is to regenerate into
a NEW path with explicitly passed CLI options
`--tstart 60000.0 --fch1 1400.0`; argparse will produce floats and
the old generator then correctly emits 8-byte values. Check parsed
header independently before attempting to inject. Preserve original
malformed file as diagnostic evidence, do not overwrite.

Next: make `noise_baseline_fixed.fil`, parse it, adapt baseline JSON
to new input path, then perform actual injection+truth fold. Do not
confuse the software fault with PULSEJET GPU kernel parity, which
previously passed 15/15.


## Stage 3 first successful synthetic injection (2026-10-23)

Initial 20 ms stationary test configuration:
`/home/rnag/PULSEJET_validation/stage3/baseline_clean.json`.
Noise input:
`/home/rnag/PULSEJET_validation/stage3/noise_baseline_fixed.fil`
(N=1048576, 16 channels, tsamp=0.00025 s, duration=262.144 s,
SIGPROC tstart=60000.0, fch1=1400 MHz, foff=-1 MHz,
nbits=8, header length=267 bytes).

Parameters: `PSR_BASELINE`, `P0=0.02` s (50 Hz), DM=10,
SNR target=80, A0=0, A1=0, duty cycle=0.06, `frame=topo`,
`ACCEPOCH=0.5`, seed 20261023. `--dry-run` passed.

The initial actual injection into the corrected filterbank failed
after creating `baseline_run/case_0001`, because Singularity exposed
user-installed `/home/rnag/.local/lib/python3.10/site-packages/pandas`
which was incompatible with system NumPy 1.21.5; injector's
`inject.log` documented the traceback. Verified that launching
`singularity exec --cleanenv inception_lite.sif
env PYTHONNOUSERSITE=1 python3 -c 'import numpy, pandas'`
isolates the container site packages: NumPy 1.21.5 and pandas 1.3.5
at `/usr/lib/python3/dist-packages`. Preserve both failed directories;
do not overwrite.

Created `baseline_clean.json` targeting a new output root
`/home/rnag/PULSEJET_validation/stage3/baseline_run_clean`, then ran:

    singularity exec --cleanenv \
      "$HOME/PULSEJET_validation/images/inception_lite.sif" \
      env PYTHONNOUSERSITE=1 python3 -m inception_lite \
      --config "$HOME/PULSEJET_validation/stage3/baseline_clean.json" \
      --perform-folds yes

**Reported SUCCESS** and created
`baseline_run_clean/case_0001/noise_baseline_fixed_baseline_stationary_case_0001.fil`.
The wrapper's success is emitted *after* `fold_truth`, which checks
PulsarX created an archive and, if necessary, generates a plot from it.
Next user action: list and inspect output products, fold log/archive/
profile, then independent PULSEJET search. No actual PULSEJET search
or frequency/DM recovery measurement yet. Source code changes only on
development branches; immutable SIFs unmodified.


## Stage 3 first PULSEJET GPU full search: 2026-10-23

The user ran the pinned PULSEJET SIF on node2 (one A40 via `-t 1`),
searching the successfully injected stationary synthetic filterbank:

    cd /home/rnag/PULSEJET_validation/stage3
    singularity exec --nv "$HOME/PULSEJET_validation/images/pulsejet_dev.sif" peasoup \
      -i "$PWD/baseline_run_clean/case_0001/noise_baseline_fixed_baseline_stationary_case_0001.fil" \
      -o "$PWD/search_stationary_01" \
      --dm_file "$PWD/dm_baseline.txt" \
      -P "$PWD/polynomial_stationary.txt" \
      -t 1 -n 4 -m 7 --min_freq 20 --max_freq 100 \
      --candidate_diagnostics -v 2>&1 | tee search_stationary_01.log

DM list: exactly `10`. Polynomial bank: exactly `0 0`.
Injection truth is `P0=0.02 s` / `f0=50 Hz`, `DM=10`, a=j=0,
target S/N 80. **Independent blind frequency recovery NOT YET checked.**

**GPU execution completed successfully**, including dedispersion,
preprocessing/rednoise, CUDA polynomial resampling, FFT, normalisation,
harmonic summing, peak extraction, all distillation, output writing.
Log ended `all done`.

- Effective filterbank samples: 1,048,576, dt=0.00025 s; search FFT
  size: 1,048,576.
- Dedispersed samples transferred to GPU: 1,048,574; remaining 2
  zero-padded. PULSEJET printed benign-looking input segment overrun
  adjustment warning (`Segment end sample: 1048576`).
- Actual printed worker DM processing time: 0.163024 seconds;
  **not** a validated whole-program end-to-end benchmark.
- 1 DM trial and 1 polynomial template trial.
- Candidate diagnostics: 42 raw spectral detections, 3 after per-template
  harmonic distillation, 3 before/after per-DM polynomial distillation,
  3 after cross-DM and final harmonic distillation, 3 at output candidate
  limit, 0 nested associated nodes.
- Output root: `/home/rnag/PULSEJET_validation/stage3/search_stationary_01`.
- Search stdout/stderr: `/home/rnag/PULSEJET_validation/stage3/search_stationary_01.log`.
- **Next mandatory action:** inspect actual candidate records
  (`overview.xml` and candidate files) to verify if one candidate
  lies at ~50 Hz and contains correct DM/a/j. Do not claim pulsar
  recovered solely from counts.
- After candidate check, use XML-to-PulsarX converter, fold matching
  searched segment and compare to truth fold. Preserve intermediate
  files and avoid modifying production/main branches.


## Stage 3 first blind frequency recovery: 2026-10-23

User inspected `/home/rnag/PULSEJET_validation/stage3/search_stationary_01/overview.xml`,
which lists candidate 0 with:

- `period = 0.0199999252322131 s` (injected 0.0200000000000000 s,
  discrepancy ≈74.77 ns; recovered frequency ≈50.000187 Hz);
- `dm=10`, `acc=0`, `jerk=0`, `nh=3`;
- **reported search S/N = 83.4094009399414**, injection input S/N target 80.
  These definitions need not be numerically identical;
- all 3 final candidates survived later distillation at this single
  DM/template point; top candidate is the injected ~50 Hz source.
- XML metadata `polynomial_reference_epoch=segment_midpoint`,
  `polynomial_reference_velocity=zero`,
  `polynomial_sampling=nearest_neighbour`,
  `segment_start_sample=0`,
  `segment_nsamples=1048576`,
  `segment_pepoch=60000.0015170371` (full 262.144-second midpoint).
  One DM `10`, bank one row `0 0`, GPU NVIDIA A40, CUDA 12.3.

**FIRST INDEPENDENT BLIND SPIN-FREQUENCY RECOVERY ACHIEVED** from the
synthetic INCEPTION-Lite injection through actual PULSEJET GPU search.
Important scientific qualification: DM, acceleration and jerk
were fixed to injected truth by trial files; do not claim these
parameters were blindly recovered or sensitivity/false alarm calibrated.

The user's PulsarX truth profile PNG (user inspected/uploaded) shows
a clear single narrow pulse at phase ~0.56; baseline ~-2600 archive
units, peak ~11500 (approx); integrated pulse morphology coherent.
Truth fold is separate from recovery fold, yet to compare.

NEXT: convert actual PULSEJET overview.xml using installed
`pulsejet_xml_to_pulsarx` to `search_stationary_01/recovered_top.cands`
and manifest with `--min-snr 7 --limit 1`, inspect the 7-column
candidate and its epoch. Then fold exactly matching observation and
compare recovered fold to known-truth fold.


## Stage 3 recovered-candidate fold execution: 2026-10-23

The user successfully converted top candidate from
`search_stationary_01/overview.xml` using the installed
`pulsejet_xml_to_pulsarx` to:
- `search_stationary_01/recovered_top.cands`
- `search_stationary_01/recovered_top.json`
The converter reported midpoint epoch MJD `60000.0015170370971`.
7-column candidate:
`0 10 0 50.00018692016603 -0 0 83.4094009399`.

User invoked CPU PulsarX directly in `pulsejet_dev.sif`:

    psrfold_fil --candfile "$PWD/search_stationary_01/recovered_top.cands" \
      --pepoch 60000.0015170371 \
      --template /usr/local/share/pulsarx/meerkat_fold.template \
      --nosearch -b 64 --nsubband 16 \
      -f "$PWD/baseline_run_clean/case_0001/noise_baseline_fixed_baseline_stationary_case_0001.fil" \
      -o "$PWD/search_stationary_01/recovered_fold"

`psrfold_fil` printed preprocessing, folding, candidate info, archive
creation, PNG generation and `done!`. PGPLOT emitted:
`foreground level = background level`,
`invalid x limits in PGSWIN: X1 = X2`, same graphical warnings as
truth fold. This establishes recovered-parameter folding **execution**,
not yet scientifically verified archive morphology. Next step: list
`search_stationary_01` outputs to locate the exact .ar path, produce
an archive-derived PNG using the INCEPTION-Lite plot helper if needed,
and compare recovered profile against earlier truth-folded profile.
No blind DM or orbital-parameter recovery yet.


## Stage 3 stationary baseline recovery profile: PASSED (2026-10-23)

User completed the recovered archive rendering successfully using
`inception_lite.fold_plots.plot_folded_archive` in pinned INCEPTION SIF.
Output:
`/home/rnag/PULSEJET_validation/stage3/search_stationary_01/recovered_folded_profile.png`,
44,299 bytes. Recovered PulsarX archive:
`search_stationary_01/recovered_fold_60000.0000000000_cfbf00000_00001.ar`,
95,040 bytes; truth archive also 95,040 bytes.

The user uploaded both PNGs. Visual side-by-side comparison:
- Recovered fold has a strong, narrow single peak at phase ~0.56,
  matching the injection truth fold's peak phase and morphology;
- recovered peak ~10,100 archive units vs truth ~11,500 units (visual
  estimates, not directly comparable calibrated fluxes);
- no substantial visual broadening; off-pulse baseline near -2,500
  to -3,000 archive units in both;
- recovered candidate f0=50.00018692016603 Hz, truth f0=50.0 Hz,
  giving frequency offset 0.000186920166 Hz and phase drift ~0.049 cycles
  across 262.144 s (a possible reason for modest recovered peak decrease,
  *not* quantitatively proved).

**STAGE 3 STATIONARY BASELINE RECOVERY PASSED**: real synthetic injection,
independent NVIDIA A40 PULSEJET polynomial search (blind frequency
discovery), XML-to-PulsarX conversion and independent `--nosearch`
PulsarX fold produces a coherent near-truth pulse. User confirmed
visual success. Do not claim rigorous numerical profile-match quality
or blind DM/acceleration/jerk recovery; those are still untested.

Next planned scientific test: isolated injected nonzero acceleration,
zero jerk, perform a template search including but not fixed to injected
acceleration, test detection and recovered candidate against truth.
Preserve simple one-command-at-a-time cluster workflow; then progress
to mixed acceleration plus jerk and study control cases. All development
writes stay on `dev/polynomial-search` or `dev/pulsejet-injections`.


## Validation progression agreed after stationary success (2026-10-23)

User approved step-by-step validation order:
1. Controlled **nonzero acceleration, zero jerk** synthetic injection and
   search across competing acceleration templates, compare recovered
   candidates and truth folds.
2. Controlled **nonzero jerk** injection, jointly varying acceleration
   and jerk in the search bank, measure losses, aliases and grouping.
3. Inject into actual telescope observational SIGPROC `.fil` files
   (preserve originals; verify channelization, RFI, header, masks,
   dedispersion, recovered folds).
4. Full **template-bank-driven controlled tests**, with known injected
   parameters, mismatch, S/N, sensitivity and distillation checks.
5. Fully blind **template-bank search** over DM, acceleration and jerk
   (spin frequency always unknown to PULSEJET), completeness,
   contamination and performance studies.

Explicit user query verified against immutable deployed PULSEJET image
source commit `513e80d1ace21868fd3d3d37734bcd79782abce3`:
`src/pipeline_multi.cu` routes `-P` through
`run_polynomial_time_domain_resampler`, constructs
`pulsejet::PolynomialTimeDomainResampler` (implemented in
`include/transforms/polynomial_resampler.hpp`), calling
`device_resample_acc_jerk` CUDA kernel. Per-DM polynomial candidate
stage uses **`Template_Bank_Polynomial_DopplerDistiller`**;
`Template_Bank_Polynomial_Distiller` also exists but is *not active*.
Per-template harmonic distillation, cross-DM DMDistiller and final
harmonic distiller are original Peasoup infrastructure. Stationary
one-bank test does not establish cross-template distillation correctness.

Next planned injection: use existing valid
`stage3/noise_baseline_fixed.fil`, source `P0=0.02` s, DM=10,
target S/N=80, a=+150 m/s², j=0, same base noise file and seed;
write `stage3/accel_a150.json`, `output_dir` new
`stage3/accel_run_a150`, source ID `PSR_ACCEL_150`, retaining fold
settings. Do not reuse previously occupied output directories.
Follow user's **one command/step at a time** preference.


## USER REQUIREMENT: Distillers are third-party; do not modify without prior discussion and approval

User explicitly stated (2026-10-23) that they did not author the polynomial
candidate distiller; it was written by someone else and may have been tuned
for a different coding/scientific application. **Do NOT modify the behavior,
source, matching thresholds or pipeline wiring of either
`Template_Bank_Polynomial_Distiller` or
`Template_Bank_Polynomial_DopplerDistiller`, or related upstream
distillers, without FIRST discussing the concrete proposed change and
obtaining user's explicit approval.** This instruction applies even if
injection tests reveal seemingly incorrect behavior. Keep original source
intact; add only non-algorithmic diagnostic observations or external
analysis as needed.

Next test order: (1) nonzero acceleration/zero-jerk injection and bank
search; (2) nonzero acceleration/nonzero jerk injection and bank search;
(3) evaluate unchanged active Doppler-distiller's before/after retention,
merges, candidates and relevant S/N/parameter biases. Discuss outcomes
with user before any modification.

## Stage 4 acceleration candidate identified (23 Oct 2026)

The +150 m/s2, zero-jerk synthetic injection was searched using nine polynomial templates with acceleration -300 through +300 m/s2 in steps of 75, DM fixed to 10. GPU search succeeded: 386 raw detections, 77 after harmonic distillation, 27 after Doppler distillation, 50 nested associations. Top surviving candidate (ID 0) recovers f = 50.000186920166 Hz, acceleration +150 m/s2, jerk 0, DM 10, S/N 75.44, nassoc 11. This is correct recovery on the tested grid, not a demonstration of free acceleration estimation. Critically, the deployed output_stats.hpp writes only nassoc for each representative; the XML does not serialize associated candidate parameter records, and candidate binary output is commented out in pipeline_multi.cu. Therefore the 11 associations cannot be identified from overview.xml alone; to characterize per-template S/N and grouping without modifying code, run single-template control searches on the same injected file and compare results. Do not modify either third-party distiller without prior user discussion and approval.


## Stage 4 acceleration correction vs uncorrected control (2026-10-23)

Using exactly the SAME injected a=+150 m/s², j=0, P0=20 ms,
DM=10 synthetic filterbank, the user ran a one-template
**incorrect, stationary control** PULSEJET GPU search (a=0,j=0) with
the otherwise identical settings to the previous nine-template
search. Output directory:
`/home/rnag/PULSEJET_validation/stage3/search_accel_zero_control`.

GPU execution completed successfully: 1 DM, 1 polynomial template,
37 raw spectral detections, 7 after per-template harmonic grouping,
7 after polynomial Doppler distillation and 7 at final output
(0 nested associations). Most significant candidate in
`overview.xml`: `f=50.000187 Hz`, a=0, **S/N=52.76**.
The matching candidate from the nine-template search had
`f=50.000187 Hz`, a=+150, **S/N=75.44**, rank #1, with 11
nested associated nodes.

Correct template increases recovered PULSEJET search S/N by
`(75.44/52.76-1)≈43.0%` (factor ≈1.43). The wrong stationary
template still detects the injected signal: this is not a complete
dropout, and it is not a detection-efficiency population estimate.
The acceleration correction gain is compelling; still must establish
that the multi-template Doppler distiller groups physically appropriate
associations and preserves strong candidates.

Scientific follow-up: run a correct-only a=150,j=0 bank on this same
data with identical search settings, compare its detected ~50 Hz S/N
to the full nine-template bank's 75.44 to ensure distiller retention
and isolate template-specific response. After that, inspect recovered
acceleration-dependent fold, then controlled jerk injection.
No code/third-party distiller changes without user approval.


## Stage 4 correct-template versus multi-template S/N equality verified (2026-10-23)

The user has now checked top ~50 Hz detections in three *independent*
PULSEJET GPU searches of the exact same a=+150 m/s², j=0 injected
filterbank, with identical DM=10, search settings and length:

| Treatment | Recovered frequency (Hz) | Acceleration (m/s²) | S/N | Nested associates |
| -- | --: | --: | --: | --: |
| Zero correction only | 50.000186920 | 0 | 52.76 | 0 |
| True +150 correction only | 50.000186920 | 150 | 75.44 | 0 |
| Nine-template bank (-300..+300, spacing 75) | 50.000186920 | 150 | 75.44 | 11 |

Measured corrected-vs-uncorrected S/N ratio ≈1.430 (=43.0% increase);
same top frequency in all cases. The **Doppler distiller preserved the
best correct-template detection at exactly the same S/N (75.44)** as the
true-only experiment and retained it as top representative with 11
associated detections. Does not prove all 11 associations represent
one astrophysical signal: XML only exposes counts.

Next: convert TOP candidate from nine-template output XML with
`pulsejet_xml_to_pulsarx` and `--limit 1` to a recovered PulsarX
candidate file and epoch-aware provenance. Then fold with PulsarX
`--nosearch` and midpoint `--pepoch`, using exactly matching
injected 262.144 s data; compare to independent truth fold.
Also fold stationary a=0 control to visualize lost acceleration
coherence. **Do not modify either third-party distiller without
prior explicit user discussion and approval.**


## Stage 4 acceleration recovered and uncorrected PulsarX folds produced (2026-10-23)

For the 262.144-second +150 m/s², zero-jerk injected dataset, all
three requested folds now exist:

- INCEPTION-Lite truth fold:
  `stage3/accel_run_a150/case_0001/folds/PSR_ACCEL_150/PSR_ACCEL_150_folded_profile.png`
- Recovered acceleration search (`a=150`, search S/N 75.44):
  `stage3/search_accel_bank_01/recovered_accel_folded_profile.png`
  (PNG 44,090 bytes), generated from real PulsarX .ar using
  `inception_lite.fold_plots.plot_folded_archive`.
- Uncorrected stationary control (`a=0`, search S/N 52.76):
  `stage3/search_accel_zero_control/recovered_zero_folded_profile.png`
  (PNG 43,640 bytes), again from real PulsarX .ar using the same
  plotting helper.

Both search-candidate folds were run with PulsarX `psrfold_fil`
`--nosearch`, with segment-midpoint
`--pepoch 60000.0015170371` and same injected .fil, 64 phase bins,
16 subbands. Native PlotX showed benign graphical warnings and the
fallback profile renderer generated valid PNGs.
**Visual inspection and quantitative archive comparison pending**;
do not claim phase-coherence or shape agreement until user provides
plots. User has been given precise local rsync commands to retrieve
all three PNGs and upload them for comparison.

Code/distiller behavior unchanged. The two distillers are authored by
someone else; user explicitly requires discussing/approving any
proposed algorithm or wiring changes beforehand.


## Stage 4 three-profile visual comparison: acceleration correction PASSED (2026-10-23)

The user uploaded all three actual PulsarX archive-derived pulse-profile
PNGs for the controlled synthetic injection (`P0=20ms`, `DM=10`,
`a=+150 m/s²`, `j=0`, `T=262.144s`):

- `accel_run_a150/case_0001/folds/PSR_ACCEL_150/PSR_ACCEL_150_folded_profile.png` (truth fold)
- `search_accel_bank_01/recovered_accel_folded_profile.png` (the highest-ranked PULSEJET candidate, `a=+150`, PulsarX `--nosearch`)
- `search_accel_zero_control/recovered_zero_folded_profile.png` (the highest-ranked stationary `a=0` control, PulsarX `--nosearch`)

Visual side-by-side observations: truth and corrected profiles show
strong, narrow, single peaks at phase ≈0.56 with nearly the same
morphology, recovered slightly lower peak (~9,700 arbitrary archive
units vs truth ~11,400), no substantial obvious broadening.
The uncorrected control has a broader, strongly asymmetric main peak
centered near ≈0.59 with long trailing shoulder extending toward phase
≈0.75; lower plot peak (~4,200 arbitrary archive units). These peak
intensities are rough visual readings, **not calibrated flux or a
statistical folding-SNR measurement**, and plotting has its own
baseline subtraction/normalization limitations.

Three way top candidate comparison already verified:
- No correction a=0: f≈50.000186920 Hz, S/N 52.76, 0 nested associates.
- Single true a=+150: same f, S/N 75.44, 0 associates.
- Nine-template bank: same f, retained true a=+150, S/N 75.44,
  11 associates.

**STAGE 4 CONTROLLED ACCELERATION RECOVERY PASSED**: demonstrable
+43.0% PULSEJET search S/N correction, correct acceleration winner
from nine templates, and near-truth coherent independent PulsarX
no-search fold; uncorrected fold visibly degraded. No broad
population-completeness, false-merge, per-template S/N surface
or statistical folding-SNR quantification yet. Current third-party
Doppler distiller preserved best candidate but astrophysical
correctness of 11 associations remains unverified.

Next user-requested experiment: synthetic nonzero jerk with nonzero
acceleration, one cluster command at a time. Suggested
`a=+150 m/s², j=+10 m/s³`, P0=20ms, DM=10, SNR target 80,
same fixed validated noise input. Prepare fresh configuration by
copying `accel_a150.json`, change unique case ID, output root,
source ID and `pulsars[0].A1=10.0`; then inject, truth-fold, search
multiple varying-jerk polynomial bank entries and compare against
zero-jerk control. **Do not modify or rewire either distiller without
first discussing exact proposed changes and obtaining explicit
user approval.**


## Stage 5 first 30-template jerk GPU search completed (2026-10-23)

INCEPTION-Lite has successfully injected a source `PSR_JERK_10`
with `P0=20ms` (f=50 Hz), `DM=10`, target SNR 80,
`A0=+150 m/s²`, `A1=+10 m/s³` and produced an actual
PulsarX truth folded .ar archive (95,040 bytes) and archive-derived
PNG (49,541 bytes), in
`stage3/jerk_run_a150_j10/case_0001/`.
The source .fil is
`stage3/jerk_run_a150_j10/case_0001/noise_baseline_fixed_jerk_a150_j10_case_0001.fil`.

A 30-row controlled acceleration/jerk bank
`stage3/polynomial_jerk_bank.txt` spans a=
`[-150,0,75,150,225,300]` m/s² and j=
`[-10,0,5,10,20]` m/s³, includes exact injected (150,10).
User launched pinned PULSEJET dev SIF on one A40 GPU with one
`DM=10` trial, `-n 4 -m 7`, frequency 20–100 Hz,
`-P polynomial_jerk_bank.txt`,
`--candidate_diagnostics -v`, output
`stage3/search_jerk_bank_01/` and logfile
`stage3/search_jerk_bank_01.log`.

**GPU execution SUCCESS** (`all done`), all 30 individual polynomial
resampling calls explicitly logged:
- 1 DM trial, 30 polynomial template trials
- 1536 raw spectral detections
- 240 after per-template harmonic distillation
- 240 before / 29 after per-DM polynomial Doppler distillation
- 29 before / after cross-DM and final harmonic grouping
- 29 final output candidates, 222 nested associated nodes
- worker reported 0.085426 s DM-processing time; NOT full pipeline
  benchmark.

IMPORTANT: nested 222 > 240−29=211, so cannot equate nested count
to unique detections eliminated by Doppler matching. Earlier harmonic
nesting and/or repeated association may be involved; not proof of
wrong grouping. XML records representative params and counts only,
not individual associated candidate records.

**Scientific jerk detection/recovery is STILL UNCONFIRMED until actual
overview.xml candidate frequency, a, j, S/N and association counts
are inspected.** Next user action: parse all 29 overview.xml records
ranked by S/N, flag ~50 Hz, compare leading candidate to known
injected (a=150,j=10). Then run correct-only and zero-jerk controls
and truth-versus-recovery PulsarX no-search folds. User explicitly
forbids changing either third-party distiller without first discussing
a proposed change and obtaining approval.


## Stage 5 top recovered candidate at injected a=150,j=10 (2026-10-23)

User parsed all 29 representative candidates in
`stage3/search_jerk_bank_01/overview.xml`.
Top S/N candidate (ID 0) independently found fundamental
`f=50.000187 Hz` with **a=+150 m/s², j=+10 m/s³**, exactly
matching injected polynomial template parameters in 30-member
two-dimensional bank, **PULSEJET search S/N 75.54**, `nassoc=37`.
DM fixed at 10, spin frequency blind, a/j recovered only on
grid that includes truth. The Doppler distiller retains the best
candidate, but associated members not inspectable from XML
and quality of all 37 groupings is unverified.

Next strongest output: candidate ID 1 at `f=92.615120 Hz`,
a=+75, j=0, S/N=36.92, assoc=48. Do not assume it is a second
pulsar: possible injection/noise artifact or other issue; investigate
in later control search if persistent.

Follow-up gates: run **true-only bank** a=150,j=10 on SAME injected
file, match recovered peak S/N ≈75.54 against 30-member bank
to verify no loss due to distillation; then run a zero-jerk control
a=150,j=0 and compare S/N; then archive-convert and PulsarX
`--nosearch` folds with segment-midpoint epoch and compare
truth/corrected/uncorrected profiles. Keep ALL distillers untouched
until discussed with and explicitly approved by user.


## Stage 5 zero-jerk control candidate table and count mismatch (2026-10-23)

After the `a=150,j=0` only-template control search of the **same
jerk-injected filterbank**, diagnostic STDOUT reported:
one DM, one template, 65 raw spectral detections, seven after
per-template harmonic distillation, seven final output, zero nested
associations; `all done`.

User then parsed `search_jerk_zero_control/overview.xml`, reporting
**nine** top-level candidates (IDs 0 through 8), not seven:
- ID 0 f=49.999233 Hz, a=150, j=0, S/N=49.92
- ID 1 f=92.614647 Hz, a=150, j=0, S/N=22.60
- remaining IDs 2..8 have S/N from 11.87 to 7.53

Compare correctly recovered 30-template candidate ID0 f=50.000187 Hz,
a=150,j=10,S/N=75.54; S/N rises by (75.54/49.92-1)*100=51.3% with
jerk correction (same DM and synthetic input). This is *search S/N*,
not fold S/N. The strong 92.615 Hz feature also appears in both
searches; its origin unknown.

**IMPORTANT integrity check next:** one-template terminal diagnostics
count=7 versus subsequent XML extracted top-level count=9, so compare
`search_jerk_zero_control.log` to `overview.xml` and their
modification timestamps before treating all candidates as products
of the same run. No assumption of software bug yet. Only one cluster
command at a time.

User wishes to archive-fold *multiple strong* full-bank candidates,
particularly IDs 0,1,2,3,4, plus truth and zero-jerk controls.
Do not edit distillers; discuss any proposed modifications and gain
explicit approval first.


## Stage 5 three-way a+j control comparison confirmed (2026-10-23)

On the 262.144-s synthetic P0=20 ms, DM=10, injected a=+150 m/s²,
j=+10 m/s³ .fil, user verified the top 50-Hz candidate across
three search outputs by directly parsing their on-cluster XMLs:

| Search | f (Hz) | a (m/s²) | j (m/s³) | S/N |
|---|---:|---:|---:|---:|
| 30-template bank | 50.000187 | 150 | 10 | 75.54 |
| correct-only a+j | 50.000187 | 150 | 10 | 75.54 |
| zero-jerk a-only | 49.999233 | 150 | 0 | 49.92 |

The full bank **retained the best true-template S/N** to displayed
precision. A+j improves search S/N 51.3% relative to a-only control.
30-template candidate ID 0 has 37 nested associated nodes, whose
physical association quality is NOT yet validated. Interesting other
strong full-bank candidates: ID1 f=92.615120 Hz S/N=36.92,
ID2 f=69.461815 Hz S/N=26.08,
ID3 f=79.384323 Hz S/N=23.50,
ID4 f=89.836113 Hz S/N=14.52.
User requests independent PulsarX `--nosearch` fold for top five
candidate IDs 0-4, plus injected truth and a-only zero-jerk control;
investigate nature of 92.615-Hz feature (do not assume astrophysical).
Next command: converter `pulsejet_xml_to_pulsarx` on 30-template
`search_jerk_bank_01/overview.xml` with `--min-snr 7 --limit 5`,
write top-five .cands and manifest and inspect output; subsequently
fold all five in PulsarX and generate profiles from .ar,
then prepare/fold a=150,j=0 zero-jerk control.
Only ONE cluster step per exchange.

The prior discrepancy of 7 vs 9 final candidates for zero-jerk was
resolved: on-disk saved zero-jerk log and XML share mtime
2026-10-23 12:25:53, and both show **9** final candidates
(50 raw spectral detections), IDs 0-8. The 65 raw/7 final
excerpt was from a different or unclear source, not evidence
of a software defect.

No changes to either distiller or algorithm without explicit
discussion and approval by the user.


## Stage 5 seven-fold visual review (2026-10-23)

User uploaded and visually reviewed ALL SEVEN PulsarX archive-derived
profiles for the 262.144-s +150m/s², +10m/s³ synthetic jerk injection:
`jerk_run_a150_j10/case_0001/folds/PSR_JERK_10/PSR_JERK_10_folded_profile.png`
(truth), `search_jerk_bank_01/top5_profiles/candidate_{0..4}_profile.png`
(five recovered candidates), and
`search_jerk_zero_control/recovered_zero_jerk_profile.png`
(control). All from actual PulsarX `--nosearch` archives.

Observations based on visual inspection:
- Truth and recovered top candidate 0 (f=50.000187 Hz,
  a=+150,j=+10,S/N75.54) have sharp, nearly identical phase~0.56
  pulse widths and morphology; recovered peak visibly modestly
  weaker. This is strong *visual* independent-fold agreement.
- Zero-jerk a=+150,j=0 top candidate (f=49.999233 Hz,
  search S/N49.92) still has a recognizable fairly narrow
  peak at ~0.56–0.58 but substantially reduced peak prominence;
  do NOT overclaim dramatic broadening or complete loss.
- Full-bank candidate 1 f=92.615Hz S/N36.92 has irregular
  multiple peaks with no comparably convincing narrow pulse;
  candidate 2 69.462Hz S/N26.08, candidate 3 79.384Hz
  S/N23.50, candidate 4 89.836Hz S/N14.52 similarly
  noise-like or inconsistent phase profiles, though average
  profiles alone cannot formally prove they are spurious.
- Profile y-axis is arbitrary baseline-shifted archive intensity,
  **not flux or statistically normalized folding S/N**. Do not
  directly equate plot peak amplitude with FFT search S/N.
- Candidate 1's strong spectral S/N despite unconvincing fold
  warrants follow-up, not instant labeling as random noise or bug.
  It was also recovered at 92.614647 Hz S/N22.60 in the
  a=150,j=0 control.

Recommended NEXT one-step test: run same 30-entry jerk bank
(with exactly same DM10, other peasoup args) against unchanged
noise-only `stage3/noise_baseline_fixed.fil`, output unique
`stage3/search_jerk_noise_control/`, compare whether 92.615 Hz
feature is present in *original noise*, versus introduced by
injection or search. No distiller edits without explicit consent.
Other later follow-ups: extract true archive folding S/N,
phase-v-time/phase-v-frequency for cand 1 and examine candidate
archive naming/ID mapping.


## Stage 5 same-seed noise-only control exposes pre-existing non-50 Hz candidates (2026-10-23)

User ran the exact same 30-template a/j polynomial GPU search
(with DM10, 20-100Hz) against the **original noise-only**
`stage3/noise_baseline_fixed.fil` (before adding PSR_JERK_10).
Output `stage3/search_jerk_noise_control/overview.xml`.
There were **21** output candidates. No candidates within 0.1Hz
of the injected 50Hz pulsar, whereas the injected-data run has
f=50.000187Hz at exact a=150,j=10 with search S/N75.54.

Highly significant non-50Hz search candidates pre-existed:
| feature | noise-only top S/N | with injected pulsar top S/N |
|---|---:|---:|
| f=92.615120Hz (a=75,j=0) | 49.19, nassoc56 | 36.92, nassoc48 |
| f=69.461815Hz (a=75,j=10) | 33.76 | 26.08 |
| f=89.836113Hz (a=150,j=-10) | 14.31 | 14.52 |
| f~79.39Hz | 17.58 | 23.50 (different nearby f/template) |

Thus the strange high-SNR non-50Hz outputs are **not caused
solely by injecting the 50Hz pulsar**. Do not label them real
pulsars, RFI, pure random peaks or distiller bugs without further
checks. Their preexistence in the noise-only search does not
identify whether origin is raw synthetic input or processing
(normalization/resampling/harmonics). The 92.615Hz candidate
is especially suspicious because of its search S/N of 49.19
in a nominally noise-only observation despite lacking
convincing narrow independent folded profile after injection.

**Next independent test:** inspect raw 8-bit noise-only filterbank
via Python/NumPy *outside PULSEJET search*, summing its 16 channels
and computing an ordinary raw FFT for high excess power around
92.615, 69.462, 89.836 and 50Hz. Use known validated SIGPROC
header size 267B, 1048576 time samples, tsamp=0.00025s, 16 channels
and `--cleanenv` inception SIF. If raw FFT is unremarkable at
92.615Hz despite search S/N49, examine search processing;
if raw FFT shows a strong line, inspect noise generation
and possible repeated patterns. Do not mistake this independent
unaccelerated FFT as definitive because original search used
nonzero a/j resampling.

Preserve both distillers unchanged until explicit user approval.
User requires one single HPC command/step at a time.


## Stage 5 independent raw FFT of same noise baseline (2026-10-23)

User independently analyzed the original 16-channel, 8-bit,
1048576-sample, 250-us noise-only SIGPROC filterbank using
NumPy rFFT of channel-mean series; PULSEJET NOT involved.
Observed mean=127.9994465, std=1.5018625 (channel-mean
8-bit counts). Band 20–100Hz; independent raw FFT power
normalized by its band median:

| target frequency (Hz) | nearby FFT peak (Hz) | FFT power/median | PULSEJET noise-only S/N |
|---|---:|---:|---:|
| 50 | 49.995422 | 5.03 | no candidate |
| 69.461815 | 69.473267 | 3.58 | 33.76 |
| 89.836113 | 89.824677 | 2.96 | 14.31 |
| 92.615120 | 92.620850 | 3.73 | 49.19 |

Strongest raw noise FFT power/median in band is 14.99
at 74.363708Hz; several other unrelated raw spectral bins
~11–14. These are not conspicuous peaks at the anomalous
PULSEJET detection frequencies.

Interpretation: noise-only PULSEJET high search S/N outputs
are not simply matched to obviously strong STATIONARY raw
FFT lines. This doesn't rule out chirping structures or
effects from PULSEJET time resampling, spectral normalization,
and harmonic summing. Neither raw FFT ratio nor FFT max is
the same statistic as PULSEJET search S/N.

**NEXT one-step control:** search unchanged noise baseline
with a=0,j=0 single polynomial template using same other
settings and inspect whether ~92.615 Hz remains a strong
candidate without nonzero resampling. Keep algorithm
and third-party distillers untouched until prior user
approval. If stationary run shows high S/N noise artifacts,
investigate spectrum/SNR normalization; if it disappears,
compare polynomial resampling / number of templates and
processing paths. One cluster step per assistant response.


## Stage 5 stationary noise-only search retains strong 92.615Hz anomaly (2026-10-23)

Using one `a=0,j=0` polynomial template against the original
noise-only `stage3/noise_baseline_fixed.fil` with the same DM10,
search band 20-100Hz, user inspected the
`stage3/search_noise_stationary_control/overview.xml`:
4 representatives total:
- 92.615601Hz, a=0,j=0,S/N=45.90
- 92.633720Hz, S/N=11.45
- 92.563622Hz, S/N=10.09
- 67.377083Hz, S/N=8.89
No candidates within 0.1Hz of 50,69.462,89.836.

Therefore strong 92.615Hz anomaly predates injection, survives
stationary search, and does **not require** nonzero polynomial
resampling or multi-template Doppler distillation.
Comparison for ~92.615 Hz:
noise-only stationary 45.90;
noise-only 30-template bank 49.19;
injected 30-template bank 36.92.

Prior independent raw (unaccelerated) channel-mean rFFT over only
20-100Hz showed no impressive power at fundamental near
92.615Hz (~3.73x band median). This alone CANNOT exclude strong
power at 2nd/4th/8th/16th harmonics elsewhere in the raw FFT,
which harmonic summing may promote to high S/N.
NEXT recommended independent test: calculate raw channel-mean rFFT
and inspect local FFT power near 92.6156Hz times
[1,2,3,4,8,16] and optionally subharmonics [0.5,0.25],
using frequency-local median normalization. Frequency bin
resolution 1/262.144s≈0.003815Hz, Nyquist 2000Hz. This test does
NOT modify PULSEJET. Depending on results investigate
harmonic-summing and normalization using diagnostic source,
not speculatively edit code. Both third-party distillers remain
untouched pending user approval.


## Stage 5 raw FFT harmonic check of noise-only 92.615 Hz (2026-10-23)

Independent NumPy FFT of original channel-averaged noise-only
filterbank checked maxima in ±0.03Hz bands near harmonics
of the strong stationary PULSEJET noise candidate
f=92.615601Hz. Data (harmonic: peak power/local median):
0.25:4.09; 0.5:7.07; 1:3.76; 2:3.61; 3:9.09;
4:4.84; 8:4.56; 16:4.34. Local windows each cover ~16
Fourier bins, so look-elsewhere effects elevate even
random-noise local maxima; peaks sometimes offset many
Fourier bins from exact expected harmonic frequencies.
No compelling narrow fundamental plus harmonics comb
to account for stationary noise PULSEJET search S/N 45.90.

The raw FFT simply channel-averaged; PULSEJET searched
with DM=10 dedispersion. NEXT controlled one-step test:
same noise-only input, *one stationary a=0,j=0* template,
DM changed to exactly 0 via separate `dm_noise_zero.txt`,
save to `search_noise_dm0_stationary`; inspect candidates
near 92.615Hz, compare to the stationary DM10 45.90.
Changing DM can alter channel alignment and normalization;
a DM0 difference does not by itself prove a dedispersion bug.
Afterwards inspect harmonic/FFT statistic and normalization
to understand high-SNR false alarms. NO source modifications,
NO distiller changes without prior user discussion/approval.
