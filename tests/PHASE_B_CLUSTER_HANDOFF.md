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
