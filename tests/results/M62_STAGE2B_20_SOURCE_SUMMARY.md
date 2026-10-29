# M62 Stage 2B: completed 20-source differential phase-track diagnostic

Date: 2026-10-29. Project: PULSEJET beta / INCEPTION-Lite, completed M62 Stage 6 five-source injections in observational 15-minute filterbank windows W1–W4.

**Status:** the independent, read-only sampled *differential-pixel phase-track* checks have been executed on all four windows. All **20 of 20** intended phase tracks have higher first-harmonic circular coherence than their deliberately shifted-frequency controls. All **59 of 59 tested physical-model alternatives** (individual acceleration sign reversal, jerk sign reversal, DM sign reversal, and no-motion variants when applicable) have lower coherence than their corresponding intended model. These are fixed-parameter diagnostic comparisons, not 59 independent significance tests or measured detection sensitivity. In particular, the implementation itself labels reports `DIAGNOSTIC_COMPLETE_NOT_SCIENCE_PASS`.

## Cluster provenance and observed payload differences

| Stage 6 window | Stage 2B Slurm job | Samples compared per input/output file | Changed bytes | Positive changes | Negative changes | Max absolute byte delta | Number of signed-model controls |
|---|---:|---:|---:|---:|---:|---:|---:|
| W1 | 66727 | 33,554,432 | 75,228 | 75,228 | 0 | 1 | 14 |
| W2 | 66787 | 33,554,432 | 68,469 | 68,469 | 0 | 1 | 15 |
| W3 | 66869 | 33,554,432 | 65,834 | 65,834 | 0 | 1 | 15 |
| W4 | 66892 | 33,554,432 | 42,295 | 42,295 | 0 | 1 | 15 |
| **All windows** | — | **134,217,728** | **251,826** | **251,826** | **0** | **1** | **59** |

All four change counts are exactly consistent with the earlier read-only Stage 2A sampling results, using 32 distributed blocks of 4096 time samples and 256 unsigned 8-bit frequency channels. The aggregate changed-byte fraction is about **0.1876%** of the sampled per-file payloads. The strong one-count asymmetry is compatible with a positive weak-profile injector and quantization; it is *not* a measurement of injected flux or S/N.

Stage 2A, job **66715**, had also passed exact metadata and filterbank geometry checks on W1–W4 and matched **8/8** manifest-to-runtime-SIF hashes for the injector script and pulsar model source. Stage 1's full read-only source-versus-window extraction audit was previously completed under job **66707**, comparing 15,177,064,192 bytes of real observational payload.

## Per-pulsar true-model coherence versus shifted-frequency controls

| Window | Pulsar | Truth coherence | Maximum off-frequency coherence | Truth/off-frequency ratio |
|---|---|---:|---:|---:|
| W1 | M62_W1_I01 | 0.36111 | 0.03895 | 9.27× |
| W1 | M62_W1_I02 | 0.21270 | 0.03079 | 6.91× |
| W1 | M62_W1_I03 | 0.08546 | 0.01113 | 7.68× |
| W1 | M62_W1_I04 | 0.26713 | 0.03136 | 8.52× |
| W1 | M62_W1_I05 | 0.06358 | 0.00619 | 10.28× |
| W2 | M62_W2_I06 | 0.17538 | 0.02136 | 8.21× |
| W2 | M62_W2_I07 | 0.10897 | 0.01316 | 8.28× |
| W2 | M62_W2_I08 | 0.31615 | 0.04087 | 7.74× |
| W2 | M62_W2_I09 | 0.34997 | 0.04110 | 8.51× |
| W2 | M62_W2_I10 | 0.04298 | 0.00633 | 6.79× |
| W3 | M62_W3_I11 | 0.29161 | 0.03401 | 8.57× |
| W3 | M62_W3_I12 | 0.07952 | 0.00699 | 11.38× |
| W3 | M62_W3_I13 | 0.20760 | 0.02524 | 8.22× |
| W3 | M62_W3_I14 | 0.14883 | 0.01571 | 9.47× |
| W3 | M62_W3_I15 | 0.26183 | 0.03494 | 7.49× |
| W4 | M62_W4_I16 | 0.25432 | 0.03026 | 8.41× |
| W4 | M62_W4_I17 | 0.35456 | 0.04197 | 8.45× |
| W4 | M62_W4_I18 | 0.07322 | 0.00964 | 7.60× |
| W4 | M62_W4_I19 | 0.20201 | 0.02123 | 9.52× |
| W4 | M62_W4_I20 | 0.10307 | 0.01202 | 8.58× |

These ratios use only sparse background-versus-injected *changed pixels*, each weighted by its signed ADC difference, and the circular first Fourier harmonic of an independently calculated topocentric polynomial phase. The off-frequency alternatives are selected, fixed frequency perturbations, not an exhaustive search over incorrect model parameters.

## W4 full signed-model counterfactuals (Slurm 66892)

The operator supplied the JSON-derived W4 values below. They complete the W4 sign-control check without relying only on a completion marker.

| Pulsar | Truth coherence | Counterfactual model | Counterfactual coherence | Truth/control ratio |
|---|---:|---|---:|---:|
| M62_W4_I16 | 0.25432 | DM sign reversed | 0.00295 | 86.08× |
| M62_W4_I17 | 0.35456 | Acceleration sign reversed | 0.07225 | 4.91× |
| M62_W4_I17 | 0.35456 | No acceleration or jerk | 0.08269 | 4.29× |
| M62_W4_I17 | 0.35456 | DM sign reversed | 0.01115 | 31.80× |
| M62_W4_I18 | 0.07322 | Jerk sign reversed | 0.01130 | 6.48× |
| M62_W4_I18 | 0.07322 | No acceleration or jerk | 0.02027 | 3.61× |
| M62_W4_I18 | 0.07322 | DM sign reversed | 0.00146 | 50.02× |
| M62_W4_I19 | 0.20201 | Acceleration sign reversed | 0.04279 | 4.72× |
| M62_W4_I19 | 0.20201 | Jerk sign reversed | 0.07724 | 2.62× |
| M62_W4_I19 | 0.20201 | No acceleration or jerk | 0.06220 | 3.25× |
| M62_W4_I19 | 0.20201 | DM sign reversed | 0.01095 | 18.45× |
| M62_W4_I20 | 0.10307 | Acceleration sign reversed | 0.01163 | 8.86× |
| M62_W4_I20 | 0.10307 | Jerk sign reversed | 0.00755 | 13.65× |
| M62_W4_I20 | 0.10307 | No acceleration or jerk | 0.00661 | 15.60× |
| M62_W4_I20 | 0.10307 | DM sign reversed | 0.00486 | 21.21× |

The weakest W4 sign-control contrast is I19 with reversed jerk (**2.62×**); the intended model is still preferred. W4's event cloud has `distributed_blocks=32`, `time_samples_per_block=4096`, `bytes_compared_per_file=33,554,432`, `changed_bytes=42,295`, `increased=42,295`, `decreased=0` and `max_abs_delta=1`. The operator-provided report status was `DIAGNOSTIC_COMPLETE_NOT_SCIENCE_PASS`.

## Earlier windows' physical-model checks

Complete numerical tables for W1 (14 alternatives), W2 (15 alternatives), and W3 (15 alternatives), including all control coherences and ratios, are preserved in [the main M62 injection integrity validation log](../M62_INJECTION_INTEGRITY.md). All tested alternatives had lower coherence than truth. The new W4 table adds another **15** comparisons to yield **59 of 59** over the pilot.

## Scientific interpretation and limitations

1. The tests establish that **sampled digitized changes are phase concentrated preferentially along the intended combined period/DM/acceleration/jerk tracks** compared with the particular off-frequency and sign-reversal alternatives evaluated. They do not prove every injected byte is correct, distinguish every nearby model, or provide calibrated false-alarm significances.
2. The W1–W4 tests inject five sources **simultaneously** in each window. Other pulsars' changed pixels can dilute or occasionally contaminate per-source coherence and the comparisons are not strictly independent.
3. The underlying emission uses finite, low-amplitude 8-bit digitization with source-specific profiles, scattering/smearing options and a nontrivial SNR normalization. Even correct phase-track coherence does **not** establish that the specified nominal SNRs are recovered, that signal amplitudes are statistically correct, or that the requested injection statistics match a calibrated distribution.
4. This pilot uses topocentric polynomial motion with midpoint `ACCEPOCH=0.5` and injected **additional DM**, not the full later-stage Keplerian binary/UCB100 injection population.
5. A correct-sign model comparison does **not** substitute for an independent epoch-convention and full profile-fold validation (PulsarX midpoint PEPOCH versus PRESTO start-of-observation convention) or calibrated pulse-strength verification on observational noise and RFI.
6. The W4 stderr was not included in the operator's excerpt; the stdout confirms normal audit completion. Preserve the original cluster JSON and stdout files; GitHub logs are reproducible summaries, not copies of the raw observational payload.

## Artifacts and provenance

- Stage 2B independent verifier: [`scripts/verify_m62_injection_phase_tracks.py`](../../scripts/verify_m62_injection_phase_tracks.py)
- Stage 2B synthetic regression: [`tests/test_verify_m62_injection_phase_tracks.py`](../test_verify_m62_injection_phase_tracks.py)
- Stage 2B read-only launcher: [`scripts/run_m62_injection_phase_tracks.slurm`](../../scripts/run_m62_injection_phase_tracks.slurm)
- Original cluster result JSON: `/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/injection_phase_<JOBID>/W<WINDOW>/phase_track_result.json`, with job IDs listed above.
- Stage 2A provenance: [`tests/M62_INJECTION_INTEGRITY.md`](../M62_INJECTION_INTEGRITY.md)
- Stage 1 source integrity: [`tests/M62_FILTERBANK_EXTRACTION.md`](../M62_FILTERBANK_EXTRACTION.md)

## Next validation gate

Perform *independent known-truth folding and amplitude/SNR calibration*: inspect all 20 pulsars at the exact injection parameters with a verified epoch and sign convention, compare recovered phase structure and signal significance to their known truth and suitable controls, and report injected-vs-recovered amplitude statistics accounting for real observational noise and RFI. Use only completed Stage 6 assets, do not touch active Stage 10/UCB100 or alter filterbanks. Keep this downstream gate marked **not yet passed**.
