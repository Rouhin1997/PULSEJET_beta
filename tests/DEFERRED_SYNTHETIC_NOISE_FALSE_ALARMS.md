# Deferred validation issue: anomalous high-S/N detections in nominally Gaussian noise

**Status:** OPEN / DEFERRED for real-observation injection tests.  
**Date:** 2026-10-23. **Priority:** revisit before publishing noise-only false-alarm statistics, production thresholds, or survey-scale detection rates; revisit sooner if the effect recurs in observational controls.  
**Branch:** `dev/polynomial-search`. No source code or either candidate distiller was modified to investigate the anomaly.

## Concise finding

An **un-injected** SIGPROC filterbank nominally generated from Gaussian noise produced a PULSEJET candidate at **92.615601 Hz, reported search S/N 45.90**, with one DM trial (DM=10) and one **stationary** polynomial template `a=0, j=0`. The same feature was not reported when the *identical* dataset was searched with DM=0. A narrow DM sweep showed a sharply enhanced response at DM=10 compared with neighboring DMs. The feature therefore **does not require nonzero polynomial resampling, an injected pulsar, or cross-template Doppler grouping**. Its origin is **not established**; in particular, these tests do not exonerate or implicate all other shared processing (dedispersion, FFT normalisation, spectral whitening, harmonic summing, output significance).

The separate **signal-recovery** results still passed: a known 50-Hz signal at `a=150 m/s², j=10 m/s³` was recovered as the highest-ranked candidate with S/N 75.54 and a coherent, truth-like independent PulsarX fold. Treat signal recovery and false-alarm calibration as separate gates.

## Input and controlled environment

- Original baseline: `/home/rnag/PULSEJET_validation/stage3/noise_baseline_fixed.fil`.
- Nominal noise-generation model: Gaussian time-frequency samples, quantized to unsigned 8-bit data. Not verified by an independent multiseed goodness-of-fit test.
- 1,048,576 time samples; `tsamp=0.00025 s`; duration **262.144 s**.
- 16 channels, `fch1=1400 MHz`, `foff=-1 MHz` (1400 to 1385 MHz); `tstart=60000.0 MJD`; 267-byte SIGPROC header, 16,777,483-byte file.
- One DM per run (no cross-DM grouping in the DM sweep), stationary bank `0 0`, `-t 1 -n 4 -m 7 --min_freq 20 --max_freq 100 --candidate_diagnostics`.
- GPU image `$HOME/PULSEJET_validation/images/pulsejet_dev.sif`, source commit `513e80d1ace21868fd3d3d37734bcd79782abce3`; A40 cluster.
- `noise_baseline_fixed.fil` is reused unchanged for every test below.

## A. Baseline versus injected candidates

| Search/data | Top or matched candidate | Search S/N | Notes |
|---|---|---:|---|
| Original noise-only, 30 a/j templates, DM=10 | 92.615120 Hz, a=75, j=0 | 49.19 | 21 final candidates total; 56 nested association nodes for that representative |
| Same background with injected 50-Hz a=150,j=10 pulsar, 30 templates, DM=10 | 92.615120 Hz, a=75, j=0 | 36.92 | Pre-existing 92.615-Hz feature persists; candidate 1 |
| Original noise-only, 30 templates, DM=10 | 69.461815 Hz, a=75,j=10 | 33.76 | This non-50-Hz feature also pre-existed |
| Injected observation, 30 templates, DM=10 | 69.461815 Hz, a=75,j=10 | 26.08 | Same frequency and template |
| Original noise-only, **single stationary** template, DM=10 | **92.615601 Hz, a=0,j=0** | **45.90** | 4 representatives; cannot be attributed to nonzero a/j kernel |
| Original noise-only, single stationary template, DM=0 | 92.615-Hz region not reported | — | 1 unrelated candidate f=78.014366Hz at S/N 8.37 |
| Injected observation, 30 templates, DM=10 | 50.000187 Hz, a=150,j=10 | 75.54 | Known injected pulsar, not found in original-noise search |

**Reported search S/N is pipeline-defined and not independently calibrated as Gaussian sigma.** No reported candidate does not mean zero spectral power.

## B. Stationary search DM sweep

Each trial used its own one-line DM file and own output directory. No results from different DMs were merged.

| DM (pc cm^-3) | Final candidates | Best S/N reported near 92.615 Hz | Strongest overall S/N |
|---:|---:|---:|---:|
| 0 | 1 | not reported | 8.37 |
| 5 | 4 | 10.34 | 12.54 |
| 8 | 5 | not reported | 13.72 |
| 9 | 4 | 9.38 | 11.54 |
| **10** | **4** | **45.90** | **45.90** |
| 11 | 10 | 10.14 | 25.03 |
| 12 | 4 | not reported | 17.86 |
| 15 | 5 | 10.07 | 17.97 |

Relevant output directories in `/home/rnag/PULSEJET_validation/stage3/`:
`search_noise_stationary_control/` (DM10);
`search_noise_dm0_stationary/` (DM0);
`search_noise_dm5_stationary/`, `dm8`, `dm9`, `dm11`, `dm12`, `dm15`;
`search_jerk_noise_control/` (30 templates, DM10).
Associated `.log` files and `overview.xml` are the primary machine-readable evidence.

## C. Independent input-spectrum checks

Independent NumPy channel-mean FFT, without PULSEJET/dedispersion, on the original 8-bit filterbank gave mean **127.9994465**, standard deviation **1.5018625** of the averaged time-series samples. Maximum raw 20–100-Hz FFT power/median ratio was **14.99**, at **74.363708 Hz**, unrelated to the main suspicious candidate.

| Search-target frequency | Nearby raw FFT peak | Raw FFT power / band median |
|---|---:|---:|
| 50 Hz | 49.995422 Hz | 5.03 |
| 69.461815 Hz | 69.473267 Hz | 3.58 |
| 89.836113 Hz | 89.824677 Hz | 2.96 |
| 92.615120 Hz | 92.620850 Hz | 3.73 |

Local power ratios in +/-0.03Hz windows at multiples of 92.615601Hz:

| Frequency multiplier | 0.25 | 0.5 | 1 | 2 | 3 | 4 | 8 | 16 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Max power/local median | 4.09 | 7.07 | 3.76 | 3.61 | 9.09 | 4.84 | 4.56 | 4.34 |

Each ±0.03-Hz maximum searched ~16 raw Fourier bins (look-elsewhere effect). None constitutes persuasive evidence of a coherent raw harmonic comb; importantly, the raw channel-mean FFT has **not** undergone the same DM10 delays, whitening, harmonic summing or candidate selection as PULSEJET. It is *not* a direct reproduction of the pipeline statistic.

## D. Interpretations that are and are not supported

**Supported:** feature predates injection; feature can be seen with a=0,j=0; at DM10 much higher reported S/N than nearby DMs; no particularly strong stationary raw FFT fundamental; the independent PulsarX fold of the 92.615-Hz candidate on the injected dataset was not a convincing isolated coherent pulse.

**Not established:** that any specific code module contains a bug; that a distiller wrongly grouped these candidates; that harmonic sums are numerically incorrect; that the nominal noise is truly white and independent after quantization/header handling; that a reported S/N ~46 corresponds to calibrated ~46 Gaussian sigma; that the issue generalizes to real MeerKAT data.

**Candidate hypotheses to test only if reopened:** synthetic filterbank statistics/seed/channel correlations; DM-dependent dedispersion or memory/boundary artifacts; shared Fourier whitening and S/N calibration; harmonic-summing statistic and searched-trial effects; numerical normalization at 8-bit/16-channel configuration; reproduction with multiple independent Gaussian noise seeds; compare raw and independently dedispersed power spectra with exact pipelines.

## E. Reopening criteria and prescribed sequence

Revisit this issue when:
1. Real-observation, no-injection controls produce similarly inexplicable narrow-DM and high-S/N candidates;
2. False-alarm curves or sensitivity/completeness results must be quantitatively calibrated for a paper;
3. Increasing bank size causes excessive false-positive load;
4. A multi-seed Gaussian-null experiment confirms unusually heavy-tailed candidate significance.

Suggested controlled sequence: repeat on independently generated noise seeds and raw headers; export/cross-check the actual DM-dedispersed timeseries via independent implementation; compare harmonic-summing/whitening intermediate spectra; audit effective S/N statistics and empirical false-alarm distributions as functions of DM, bank size, harmonic count, input quantization and observation length. Preserve both third-party distillers and other established algorithms unless changes are scientifically justified and **explicitly approved by the user**.

**Decision:** Park this as a documented open statistical-validation issue; advance to real observation M62 injection and honest wall-clock A40 benchmarking now. Avoid interpreting the current synthetic-noise data as a validated false-positive benchmark.

See also [development handoff](PHASE_B_CLUSTER_HANDOFF.md) and [paper-oriented validation log](../docs/paper/PULSEJET_VALIDATION_LOG.md).
