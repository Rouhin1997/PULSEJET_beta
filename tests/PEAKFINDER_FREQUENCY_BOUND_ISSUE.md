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