# Open issue — PeakFinder minimum-frequency bin uses an inconsistent factor of two

**Status:** Reproducible code-level invalid-range defect suspected of explaining real M62 CUDA crash; diagnostic workaround identified but **not yet executed/confirmed**. **No code edits** as of 2026-10-23. Needs user-approved correction and regression tests before science publication or survey benchmarking.

## Observation

The first M62 baseline tests run on genuine unsigned 8-bit, 256-channel MeerKAT data, each single DM=0 and stationary polynomial template, crashed at the peak-finding stage with `thrust::system::system_error`: `trivial_device_copy D->H failed: cudaErrorInvalidValue: invalid argument`. The 2^22-sample attempt aborted after 13.577s, and the 2^20 attempt after 9.973s; both exit 134, not valid benchmarks. Using line-buffered stdout and `CUDA_LAUNCH_BLOCKING=1` confirmed full GPU preprocessing, polynomial `a=j=0` resampling, FFT, normalization and harmonic summing completed; last log message was `Finding peaks`, before `Distilling harmonics`.

## Source-level diagnosis

In [`include/transforms/peakfinder.hpp`](https://github.com/Rouhin1997/PULSEJET_beta/blob/dev/polynomial-search/include/transforms/peakfinder.hpp), lines 77–87:

```cpp
int size = pspec.get_nbins();
float nyquist = pspec.get_bin_width()*size;
int orig_size = 2.0*(size-1.0);
int nh = pspec.get_nh();
int max_bin = (int)((max_freq/pspec.get_bin_width())*pow(2.0,nh));
int start_idx = (int)(orig_size*(min_freq/nyquist)*pow(2.0,nh));
int count = device_find_peaks(std::min(size,max_bin),
                              start_idx, pspec.get_data(), ...);
```

For real-to-complex FFT of length N, the power spectrum has `size=N/2+1` and `orig_size=N`, while `nyquist=bin_width*size`. Therefore:

`start_idx = orig_size/size * min_freq/bin_width * 2^nh ≈ 2*min_freq/bin_width * 2^nh`,

while `max_bin = max_freq/bin_width * 2^nh`. Thus valid user bands with `max_freq < 2*min_freq` result in **start_idx > max_bin**. The first M62 band `[200,350] Hz` is invalid internally: it tries to iterate from approximately 400Hz to 350Hz. This is an evident mathematical inconsistency independent of the astronomical input.

In [`src/kernels.cu`](https://github.com/Rouhin1997/PULSEJET_beta/blob/dev/polynomial-search/src/kernels.cu) `device_find_peaks` constructs `zipped_iter+n-start_index` and hands this to `thrust::copy_if(...)`; when `n-start_index < 0`, the iterator range is invalid. A follow-on Thrust exception / CUDA invalid argument is plausible. The exact exception site inside the Thrust call is **not** independently verified with a debugger yet.

## Scientific ramifications

- Actual lower bound is approximately twice the user-supplied `--min_freq` (for non-truncated harmonic ranges); searches may **silently omit all candidates between requested min_freq and 2*min_freq**, even when they do not crash.
- Synthetic Stage 3–5 searches used `[20,100] Hz` and recovered the 50Hz injected pulsars. Those detections remain valid, but coverage of 20–40Hz was **not** necessarily achieved. This matters for any sensitivity/completeness statement; update downstream plans.
- The M62 J1701-3006B pulsar near 278Hz is in the *effective* range of a diagnostic `[100,350] Hz` request, avoiding the invalid `400>350` input.
- This bug belongs to peak extraction, not proven to originate in polynomial resampling. No distiller was reached in either M62 abort.

## Next experiment and change-control policy

**Without modifying code**, repeat a new 2^20-sample M62 DM0 stationary run, keeping all parameters the same except request `--min_freq 100 --max_freq 350`; retain `CUDA_LAUNCH_BLOCKING=1` plus `stdbuf -oL -eL`, and store logs in a unique output directory. Expect internally valid lower bound near 200Hz. Success would support causal diagnosis but does not validate peak counts, harmonics or actual sensitivity.

**Proposed future code fix, subject to user approval:** compute `start_idx` consistently as `(int)((min_freq/pspec.get_bin_width())*pow(2.0,nh))` (with sane clamping to `[0, size]` and `max_bin>=start_idx` check), then add CPU unit coverage for `[200,350]`, `[20,100]`, Nyquist edges and multiple harmonics, and end-to-end GPU regression tests including exactly matched synthetic injected signals. Preserve polynomial resampler, third-party distillers and original master. Determine if issue exists in upstream before attributing authorship.

## Provenance

Research ledger: [`docs/paper/PULSEJET_VALIDATION_LOG.md`](../docs/paper/PULSEJET_VALIDATION_LOG.md). HPC log: `$HOME/PULSEJET_validation/stage6_m62/baseline_1m_cuda_debug_01/debug.log`. Host: `node2`, pinned `pulsejet_dev.sif`, source commit `513e80d1ace21868fd3d3d37734bcd79782abce3`. No user data or original archive was modified.

## Controlled M62 frequency-bound A/B test: passed workaround (2026-10-23)

Exactly the same archival M62 symlink (`stage6_m62/m62_original.fil`), 1,048,576-sample segment, DM 0, a=j=0, one polynomial template, `-t 1 -n 4 -m 7`, upper bound 350 Hz, same pinned PULSEJET SIF; only lower search bound changed from `--min_freq 200` to `--min_freq 100`. The synchronized/line-buffered diagnostic completed with **exit status 0**; original with `--min_freq 200` consistently aborted with 134. This is strong A/B experimental evidence for the invalid `start_idx>max_bin` root cause. Diagnostic flags `CUDA_LAUNCH_BLOCKING=1`, `stdbuf -oL -eL`; this successful run did not measure whole-process wall-clock time.

Reported end of successful log:

```text
Finding peaks
Distilling harmonics
Distilling polynomial (acc+jerk) candidates
[DEBUG] poly post-distill count added=2
DM processing took 0.098978 seconds
[POLYNOMIAL_DIAGNOSTICS]
DM trials processed: 1
Polynomial template trials: 1
Raw spectral detections: 3
After per-template harmonic distillation: 2
Before per-DM polynomial distillation: 2
After per-DM polynomial distillation: 2
Collected before cross-DM distillation: 2
After cross-DM distillation: 2
After final harmonic distillation: 2
After output candidate limit: 2
Nested associated nodes in final output: 0
[END_POLYNOMIAL_DIAGNOSTICS]
all done
```

The `0.098978 s` diagnostic is **not** an end-to-end wall-clock benchmark, and the candidate significance/physical identity has not yet been inspected. Outputs: `$HOME/PULSEJET_validation/stage6_m62/baseline_1m_frequency_fix_test_01/run.log`, likely `overview.xml` in the same output dir; require user verification before treating candidates as meaningful.

**Source is still unmodified.** Before actual patching obtain user approval. Proposed minimal repair: compute the start bound in the same Fourier-bin units as the maximum, without `orig_size/size`; clamp both to valid spectrum indices, validate lower<=upper and any `count`/host-array bounds; test ordinary and harmonic-folded bin widths, valid `[200,350]` frequency range, and empty ranges. Do not change the polynomial resampler or third-party distillers. Then rebuild a *new pinned image* and rerun the original `[200,350]` search. Old pinned SIF stays available as a baseline for the A/B regression.


## 2026-10-27 — Source repair committed, CPU regression passes; new GPU image acceptance pending

Following the user's approval to fix the bug, the correction was implemented
**only on `dev/polynomial-search`**, not on master and not in the
previously pinned `/home/rnag/PULSEJET_validation/images/pulsejet_dev.sif`.

The new pure C++17 header
`include/transforms/peakfinder_bounds.hpp` calculates the search interval:

```text
harmonic_scale = 2^nh
first = ceil(min_freq / frequency_bin_width * harmonic_scale)
stop  = floor(max_freq / frequency_bin_width * harmonic_scale) + 1
clamp first and stop to [0, spectrum_nbins]
```

`[first,stop)` is an ordinary half-open integer interval and both user
frequency edges are inclusive. No `orig_size / spectrum_size` factor
appears. The returned candidate frequency uses the same transform in
reverse: `f_peak = peak_bin * frequency_bin_width / 2^nh`.
Empty ranges are returned without touching CUDA/Thrust. Invalid user
frequency windows and non-finite coordinates are rejected.

This fixes the earlier approximately **2× incorrect minimum
frequency** and handles Nyquist and harmonic-level limits consistently.
Before any host copy, the peak extraction wrapper also verifies that
its returned candidate count fits the existing bounded host arrays.
This is specifically a safety check for RFI-heavy scans; it does not
change the detection threshold or distillation.

New isolated CPU test `tests/test_peakfinder_bounds.cpp` is integrated
into `tests/run_cpu_tests.sh` (through `test_peakfinder_bounds`) and
automatically run by `.github/workflows/cpu-tests.yml`. It reproduces
the originally failing `[200,350]` Hz setup with the actual M62
8,388,608-sample FFT bin spacing, checks harmonic search stages nh0..4,
frequency reporting, clipped/empty windows, invalid arguments and
host buffer capacity.

**Independent CI evidence:** https://github.com/Rouhin1997/PULSEJET_beta/actions/runs/40520331689
— completed **success**, all CPU C++17 and Python wiring tests
passed. No CUDA/Peasoup binary was built or executed in that CPU
workflow.

**Explicit remaining acceptance gates:**

1. Build a new, independently version-pinned `dev-polynomial-` container
   from the revised code and verify the NVCC build succeeded.
2. Pull it to a **new filename** on the HPC; retain the old
   `pulsejet_dev.sif` unchanged.
3. Run `scripts/run_m62_w1_peakfinder_fixed_band_regression.sh`
   with the new SIF and `--min_freq 200 --max_freq 350` to confirm
   W1/I01 at 247 Hz and W1/I02 at 263 Hz are both recovered at
   their known DM and acceleration, with no old half-frequency workaround.
4. Optionally rerun the previous W3/I15 off-grid bank with the *true*
   lower band limit ~374 Hz and compare identical-source S/N and
   candidates with the prior pinned image.
5. Document container digest, A40 driver and real end-to-end wall
   times before treating this as production-ready for a 100-source
   population recovery test.

**IMPORTANT:** the present GitHub code may be fixed while an older HPC
SIF still contains the old bug. The two executables must not be
interchanged in experiment logs. An older script passing
`--min_freq 187` to *approximate* 374 Hz must not be assumed to have
its old effective frequency limits in the new image.


## 2026-10-27 — A40 end-to-end regression PASS; issue fixed in pinned image

The new CUDA image was published by GitHub Actions build 40521035662 and installed as:
`/home/rnag/PULSEJET_validation/images/pulsejet_peakfinder_fixed_fa2dfdcd.sif`.
HPC-computed SHA256: **`7ee88af84805e8434943df79af9d8e20dd62a52e0a6cb4c0ca2d9fc2df1410a3`**.
The image embeds source revision `fa2dfdcd2573d41f4751fce6d429c63a34344d05`. The old SIF was preserved.

The user ran `scripts/run_m62_w1_peakfinder_fixed_band_regression.sh` on A40 node3 with **literal requested [200,350] Hz** and without the old half-min-frequency workaround. The previously problematic band completed cleanly in both cases:

- W1/I01 fixed DM=0, a=j=0, start sample 0, N=4194304: **f=247.000107 Hz, S/N=52.29, nh=3**, 27 raw / 8 final candidates, 14 s wall, exit 0.
- W1/I02 fixed DM=4, a=40 m/s², j=0, start sample 5313523, N=4194304: **f=263.000305 Hz, S/N=29.89, nh=3**, 34 raw / 13 final candidates, 13 s wall, exit 0.

Both S/Ns match prior old-image pilot responses under a diagnostic frequency workaround. This confirms the original invalid peak-finding range is now functional in the new image and did not alter these established source recoveries. Source-level CPU regression and full image build also passed. The result is **not** yet a claim that all frequency bounds and heavy-RFI conditions are comprehensively GPU-tested, or that broad parameter-space recovery is complete.

**Status:** FIXED, CPU-validated, CUDA built and A40 functional regression accepted. Use the newly pinned image and correct frequency bounds for the new multi-DM, generated-bank campaign. **Never carry the old `--min_freq = desired/2` workaround into new results**. The old `pulsejet_dev.sif` remains a reproducibility baseline.
