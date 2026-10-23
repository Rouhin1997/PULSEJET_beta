# PULSEJET polynomial acceleration–jerk engine: research validation and benchmark log

**Document class:** paper evidence / experimental laboratory record (living; begins 2026-10-23).  
**Status:** synthetic-injection recovery verified; empirical false-alarm calibration and observational validation pending.  
**Development branch:** \`dev/polynomial-search\`, repository \`Rouhin1997/PULSEJET_beta\`.  
**Companion documents:** [full cluster handoff](../../tests/PHASE_B_CLUSTER_HANDOFF.md), [synthetic-noise anomaly record](../../tests/DEFERRED_SYNTHETIC_NOISE_FALSE_ALARMS.md), [candidate-distiller characterization](../../tests/STEP2_FINDINGS.md).

> **Integrity principle.** The pipeline's reported *search S/N*, a PulsarX archive plot's arbitrary y-axis values, a statistically calibrated folded S/N, and wall-clock computation time are **different measurements**. Do not exchange one for another. All numerical results below are controlled tests, not sky-sensitivity forecasts. The PDF companion \`PULSEJET_Synthetic_Validation_Dossier_2026-10-23.pdf\` contains the **actual ten uploaded archive-derived plots**; primary PNGs and \`.ar\` files remain on the cluster at the paths specified in §8. The PDF is a local report/evidence export, not yet a tracked binary in the repository.

## 1. Provenance: executable, GPU, and algorithm

- PULSEJET compiled Singularity image: \`/home/rnag/PULSEJET_validation/images/pulsejet_dev.sif\`; source commit **\`513e80d1ace21868fd3d3d37734bcd79782abce3\`**, Docker \`rouhin1997/pulsejet:dev-polynomial-513e80d1ace21868fd3d3d37734bcd79782abce3\`.
- INCEPTION-Lite image: \`/home/rnag/PULSEJET_validation/images/inception_lite.sif\`; injection source commit **\`5a9cd1c9b252ffd1797575267c4528fa5b8e81c5\`**.
- Processing host: INAF OACagliari compute node \`node2\`, NVIDIA A40; Singularity \`--nv\` for \`peasoup\`, \`--cleanenv\` and \`PYTHONNOUSERSITE=1\` for INCEPTION-Lite Python calls.
- Polynomial search uses custom **CUDA time-domain acceleration–jerk resampler** \`device_resample_acc_jerk\`, via \`pulsejet::PolynomialTimeDomainResampler\`. Each polynomial template is an \`a j\` row passed to \`peasoup -P <file>\`.
- Per-template harmonic grouping followed by **\`Template_Bank_Polynomial_DopplerDistiller\`** per DM, then existing cross-DM and final harmonic processing. The separately defined \`Template_Bank_Polynomial_Distiller\` is **not** wired into this path. Distillers and matching rules were **not modified** during validation; correct-retention of the best detection does **not** establish correctness of every association.
- Independent CUDA versus CPU polynomial-resampling parity: **15/15 scenarios, 491,520 samples compared with zero reported differences**; \`/home/rnag/PULSEJET_validation/stage2/polynomial_cuda_parity.log\`. This is numerical-parity evidence, not recovery or survey sensitivity.
- Output chain: \`peasoup ... -P bank.txt\` -> \`overview.xml\` -> \`pulsejet_xml_to_pulsarx\` (F0,F1,F2) -> independent \`psrfold_fil --nosearch --pepoch 60000.0015170371\` -> actual PulsarX \`.ar\` -> \`inception_lite.fold_plots.plot_folded_archive\` PNG.

## 2. Experimental input specification

All initial signal-level tests share one original fixed noise realization:

| Field | Specification |
|---|---|
| Source | INCEPTION-Lite nominal Gaussian noise, unsigned 8-bit SIGPROC |
| Baseline file | \`stage3/noise_baseline_fixed.fil\` |
| Sampling | 250 μs per sample, 1,048,576 original samples (262.144 s) |
| Frequency setup | 16 channels, \`fch1=1400.0 MHz\`, \`foff=-1.0 MHz\`, channels 1400–1385 MHz |
| SIGPROC tstart | MJD 60000.0 |
| Raw file | 16,777,483 bytes; 267-byte header |
| Injection | \`P0=0.020 s\` (50 Hz), \`DM=10 pc cm^-3\`, target injected S/N 80, duty cycle 0.06 |
| Motion | stationary; constant acceleration +150 m/s²; combined +150 m/s² and +10 m/s³ |
| Search settings | one DM trial =10; \`-t 1 -n 4 -m 7 --min_freq 20 --max_freq 100 --candidate_diagnostics -v\` |
| FFT | 1,048,576 padded samples; two padded samples after dedispersion in user logs |
| Fold | PulsarX \`--nosearch -b 64 --nsubband 16\`, reference epoch MJD **60000.0015170371** |

**Original synthetic SIGPROC header caveat:** the pinned INCEPTION-Lite image requires explicit float-valued \`--tstart 60000.0 --fch1 1400.0\` in noise generation to avoid an old 4-byte-versus-8-byte numeric header issue; the validated fixed baseline above is usable. The source repository subsequently received the header fix, but the pinned injection image was **not** rebuilt during this study.

## 3. Stage 3 — stationary synthetic-source baseline

File \`stage3/baseline_run_clean/case_0001/noise_baseline_fixed_baseline_stationary_case_0001.fil\`, injection \`a=0,j=0\`.

| Reported quantity | Measurement |
|---|---:|
| Injected spin frequency | 50 Hz |
| Recovered strongest candidate | **50.000186920166 Hz** |
| Recovered period | **0.0199999252322131 s** |
| DM, a, j | 10, 0 m/s², 0 m/s³ |
| PULSEJET search S/N | **83.41** |
| Final representative candidates | **3** |

A true-ephemeris PulsarX truth fold and the top XML-recovered candidate's independent no-search fold each show a narrow phase peak at approximately 0.56. This established end-to-end data conversion and folding for a stationary injected source. Note only the spin frequency was blind here; DM and motion were controlled.

**Figure S1 (two panels):** actual truth and recovered baseline profiles. See §8 figure manifest and companion PDF.

## 4. Stage 4 — acceleration-only injection and controlled recovery

Injection: \`a=+150 m/s², j=0\`, otherwise identical model, same starting noise realization; INCEPTION-Lite file
\`stage3/accel_run_a150/case_0001/noise_baseline_fixed_accel_a150_case_0001.fil\`.

- Nine-row bank \`stage3/polynomial_accel_bank.txt\`: \`a = [-300,-225,-150,-75,0,75,150,225,300] m/s²\`, \`j=0\`.
- Search 386 raw spectral detections -> 77 after per-template harmonic grouping -> 27 post-Doppler representatives -> 27 final, 50 nested association nodes.
- Top bank candidate 50.000186920166 Hz, **a=150 m/s²**, S/N **75.44**, \`nassoc=11\`.
- Single-template true-acceleration control and single-template zero-acceleration control run on the **same injected data**.

| Treatment | Recovered f (Hz) | a (m/s²) | j (m/s³) | Search S/N |
|---|---:|---:|---:|---:|
| Zero correction, a=j=0 | 50.000187 | 0 | 0 | **52.76** |
| Correct-only acceleration | 50.000187 | 150 | 0 | **75.44** |
| Nine-template competition | 50.000187 | 150 | 0 | **75.44** |

**Measured gain:** \`75.44/52.76 - 1 = 0.430\` (~**43.0% higher reported search S/N**). Correct-only and bank candidates agree in frequency and S/N to shown precision; bank retained the highest-S/N detection. The truth and corrected recovered \`.ar\` profiles show almost coincident narrow peaks near phase 0.56; uncorrected pulse is visibly broadened/asymmetric and weaker in the plotting units.

**Figure S2 (three panels):** acceleration truth, corrected recovery, and a=0 fold; actual archives, not simulations of what folds might look like. No statistically calibrated folded S/N or pulse-width fit yet.

## 5. Stage 5 — two-dimensional acceleration–jerk injection and recovery

Injection: \`a=+150 m/s²\`, \`j=+10 m/s³\`, f=50 Hz, DM=10, S/N target 80; file
\`stage3/jerk_run_a150_j10/case_0001/noise_baseline_fixed_jerk_a150_j10_case_0001.fil\`.

- 30-row controlled polynomial bank \`stage3/polynomial_jerk_bank.txt\`: acceleration \`[-150,0,75,150,225,300] m/s²\` × jerk \`[-10,0,5,10,20] m/s³\`; **exact truth included**.
- Search diagnostics: 1 DM, 30 templates, **1536 raw spectral detections** -> **240** after per-template harmonics -> **29** after per-DM Doppler grouping -> **29** final representatives, **222** nested associated nodes.
- Top candidate ID0 at f=**50.000186920166 Hz**, a=**150 m/s²**, j=**10 m/s³**, search S/N=**75.53636** (≈75.54), \`nassoc=37\`; strongest across all 30 competing templates.
- Top-candidate PulsarX conversion: \`F0=50.00018692016603 Hz, F1=-2.501740066464549e-05 Hz/s, F2=-1.667801676256515e-06 Hz/s²\`, consistent with Doppler model.
- Correct-only and zero-jerk controls use **the same jerk-injected filterbank**.

| Treatment | Recovered f (Hz) | a (m/s²) | j (m/s³) | Search S/N |
|---|---:|---:|---:|---:|
| Correct a+j, 30-template bank | **50.000187** | **150** | **10** | **75.54** |
| Correct a+j, **single template** | **50.000187** | **150** | **10** | **75.54** |
| Correct a, **zero jerk** | **49.999233** | **150** | **0** | **49.92** |

**Measured gain:** \`75.54/49.92 - 1 = 0.5132\` (~**51.3% higher search S/N** when jerk is included, for this deliberately large jerk). True-only and multi-template match, indicating highest-S/N candidate preservation by existing grouping.

**Independent PulsarX folding:** the true-ephemeris and recovered candidate 0 folds show a sharp, closely matching phase≈0.56 pulse. The j=0 control still has a recognizable pulse near 0.56–0.58 but reduced prominence; do **not** claim the signal vanishes or is necessarily extremely broad. Archive intensity is arbitrary in the quicklook; these aren't calibrated fold-S/N measurements.

**Figure S3 (three panels):** truth / corrected PULSEJET recovered top / zero-jerk control.

### 5.1 Five strongest search candidates and independent folds

All five were converted from \`search_jerk_bank_01/overview.xml\` by \`pulsejet_xml_to_pulsarx --min-snr 7 --limit 5\`, then independently folded with \`psrfold_fil --nosearch\` and plotted from actual \`.ar\` files.

| Rank/ID | f (Hz) | a (m/s²) | j (m/s³) | Search S/N | Visual fold |
|---:|---:|---:|---:|---:|---|
| **0** | **50.000187** | **150** | **10** | **75.54** | Narrow truth-like pulse |
| 1 | 92.615120 | 75 | 0 | 36.92 | Multiple irregular fluctuations, not a convincing isolated pulse |
| 2 | 69.461815 | 75 | 10 | 26.08 | Noise-like / no obvious coherent pulse |
| 3 | 79.384323 | 75 | 5 | 23.50 | Fluctuating phase profile |
| 4 | 89.836113 | 150 | -10 | 14.52 | Fluctuating phase profile |

Quicklook phase averages **cannot conclusively classify** the other candidates as false positives. Candidate 1 is especially high S/N and was separately investigated against the original synthetic background. No calibrated pulse statistics or phase-versus-time/-frequency plots yet.

**Figure S4 (four panels):** IDs 1–4 independent folds; the actual images are in the companion dossier.

### 5.2 Important distiller limits

- Multi-template run retained **the exact correct top candidate and its S/N**.
- \`nassoc=37\` for ID0, but its 37 associated entries are **not independently validated** as same-source detections. The recorded total of 222 nested nodes even exceeds \`240-29=211\` top-level reductions; recursive nesting/association duplication affects counts.
- Independent CPU candidate-population characterization already exposed both false-merge and under-merging examples with different distillation strategies. This project does **not** alter their wiring absent prior user approval.

## 6. Known issue — anomalous candidate in nominal noise-only filterbank

The same **original no-injection** background searched at DM10 contains candidate f≈92.615Hz S/N=49.19 in the 30-template bank, and S/N=**45.90** in the **single stationary** a=0,j=0 template. The latter rules out nonzero a/j correction and cross-template Doppler grouping as *necessary* causes. Raw, non-dedispersed channel-mean FFT shows no exceptional stationary 92.615Hz fundamental or persuasive harmonic comb. The strong stationary candidate disappears below reporting threshold at DM0. Stationary one-DM sweep:

| DM | 0 | 5 | 8 | 9 | **10** | 11 | 12 | 15 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Matched 92.615 Hz S/N | NR | 10.34 | NR | 9.38 | **45.90** | 10.14 | NR | 10.07 |

\`NR\` means **not reported**, NOT zero S/N. **Cause unresolved**; may involve dedispersion, noise statistics, spectral whitening/harmonic summing or significance calibration. No claim of false-alarm-rate calibration is justified. We explicitly parked this issue to prioritize real-data injection; reopen if realistic data or broad null simulations reproduce it.

Full details, exact noise-only file paths, FFT power ratios, harmonic check and investigation criteria: [dedicated anomaly record](../../tests/DEFERRED_SYNTHETIC_NOISE_FALSE_ALARMS.md).

## 7. Reproduction recipe and source artifacts

Set \`cd /home/rnag/PULSEJET_validation/stage3\`, \`PULSEJET_SIF=$HOME/PULSEJET_validation/images/pulsejet_dev.sif\`.

The central search command for the 30-template jerk study was:

\`\`\`bash
singularity exec --nv "$PULSEJET_SIF" peasoup \
  -i "$PWD/jerk_run_a150_j10/case_0001/noise_baseline_fixed_jerk_a150_j10_case_0001.fil" \
  -o "$PWD/search_jerk_bank_01" \
  --dm_file "$PWD/dm_baseline.txt" \
  -P "$PWD/polynomial_jerk_bank.txt" \
  -t 1 -n 4 -m 7 --min_freq 20 --max_freq 100 \
  --candidate_diagnostics -v
\`\`\`

The injection configurations are \`baseline_clean.json\`, \`accel_a150.json\`, and \`jerk_a150_j10.json\`; each wrote a resolved JSON, injection report and logs. Truth folds are under each run's \`case_0001/folds/<PSR_ID>/\`. All candidate XMLs and individual GPU logs live under \`stage3/search_*/\`.

To convert XML candidate(s):
\`\`\`bash
singularity exec "$PULSEJET_SIF" pulsejet_xml_to_pulsarx \
  search_jerk_bank_01/overview.xml \
  -o search_jerk_bank_01/recovered_top5.cands \
  --manifest search_jerk_bank_01/recovered_top5.json \
  --min-snr 7 --limit 5
\`\`\`

To fold unchanged recovered parameters (same filterbank used by PULSEJET):
\`\`\`bash
singularity exec "$PULSEJET_SIF" psrfold_fil \
  --candfile "$PWD/search_jerk_bank_01/recovered_top5.cands" \
  --pepoch 60000.0015170371 \
  --template /usr/local/share/pulsarx/meerkat_fold.template \
  --nosearch -b 64 --nsubband 16 \
  -f "$PWD/jerk_run_a150_j10/case_0001/noise_baseline_fixed_jerk_a150_j10_case_0001.fil" \
  -o "$PWD/search_jerk_bank_01/recovered_top5_fold"
\`\`\`

Render archive quicklooks with the pinned INCEPTION-Lite image's \`inception_lite.fold_plots.plot_folded_archive\`, passing the actual PulsarX \`.ar\`, output PNG, and a descriptive \`label\`.

## 8. Paper figure manifest and archive paths

Each listed PNG **exists and was inspected** on the HPC or uploaded by the user; source archive files exist from actual PulsarX folding. The companion local PDF embeds these exact uploaded PNG files. For paper submission, promote **calibrated quantitative plots / phase–time–frequency diagnostics** and figures with consistent axes, not the current arbitrary-intensity quicklooks alone.

All relative paths below start at \`/home/rnag/PULSEJET_validation/stage3/\`.

| Figure/panel | PNG path | Meaning |
|---|---|---|
| S1a | \`baseline_run_clean/case_0001/folds/PSR_BASELINE/PSR_BASELINE_folded_profile.png\` | stationary injection truth |
| S1b | \`search_stationary_01/recovered_folded_profile.png\` | stationary recovered, blind frequency |
| S2a | \`accel_run_a150/case_0001/folds/PSR_ACCEL_150/PSR_ACCEL_150_folded_profile.png\` | acceleration truth |
| S2b | \`search_accel_bank_01/recovered_accel_folded_profile.png\` | corrected a=150 |
| S2c | \`search_accel_zero_control/recovered_zero_folded_profile.png\` | uncorrected a=0 |
| S3a | \`jerk_run_a150_j10/case_0001/folds/PSR_JERK_10/PSR_JERK_10_folded_profile.png\` | jerk truth |
| S3b | \`search_jerk_bank_01/top5_profiles/candidate_0_profile.png\` | a=150,j=10 recovered |
| S3c | \`search_jerk_zero_control/recovered_zero_jerk_profile.png\` | a=150,j=0 control |
| S4a | \`search_jerk_bank_01/top5_profiles/candidate_1_profile.png\` | f=92.615Hz anomaly |
| S4b | \`search_jerk_bank_01/top5_profiles/candidate_2_profile.png\` | f=69.462Hz |
| S4c | \`search_jerk_bank_01/top5_profiles/candidate_3_profile.png\` | f=79.384Hz |
| S4d | \`search_jerk_bank_01/top5_profiles/candidate_4_profile.png\` | f=89.836Hz |

**Draft figure captions** (not finalized):
- **S1.** Controlled stationary injected pulsar: known-ephemeris truth fold (left) versus independently recovered candidate fold (right). Both identify the same narrow periodic pulse near phase 0.56.
- **S2.** Constant-acceleration validation: truth, acceleration-corrected recovered candidate, and uncorrected control. The correct +150 m/s² search raises pipeline-reported S/N from 52.76 to 75.44.
- **S3.** Combined acceleration–jerk validation: true-ephemeris, independently recovered a=+150 m/s²/j=+10 m/s³ candidate, and a-only/j=0 control. The correct model yields search S/N 75.54 versus 49.92 for the a-only control.
- **S4.** Four high-ranked non-injected-frequency candidates from the same search. Their phase-averaged profiles are not as convincing as the known pulsar; pre-existing features in the synthetic background and the distinction between search statistic and folded coherence must be considered before classification.

## 9. Next phase — real MeerKAT M62 filterbank

**Proposed observational input (not yet inspected on cluster):**
\`/archive1/ridolfi/DATA/MeerKAT/ALL_TRAPUM_GC_CENTRAL_BEAM/M62_18U-trapum-pgb_cfbf00001sub_CB.fil\`.

Immediate gates:
1. Read-only \`stat/readlink/du\` and SIGPROC header verification of original M62 file (data size, sample format, actual channels, tsamp, frequency setup, tstart, source name, telescope ID, signedness, beam metadata; record if coherent dedispersion or downsampling already present).
2. Prefer a **symlink** inside project work directory to avoid copying an unexpectedly huge observational dataset; **never inject into or overwrite the original**. If injection software requires a mutable file, create an isolated working output/copy or small segment, preserving raw provenance.
3. Uninjected M62 baseline search and independent validation of a known pulsar, if suitable. Then matched controlled injections at several DM, acceleration, jerk, spin-frequency, S/N and observation durations.
4. Compare candidate sets, candidate ranks, coherent fold S/N/profile metrics, null behavior, GPU wall-clock and end-to-end throughput; record model assumptions and any RFI masks.
5. Expand to longer segments and physically motivated binary orbits. Only after controlled observational recovery, quantify sensitivity/completeness as a function of mismatch, segmentation and trials.

**No observational header or file-size values have yet been verified**; do not infer them from the filename.

## 10. Benchmark and PRESTOzl comparison protocol — prospective, not yet measured

The synthetic jerk worker reported **0.085426 s 'DM processing took' for 30 templates / one DM**. This is a **worker-local diagnostic, NOT end-to-end runtime**, and must NOT be used in a paper performance claim. No complete wall-clock benchmarks or apples-to-apples PRESTOzl comparisons have yet been collected in this experiment.

### Required per-run metadata

Record: experiment ID/date, exact immutable image/revision and binary flags, hardware GPU model/count/free memory/driver, host CPU model/threads, RAM, scheduler job ID/concurrent load, file system/storage tier, input file checksum/path, sample count/duration, tsamp, channels/bits/DM layout, FFT size and padding, DM trials, bank size and a/j bounds, frequency range, number of harmonics and detection threshold, I/O bytes, RFI/zapping/preprocessing, and output count. Record cold/warm cache conditions.

### Required timing and reliability metrics

- End-to-end elapsed wall-clock **including input reading, dedispersion, GPU copy, resampling, FFTs, harmonic summing, distillation and output**.
- If possible separately instrument **I/O, dedispersion, preprocessing, resampling, FFT, harmonic summing and distillation**, and peak host RAM / peak GPU VRAM.
- Use repeated samples (at least 3–5 after warm-up) and report median and run-to-run dispersion; do not mix worker timing with full process timing.
- Normalize by **samples × DM trials × template count**, and independently report **effective searched volume**; naive per-template averages can hide overhead or different search coverage.
- For PRESTO/PRESTOzl, specify exact \`zmax\`, \`wmax\`, harmonic settings, frequency selection, FFT size, data representation, CPU threads, GPU acceleration (if any), input file and masking/dedispersion. A wall-clock speed ratio is meaningful only with sufficiently matched completeness and search range.
- Measure **recovery fraction and empirical false-alarm / false-candidate workload** at the same sensitivity/compute budget; compare candidate coherent folding quality and astrophysical injection populations, not only wall-clock.

### Benchmark ledger — initial schema

| ID | Input/segment | DM trials | Polynomial templates | Wall clock (s) | Peak GPU VRAM | PULSEJET recovered S/N | PRESTOzl wall clock (s) | Matched recovery? |
|---|---|---:|---:|---:|---:|---:|---:|---|
| SYN-STATIONARY | fixed Gaussian + P0=20ms, a=j=0 | 1 | 1 | **not benchmarked** | — | 83.41 | — | not tested |
| SYN-ACCEL-9 | fixed Gaussian + a=150, j=0 | 1 | 9 | **not benchmarked** | — | 75.44 | — | not tested |
| SYN-JERK-30 | fixed Gaussian + a=150,j=10 | 1 | 30 | **not benchmarked** | — | 75.54 | — | not tested |
| M62-BASELINE | real filterbank, no injection | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| M62-INJECT-A/J | real filterbank plus known injected model | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

Future benchmark additions should be append-only, with reruns clearly identified and images/version fixed. If pipeline code, candidate filters, frequency range, DM grid or hardware changes, create a new row and do not quietly replace previous numbers.

## 11. Paper-draft wording (conservative)

### Methods candidate

"We tested the acceleration–jerk resampling and candidate-recovery chain using controlled periodic signals injected into SIGPROC-format filterbanks. The initial synthetic dataset comprised 1,048,576 samples at 250 μs sampling time over 16 frequency channels, corresponding to 262.144 s. A 20-ms, DM=10 pc cm^-3 pulse train with a 6% duty cycle was injected into a fixed baseline realization for stationary, constant-acceleration and acceleration–jerk experiments. A GPU polynomial template bank was evaluated at a single controlled DM; detections were independently converted to spin-frequency derivatives and folded using PulsarX without parameter refinement. Dedicated single-template controls isolated the effect of the acceleration and jerk terms."

### Results candidate

"For the +150 m s^-2 acceleration injection, the correct-template candidate achieved a pipeline-reported detection S/N of 75.44, compared with 52.76 under a stationary correction. A nine-template search retained the same strongest candidate and S/N. With an additional +10 m s^-3 injected jerk, a 30-template acceleration–jerk search recovered the exact simulated motion parameters as its highest-ranked candidate (S/N 75.54). A matched single-template run recovered the same S/N, whereas omitting the jerk term reduced the reported detection S/N to 49.92. Independent no-search folded archives show a narrow pulse matching the injected ephemeris for the correctly corrected candidates. These constitute controlled grid-recovery tests; empirical false-alarm calibration, blind parameter recovery and validation on observations remain forthcoming."

### Mandatory limitations sentence

"The initial Gaussian-noise dataset also produced an anomalously strong, narrow-DM noise-only search candidate; its origin remains under investigation, and the synthetic experiments are not used here to establish a calibrated false-alarm probability."

---

**Working practice:** update this log after every major real-data experiment and comparative benchmark; keep figures, folded archives, XML candidate tables and command invocations together; keep the original observational data read-only. No algorithm or third-party distiller rewiring without explicit prior user agreement.
