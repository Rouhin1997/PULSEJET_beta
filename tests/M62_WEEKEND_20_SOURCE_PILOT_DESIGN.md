# Weekend M62 experimental design: 20 controlled injections into observational noise

**Status: scientific design proposal only (2026-10-23); NOT launched or validated.** No search or injector scientific source-code changes. This is a small coverage pilot, **not yet a statistically calibrated population completeness experiment**.

## Recommended layout

Process the *actual* UHF M62 SIGPROC observation as four **disjoint** ~14.88-minute blocks (original 59.52-minute observation divided into fourths). Prepare four independently validated SIGPROC sub-filterbanks automatically with original channel metadata, appropriate adjusted `tstart`, correct `nsamples`, original sample formatting. Original archive is read-only. Use INCEPTION-Lite `mode=together`, **five sources per block**, yielding **four new injected `.fil` files, 20 uniquely identified injected pulsars total**. Each sub-filterbank is a distinct real-noise/RFI realization by time. This avoids 20 full-length output files or >~20 source models evolved over the full hour. A Python extraction utility and extraction validation are NOT yet implemented. The exact target segment sizes/search `nsamples` and PULSEJET FFT padding must be tested before the performance experiment; PULSEJET may require power-of-two FFTs.

The injector's `SNR` is nominal S/N **for each 14.88-minute injection file**, not an independently verified folded S/N and not a guarantee of Fourier-search recovery. Five injected signals could contaminate each other, particularly with coincident frequencies, so use well-separated frequencies and paired original-background controls. The frequency choices avoid the known M62B ~278.25Hz frequency.

## Proposed 20-source truth catalogue (illustrative; sign/epoch verified during pilot)

Frequency is at the sub-filterbank midpoint (`ACCEPOCH=0.5`, topocentric, no explicit `PEPOCH`); `P0 = 1/f0`. `DM_add` means **additional synthetic interchannel dispersion on top of already processed background**, not physical total DM 114. Acceleration is m/s², jerk is m/s³. Values describe a *local constant-jerk polynomial*, not full Keplerian orbits.

| Window | ID | f0 (Hz) | P0 (ms) | DM_add (pc cm^-3) | a (m/s²) | j (m/s³) | Nominal S/N | Class |
|---|---|---:|---:|---:|---:|---:|---:|---|
| W1 | I01 | 247 | 4.04858 | 0 | 0 | 0.00 | 100 | stationary |
| W1 | I02 | 263 | 3.80228 | 4 | 40 | 0.00 | 60 | acceleration only |
| W1 | I03 | 289 | 3.46021 | 8 | 0 | +0.04 | 24 | jerk dominated |
| W1 | I04 | 311 | 3.21543 | 12 | 85 | -0.06 | 75 | mixed a+j |
| W1 | I05 | 359 | 2.78552 | 20 | -160 | +0.15 | 18 | mixed a+j |
| W2 | I06 | 253 | 3.95257 | 2 | 0 | 0.00 | 45 | stationary |
| W2 | I07 | 271 | 3.69004 | 8 | -70 | 0.00 | 28 | acceleration only |
| W2 | I08 | 297 | 3.36700 | 12 | 0 | -0.10 | 80 | jerk dominated |
| W2 | I09 | 329 | 3.03951 | 20 | -120 | -0.08 | 90 | mixed a+j |
| W2 | I10 | 371 | 2.69542 | 4 | 210 | +0.22 | 10 | mixed a+j |
| W3 | I11 | 241 | 4.14938 | 4 | 0 | 0.00 | 70 | stationary |
| W3 | I12 | 305 | 3.27869 | 12 | 135 | 0.00 | 20 | acceleration only |
| W3 | I13 | 317 | 3.15457 | 20 | 0 | +0.18 | 50 | jerk dominated |
| W3 | I14 | 341 | 2.93255 | 2 | 185 | +0.10 | 36 | mixed a+j |
| W3 | I15 | 383 | 2.61097 | 8 | -235 | -0.25 | 65 | mixed a+j |
| W4 | I16 | 259 | 3.86100 | 8 | 0 | 0.00 | 40 | stationary |
| W4 | I17 | 291 | 3.43643 | 20 | -220 | 0.00 | 55 | acceleration only |
| W4 | I18 | 323 | 3.09598 | 2 | 0 | -0.25 | 12 | jerk dominated |
| W4 | I19 | 347 | 2.88184 | 4 | -90 | +0.06 | 32 | mixed a+j |
| W4 | I20 | 391 | 2.55754 | 12 | 250 | -0.30 | 15 | mixed a+j |

Distribution: 4 stationary, 4 acceleration-only, 4 jerk-at-zero-acceleration, 8 mixed a+j; 20 unique f, 20 unique nominal S/N in 10–100, DM_add in 0–20. All a lie within ±250 m/s²; all j lie within ±0.30 m/s³. Ranges are illustrative physically plausible **local** derivatives for compact pulsar binaries; not sampled from a coupled Keplerian mass/orbit prior. DM_add=20 may incur substantial smearing in 2.125-MHz channels, especially toward the bottom of the UHF band, and requires validation in the actual injector before claiming physical realism. We do not currently have a verified original filterbank dedispersion history.

## Performance reality and weekend feasibility gate

With **one source** injected into full 59.52min, the observed eight-worker throughput at ~20/190 blocks/worker was ~770–780s per 10 blocks/worker, roughly 4h to process the entire file if steady, **before folding**. Source synthesis loop in `injector/signal_injector.py` calls `pulsar_model.generate_signal` separately per source in every block; 20 sources over the full file could exceed a weekend and should not be launched blindly. Four ~14.88-minute files with five sources each reduce synthesized signal-time from 20*59.52 to 5*59.52 minutes, about 4x less than twenty full-length injections or one 20-source full observation. Very roughly ~20h injection plus folding at eight workers **only if cost scales near linearly with source count and duration**; this projection is NOT validated. The actual runtime depends on CPU allocations/contending jobs/memory and I/O. Do a short throughput benchmark (e.g. 2–4-minute real-data excerpt with all five W1 models) before weekend launch and extrapolate actual measured throughput.

Disk budget: original full ~15.18 GB decimal, four background subfiles combined ~15.18GB, four injected subfiles combined ~15.18GB, plus intermediate `.fil.part`, truth .ar/fold products/logs. Concurrent peak usage may be greater; verify `df -h`, quota, scratch policy and that original remains immutable. If local quota is too small, prepare and inject one block at a time with safe manifest/checksum gating and do not delete any verified or unfinished file automatically. Run jobs under scheduler/session-aware controls; don't leave an SSH-attached foreground process as a substitute for job management if weekend unattended runs are intended. Only run CPU tasks within allocated worker limits.

## Validation gates, in order

1. Stop and reap any workers from aborted full-file attempt `_pilot_02`; preserve its logs/manifest; do not confuse preallocated `.fil.part` with complete data.
2. Validate safe chunk extractor against the original SIGPROC header/data bytes; verify adjusted `tstart`, `tsamp`, channels, `nifs`, signedness, actual sample count, and end-time/time alignment; verify no original-file mutation. Store SHA256 and read-back checks. Optionally extract W1 only first.
3. Build a **small ~2–4-minute benchmark** of five sources in realistic M62 noise, `PYTHONNOUSERSITE=1`, seeded input, `--perform-folds no` for throughput only, and check actual CPU and disk capacity. Short preflight with one source and `--perform-folds yes` proves real PulsarX archive/multi-panel diagnostic path.
4. Author and review four separate `mode=together` JSON configs using the 20-source matrix; `generate_fb` MUST be absent (preserve real observational data), unique output locations, fixed seeds per window, `ACCEPOCH=0.5`, `frame=topo`, and correct injected dispersion policy. Confirm full-length (`~14.88min`) output SNR scaling for each case.
5. Run four injections with successful fold truth from **PulsarX `psrfold_fil`** (5 `.ar` products per output) and create scientifically correct integrated profile/time–phase/frequency–phase displays from real archive data. Existing INCEPTION fallback `fold_plots.py` draws only 1D pulse phase profile; additional panels must be implemented and QA'd. Ensure each `run_manifest.json` and `inject.log` is complete. Check reported model coefficients and folded S/N.
6. Before searching, correct the confirmed PeakFinder lower-frequency bin boundary factor-of-two bug in `include/transforms/peakfinder.hpp` with regression tests and rebuild a **new pinned SIF** on `dev/polynomial-search`; original crash reproduction and bug documented in `tests/PEAKFINDER_FREQUENCY_BOUND_ISSUE.md`. Do not modify source until approved by user.
7. Paired searches: run PULSEJET with **tailored exact truth acceleration/jerk templates** for injected and original observations, matching DM trials. Then generated banks (mismatch/coverage), positive vs negative derivative recovery, false positives, S/N vs injected strength and runtime. Background M62B search at residual DM near reported 114 may be run separately without assuming that beam actually detects it.
8. PRESTOzl benchmark with equivalent searched observation windows, harmonic strategy, acceleration/jerk coverage, DM and candidate validation, and matched end-to-end timings; no paper-grade efficiency or sensitivity claims until matching search conditions.

**Known subtleties:** injection/PeakFinder code are different projects. An injection 'DM' value in upstream `injector/propagation_effects.py` controls across-channel offsets; `cDM` influences intra-channel smearing but is NOT subtracted from delays by upstream code. Check whether current M62 file has been incoherently dedispersed at DM114 and how the coarse channelization was formed. For the purpose of pure detection-validation, treat the above values as *additional synthetic dispersive offsets*, label them as such in plots/results, and validate known injected signal truth. Avoid claiming these sources occupy the actual M62 cluster DM distribution.

**Owner decision remaining:** approve four ~15-minute multi-source files vs single full-length 20-source file. No injection launched by this document.
