# PULSEJET polynomial acceleration–jerk engine: research validation and benchmark log

**Document class:** paper evidence / experimental laboratory record (living; begins 2026-10-23).  
**Status:** synthetic-injection recovery verified; empirical false-alarm calibration and observational validation pending.  
**Development branch:** `dev/polynomial-search`, repository `Rouhin1997/PULSEJET_beta`.  
**Companion documents:** [full cluster handoff](../../tests/PHASE_B_CLUSTER_HANDOFF.md), [synthetic-noise anomaly record](../../tests/DEFERRED_SYNTHETIC_NOISE_FALSE_ALARMS.md), [candidate-distiller characterization](../../tests/STEP2_FINDINGS.md).

> **Integrity principle.** The pipeline's reported *search S/N*, a PulsarX archive plot's arbitrary y-axis values, a statistically calibrated folded S/N, and wall-clock computation time are **different measurements**. Do not exchange one for another. All numerical results below are controlled tests, not sky-sensitivity forecasts. The PDF companion `PULSEJET_Synthetic_Validation_Dossier_2026-10-23.pdf` contains the **actual twelve uploaded archive-derived plots**; primary PNGs and `.ar` files remain on the cluster at the paths specified in §8. The PDF is a local report/evidence export, not yet a tracked binary in the repository.

## 1. Provenance: executable, GPU, and algorithm

- PULSEJET compiled Singularity image: `/home/rnag/PULSEJET_validation/images/pulsejet_dev.sif`; source commit **`513e80d1ace21868fd3d3d37734bcd79782abce3`**, Docker `rouhin1997/pulsejet:dev-polynomial-513e80d1ace21868fd3d3d37734bcd79782abce3`.
- INCEPTION-Lite image: `/home/rnag/PULSEJET_validation/images/inception_lite.sif`; injection source commit **`5a9cd1c9b252ffd1797575267c4528fa5b8e81c5`**.
- Processing host: INAF OACagliari compute node `node2`, NVIDIA A40; Singularity `--nv` for `peasoup`, `--cleanenv` and `PYTHONNOUSERSITE=1` for INCEPTION-Lite Python calls.
- Polynomial search uses custom **CUDA time-domain acceleration–jerk resampler** `device_resample_acc_jerk`, via `pulsejet::PolynomialTimeDomainResampler`. Each polynomial template is an `a j` row passed to `peasoup -P <file>`.
- Per-template harmonic grouping followed by **`Template_Bank_Polynomial_DopplerDistiller`** per DM, then existing cross-DM and final harmonic processing. The separately defined `Template_Bank_Polynomial_Distiller` is **not** wired into this path. Distillers and matching rules were **not modified** during validation; correct-retention of the best detection does **not** establish correctness of every association.
- Independent CUDA versus CPU polynomial-resampling parity: **15/15 scenarios, 491,520 samples compared with zero reported differences**; `/home/rnag/PULSEJET_validation/stage2/polynomial_cuda_parity.log`. This is numerical-parity evidence, not recovery or survey sensitivity.
- Output chain: `peasoup ... -P bank.txt` -> `overview.xml` -> `pulsejet_xml_to_pulsarx` (F0,F1,F2) -> independent `psrfold_fil --nosearch --pepoch 60000.0015170371` -> actual PulsarX `.ar` -> `inception_lite.fold_plots.plot_folded_archive` PNG.

## 2. Experimental input specification

All initial signal-level tests share one original fixed noise realization:

| Field | Specification |
|---|---|
| Source | INCEPTION-Lite nominal Gaussian noise, unsigned 8-bit SIGPROC |
| Baseline file | `stage3/noise_baseline_fixed.fil` |
| Sampling | 250 μs per sample, 1,048,576 original samples (262.144 s) |
| Frequency setup | 16 channels, `fch1=1400.0 MHz`, `foff=-1.0 MHz`, channels 1400–1385 MHz |
| SIGPROC tstart | MJD 60000.0 |
| Raw file | 16,777,483 bytes; 267-byte header |
| Injection | `P0=0.020 s` (50 Hz), `DM=10 pc cm^-3`, target injected S/N 80, duty cycle 0.06 |
| Motion | stationary; constant acceleration +150 m/s²; combined +150 m/s² and +10 m/s³ |
| Search settings | one DM trial =10; `-t 1 -n 4 -m 7 --min_freq 20 --max_freq 100 --candidate_diagnostics -v` |
| FFT | 1,048,576 padded samples; two padded samples after dedispersion in user logs |
| Fold | PulsarX `--nosearch -b 64 --nsubband 16`, reference epoch MJD **60000.0015170371** |

**Original synthetic SIGPROC header caveat:** the pinned INCEPTION-Lite image requires explicit float-valued `--tstart 60000.0 --fch1 1400.0` in noise generation to avoid an old 4-byte-versus-8-byte numeric header issue; the validated fixed baseline above is usable. The source repository subsequently received the header fix, but the pinned injection image was **not** rebuilt during this study.

## 3. Stage 3 — stationary synthetic-source baseline

File `stage3/baseline_run_clean/case_0001/noise_baseline_fixed_baseline_stationary_case_0001.fil`, injection `a=0,j=0`.

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

Injection: `a=+150 m/s², j=0`, otherwise identical model, same starting noise realization; INCEPTION-Lite file
`stage3/accel_run_a150/case_0001/noise_baseline_fixed_accel_a150_case_0001.fil`.

- Nine-row bank `stage3/polynomial_accel_bank.txt`: `a = [-300,-225,-150,-75,0,75,150,225,300] m/s²`, `j=0`.
- Search 386 raw spectral detections -> 77 after per-template harmonic grouping -> 27 post-Doppler representatives -> 27 final, 50 nested association nodes.
- Top bank candidate 50.000186920166 Hz, **a=150 m/s²**, S/N **75.44**, `nassoc=11`.
- Single-template true-acceleration control and single-template zero-acceleration control run on the **same injected data**.

| Treatment | Recovered f (Hz) | a (m/s²) | j (m/s³) | Search S/N |
|---|---:|---:|---:|---:|
| Zero correction, a=j=0 | 50.000187 | 0 | 0 | **52.76** |
| Correct-only acceleration | 50.000187 | 150 | 0 | **75.44** |
| Nine-template competition | 50.000187 | 150 | 0 | **75.44** |

**Measured gain:** `75.44/52.76 - 1 = 0.430` (~**43.0% higher reported search S/N**). Correct-only and bank candidates agree in frequency and S/N to shown precision; bank retained the highest-S/N detection. The truth and corrected recovered `.ar` profiles show almost coincident narrow peaks near phase 0.56; uncorrected pulse is visibly broadened/asymmetric and weaker in the plotting units.

**Figure S2 (three panels):** acceleration truth, corrected recovery, and a=0 fold; actual archives, not simulations of what folds might look like. No statistically calibrated folded S/N or pulse-width fit yet.

## 5. Stage 5 — two-dimensional acceleration–jerk injection and recovery

Injection: `a=+150 m/s²`, `j=+10 m/s³`, f=50 Hz, DM=10, S/N target 80; file
`stage3/jerk_run_a150_j10/case_0001/noise_baseline_fixed_jerk_a150_j10_case_0001.fil`.

- 30-row controlled polynomial bank `stage3/polynomial_jerk_bank.txt`: acceleration `[-150,0,75,150,225,300] m/s²` × jerk `[-10,0,5,10,20] m/s³`; **exact truth included**.
- Search diagnostics: 1 DM, 30 templates, **1536 raw spectral detections** -> **240** after per-template harmonics -> **29** after per-DM Doppler grouping -> **29** final representatives, **222** nested associated nodes.
- Top candidate ID0 at f=**50.000186920166 Hz**, a=**150 m/s²**, j=**10 m/s³**, search S/N=**75.53636** (≈75.54), `nassoc=37`; strongest across all 30 competing templates.
- Top-candidate PulsarX conversion: `F0=50.00018692016603 Hz, F1=-2.501740066464549e-05 Hz/s, F2=-1.667801676256515e-06 Hz/s²`, consistent with Doppler model.
- Correct-only and zero-jerk controls use **the same jerk-injected filterbank**.

| Treatment | Recovered f (Hz) | a (m/s²) | j (m/s³) | Search S/N |
|---|---:|---:|---:|---:|
| Correct a+j, 30-template bank | **50.000187** | **150** | **10** | **75.54** |
| Correct a+j, **single template** | **50.000187** | **150** | **10** | **75.54** |
| Correct a, **zero jerk** | **49.999233** | **150** | **0** | **49.92** |

**Measured gain:** `75.54/49.92 - 1 = 0.5132` (~**51.3% higher search S/N** when jerk is included, for this deliberately large jerk). True-only and multi-template match, indicating highest-S/N candidate preservation by existing grouping.

**Independent PulsarX folding:** the true-ephemeris and recovered candidate 0 folds show a sharp, closely matching phase≈0.56 pulse. The j=0 control still has a recognizable pulse near 0.56–0.58 but reduced prominence; do **not** claim the signal vanishes or is necessarily extremely broad. Archive intensity is arbitrary in the quicklook; these aren't calibrated fold-S/N measurements.

**Figure S3 (three panels):** truth / corrected PULSEJET recovered top / zero-jerk control.

### 5.1 Five strongest search candidates and independent folds

All five were converted from `search_jerk_bank_01/overview.xml` by `pulsejet_xml_to_pulsarx --min-snr 7 --limit 5`, then independently folded with `psrfold_fil --nosearch` and plotted from actual `.ar` files.

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
- `nassoc=37` for ID0, but its 37 associated entries are **not independently validated** as same-source detections. The recorded total of 222 nested nodes even exceeds `240-29=211` top-level reductions; recursive nesting/association duplication affects counts.
- Independent CPU candidate-population characterization already exposed both false-merge and under-merging examples with different distillation strategies. This project does **not** alter their wiring absent prior user approval.

## 6. Known issue — anomalous candidate in nominal noise-only filterbank

The same **original no-injection** background searched at DM10 contains candidate f≈92.615Hz S/N=49.19 in the 30-template bank, and S/N=**45.90** in the **single stationary** a=0,j=0 template. The latter rules out nonzero a/j correction and cross-template Doppler grouping as *necessary* causes. Raw, non-dedispersed channel-mean FFT shows no exceptional stationary 92.615Hz fundamental or persuasive harmonic comb. The strong stationary candidate disappears below reporting threshold at DM0. Stationary one-DM sweep:

| DM | 0 | 5 | 8 | 9 | **10** | 11 | 12 | 15 |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Matched 92.615 Hz S/N | NR | 10.34 | NR | 9.38 | **45.90** | 10.14 | NR | 10.07 |

`NR` means **not reported**, NOT zero S/N. **Cause unresolved**; may involve dedispersion, noise statistics, spectral whitening/harmonic summing or significance calibration. No claim of false-alarm-rate calibration is justified. We explicitly parked this issue to prioritize real-data injection; reopen if realistic data or broad null simulations reproduce it.

Full details, exact noise-only file paths, FFT power ratios, harmonic check and investigation criteria: [dedicated anomaly record](../../tests/DEFERRED_SYNTHETIC_NOISE_FALSE_ALARMS.md).

## 7. Reproduction recipe and source artifacts

Set `cd /home/rnag/PULSEJET_validation/stage3`, `PULSEJET_SIF=$HOME/PULSEJET_validation/images/pulsejet_dev.sif`.

The central search command for the 30-template jerk study was:

```bash
singularity exec --nv "$PULSEJET_SIF" peasoup \
  -i "$PWD/jerk_run_a150_j10/case_0001/noise_baseline_fixed_jerk_a150_j10_case_0001.fil" \
  -o "$PWD/search_jerk_bank_01" \
  --dm_file "$PWD/dm_baseline.txt" \
  -P "$PWD/polynomial_jerk_bank.txt" \
  -t 1 -n 4 -m 7 --min_freq 20 --max_freq 100 \
  --candidate_diagnostics -v
```

The injection configurations are `baseline_clean.json`, `accel_a150.json`, and `jerk_a150_j10.json`; each wrote a resolved JSON, injection report and logs. Truth folds are under each run's `case_0001/folds/<PSR_ID>/`. All candidate XMLs and individual GPU logs live under `stage3/search_*/`.

To convert XML candidate(s):
```bash
singularity exec "$PULSEJET_SIF" pulsejet_xml_to_pulsarx \
  search_jerk_bank_01/overview.xml \
  -o search_jerk_bank_01/recovered_top5.cands \
  --manifest search_jerk_bank_01/recovered_top5.json \
  --min-snr 7 --limit 5
```

To fold unchanged recovered parameters (same filterbank used by PULSEJET):
```bash
singularity exec "$PULSEJET_SIF" psrfold_fil \
  --candfile "$PWD/search_jerk_bank_01/recovered_top5.cands" \
  --pepoch 60000.0015170371 \
  --template /usr/local/share/pulsarx/meerkat_fold.template \
  --nosearch -b 64 --nsubband 16 \
  -f "$PWD/jerk_run_a150_j10/case_0001/noise_baseline_fixed_jerk_a150_j10_case_0001.fil" \
  -o "$PWD/search_jerk_bank_01/recovered_top5_fold"
```

Render archive quicklooks with the pinned INCEPTION-Lite image's `inception_lite.fold_plots.plot_folded_archive`, passing the actual PulsarX `.ar`, output PNG, and a descriptive `label`.

## 8. Paper figure manifest and archive paths

Each listed PNG **exists and was inspected** on the HPC or uploaded by the user; source archive files exist from actual PulsarX folding. The companion local PDF embeds these exact uploaded PNG files. For paper submission, promote **calibrated quantitative plots / phase–time–frequency diagnostics** and figures with consistent axes, not the current arbitrary-intensity quicklooks alone.

All relative paths below start at `/home/rnag/PULSEJET_validation/stage3/`.

| Figure/panel | PNG path | Meaning |
|---|---|---|
| S1a | `baseline_run_clean/case_0001/folds/PSR_BASELINE/PSR_BASELINE_folded_profile.png` | stationary injection truth |
| S1b | `search_stationary_01/recovered_folded_profile.png` | stationary recovered, blind frequency |
| S2a | `accel_run_a150/case_0001/folds/PSR_ACCEL_150/PSR_ACCEL_150_folded_profile.png` | acceleration truth |
| S2b | `search_accel_bank_01/recovered_accel_folded_profile.png` | corrected a=150 |
| S2c | `search_accel_zero_control/recovered_zero_folded_profile.png` | uncorrected a=0 |
| S3a | `jerk_run_a150_j10/case_0001/folds/PSR_JERK_10/PSR_JERK_10_folded_profile.png` | jerk truth |
| S3b | `search_jerk_bank_01/top5_profiles/candidate_0_profile.png` | a=150,j=10 recovered |
| S3c | `search_jerk_zero_control/recovered_zero_jerk_profile.png` | a=150,j=0 control |
| S4a | `search_jerk_bank_01/top5_profiles/candidate_1_profile.png` | f=92.615Hz anomaly |
| S4b | `search_jerk_bank_01/top5_profiles/candidate_2_profile.png` | f=69.462Hz |
| S4c | `search_jerk_bank_01/top5_profiles/candidate_3_profile.png` | f=79.384Hz |
| S4d | `search_jerk_bank_01/top5_profiles/candidate_4_profile.png` | f=89.836Hz |

**Draft figure captions** (not finalized):
- **S1.** Controlled stationary injected pulsar: known-ephemeris truth fold (left) versus independently recovered candidate fold (right). Both identify the same narrow periodic pulse near phase 0.56.
- **S2.** Constant-acceleration validation: truth, acceleration-corrected recovered candidate, and uncorrected control. The correct +150 m/s² search raises pipeline-reported S/N from 52.76 to 75.44.
- **S3.** Combined acceleration–jerk validation: true-ephemeris, independently recovered a=+150 m/s²/j=+10 m/s³ candidate, and a-only/j=0 control. The correct model yields search S/N 75.54 versus 49.92 for the a-only control.
- **S4.** Four high-ranked non-injected-frequency candidates from the same search. Their phase-averaged profiles are not as convincing as the known pulsar; pre-existing features in the synthetic background and the distinction between search statistic and folded coherence must be considered before classification.

## 9. Next phase — real MeerKAT M62 filterbank

**Proposed observational input (not yet inspected on cluster):**
`/archive1/ridolfi/DATA/MeerKAT/ALL_TRAPUM_GC_CENTRAL_BEAMS/M62_18U-trapum-pgb_cfbf00001sub_CB.fil`.

Immediate gates:
1. Read-only `stat/readlink/du` and SIGPROC header verification of original M62 file (data size, sample format, actual channels, tsamp, frequency setup, tstart, source name, telescope ID, signedness, beam metadata; record if coherent dedispersion or downsampling already present).
2. Prefer a **symlink** inside project work directory to avoid copying an unexpectedly huge observational dataset; **never inject into or overwrite the original**. If injection software requires a mutable file, create an isolated working output/copy or small segment, preserving raw provenance.
3. Uninjected M62 baseline search and independent validation of a known pulsar, if suitable. Then matched controlled injections at several DM, acceleration, jerk, spin-frequency, S/N and observation durations.
4. Compare candidate sets, candidate ranks, coherent fold S/N/profile metrics, null behavior, GPU wall-clock and end-to-end throughput; record model assumptions and any RFI masks.
5. Expand to longer segments and physically motivated binary orbits. Only after controlled observational recovery, quantify sensitivity/completeness as a function of mismatch, segmentation and trials.

**Location update, 2026-10-23:** the user verified by shell listing that the actual directory is `ALL_TRAPUM_GC_CENTRAL_BEAMS` (plural); the initially supplied singular-directory path does not exist. The exact M62 filename appears in the plural-directory listing. File readability, stat data and header **remain unverified**. The next step is a read-only metadata check at the corrected path.

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
- For PRESTO/PRESTOzl, specify exact `zmax`, `wmax`, harmonic settings, frequency selection, FFT size, data representation, CPU threads, GPU acceleration (if any), input file and masking/dedispersion. A wall-clock speed ratio is meaningful only with sufficiently matched completeness and search range.
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


## 12. How this living paper record is maintained

This file is the **canonical, version-controlled development and paper-evidence ledger**. Add a dated subsection for each significant experiment from the synthetic validation onward. Keep only scientifically usable, well-provenanced results in main tables; uncertainties or unresolved control issues get an explicit companion issue record instead of being silently omitted. Record real data sources, immutable input files and checksums, parameters and injection truth, exact search settings, CPU/GPU and pinned image revisions, XML candidate outputs, raw/archive fold plot references, timing method, wall-clock measurements, repeated-run dispersions, candidate/false-positive diagnostics, interpretation and limits. Never mislabel worker-internal timing as process runtime or search S/N as folded S/N.

Figures are currently indexed by exact HPC source paths in §8, and the user has a self-contained ZIP/PDF copy. **Actual PNG binaries have not yet been committed to the GitHub branch**, so the figure manifest is a reproducibility index, not an assertion that the images render inline on GitHub. Promote selected originals or re-rendered publication figures into a tracked `docs/paper/figures/` directory when feasible, with captions and original archive provenance. Do not treat the separately created PDF as the primary living document.

For observational data, record the **unaltered archive path**, symlink or working copy arrangement, file header, original-pulsar/RFI context, and an observational no-injection control before any injection. The initial user-selected file is at `/archive1/ridolfi/DATA/MeerKAT/ALL_TRAPUM_GC_CENTRAL_BEAMS/M62_18U-trapum-pgb_cfbf00001sub_CB.fil` (pending file stat/header verification). Any injected outputs must live outside the archive and must never overwrite the original.


### Real M62 observation metadata checkpoint — file stat verified (2026-10-23)

Read-only check on compute node `node2` confirmed the input exists
and is readable at
`/archive1/ridolfi/DATA/MeerKAT/ALL_TRAPUM_GC_CENTRAL_BEAMS/M62_18U-trapum-pgb_cfbf00001sub_CB.fil`
(plural `BEAMS`, not `BEAM`). File is a regular file, owned by
`ridolfi` group `pulsar`, mode `-rw-r--r--`,
size **15,177,064,483 bytes** (~14.14 GiB), modified
**2022-04-21 23:58:40 +0200**. Resolved path identical to given path.
Archive storage `/archive1` is network-mounted as a large
shared filesystem. No SIGPROC header keys, observation duration,
or sample format have been read yet, so these remain **TBD**.
Keep observational original immutable and use symlink for baseline
searches; injected outputs/derived segments must be separate.
Next: read-only standard SIGPROC header parser on exact file, then
decide safe working-link/copy strategy. Benchmark full wall-clock
on real observation and later use matched PRESTOzl controls; no
new timing measured yet.


### M62 SIGPROC header verified: observational stage input (2026-10-23)

Raw archival filterbank, untouched:
`/archive1/ridolfi/DATA/MeerKAT/ALL_TRAPUM_GC_CENTRAL_BEAMS/M62_18U-trapum-pgb_cfbf00001sub_CB.fil`.
Read-only SIGPROC header parsed on node2:

| Item | Verified value |
|---|---|
| Header bytes | 291 |
| File bytes | 15,177,064,483 (~14.14 GiB) |
| telescope_id / machine_id / data_type | 64 / 11 / 1 |
| source_name | J1701-3006B |
| src_raj / src_dej | 170112.67 / -300649.0 |
| barycentric | 0 |
| nbits / nifs / nchans | 8 / 1 / 256 |
| fch1 / foff (MHz) | 1086.87109375 / -2.125 |
| Lowest channel center (MHz) | 544.99609375 |
| tstart (MJD) | 59689.96788709412 |
| tsamp (s) | 0.0000602352941176 |
| samples | 59,285,407 (exact inferred from bytes and sample format) |
| duration | 3571.073927526622 s = 59.5178987921 min |

Archive file modified 2022-04-21 23:58:40 +0200; regular file, readable on node2; located on network-mounted `/archive1`.
Header names the known M62 pulsar J1701-3006B; actual detectability in this file not yet measured.
These values must be used to choose legal sample/FFT windows and correct dispersion configuration.

First real-data step: establish project-side symlink to the immutable archive original and test container-visible header/size via Singularity with an explicit `/archive1` bind.
Then run a short (~four-minute) **uninjected** segment first; log cold/warm end-to-end wall-clock and separate processing stages if available.
Only generate injected **working segments** outside `/archive1`, never overwrite or write through original symlink.
PRESTOzl timing and comparable search bounds have not yet been measured.


### M62 preprocessing warning: archival filterbank may have prior DM=114 correction (2026-10-23)

Published M62 TRAPUM reduction methodology states that recorded data
were **incoherently dedispersed at DM=114.00 pc cm^-3** before
downsampling channel count to 256 and storage, with UHF follow-up
DM trials spanning 108.00 to 120.20 pc cm^-3:
[Vleeschower et al., *Discoveries and timing of pulsars in M62*,
MNRAS 530, 1436 (2024)](https://academic.oup.com/mnras/article/530/2/1436/7632774).
This is **consistent** with the M62 real file's 256 channels,
but the precise processing provenance of this specific beam file
still needs confirmation. Its SIGPROC header does **not** contain
a refdm field, so do not assume the prior DM has been encoded
for a search program. **Do not naively dedisperse the full
DM=113.44 pc cm^-3 again** without confirming how
PULSEJET/dedisp and the `--cdm` option interpret already
dedispersed files. The known J1701-3006B has
P≈3.593852ms (~278.25Hz) and published DM≈113.44–113.46;
searching only the synthetic-test 20–100Hz band would miss
this known pulsar. M62B can eclipse; lack of recovery in an
arbitrary 4-minute segment would not automatically mean
failure of the pipeline.

NEXT read-only command: inspect the deployed `peasoup --help`
options for coherent/reference DM, `--start_sample`,
`--fft_size` and `--nsamples`; inspect the corresponding code
if help text cannot establish whether the *existing* DM is
subtracted or simply used for DM-trial planning. Then run a
4-minute read-only baseline search on a pinned segment and
time it with whole-process `/usr/bin/time`.
No changes to immutable archive file, existing distillers,
or search algorithm.


### Related M62 beam header cross-check (different file) (2026-10-23)

User separately supplied a detailed SIGPROC summary from **a different file**,
`/archive1/ridolfi/DATA/MeerKAT/ALL_TRAPUM_GC_CENTRAL_BEAMS/M62_18U-trapum-pgb_cfbf00010sub_r1.fil`;
do NOT conflate it with our selected `...00001sub_CB.fil` (291-byte header, `source_name=J1701-3006B`).

| Field | Separate `...00010sub_r1.fil` |
|---|---|
| Header bytes | 287 |
| Source name | M62_UHF |
| Observation UTC | 2022-04-20 23:13:45.4912 |
| MJD start | 59689.96788762954384 |
| RA, Dec | 17:01:13.5500, -30:06:55.3000 |
| Time sample | 60.2352941176 us |
| Channels and 8-bit type | 256, 8-bit unsigned |
| fch1/foff | 1086.87109375 MHz / -2.125 MHz |
| Band centre and total bandwidth | 815.93359375 MHz, 544 MHz |
| Samples / duration | 59,285,407 / 3571.07392753 s |

Shared sample/channel/duration properties independently corroborate the observation setup. The source naming, coordinates, start time and header byte count differ, so they are **not interchangeable**.
Published M62 TRAPUM processing records incoherent pre-dedispersion at DM 114.00 pc cm^-3, RFI cleaning and channel downsampling to 256 before storage (Vleeschower et al. 2024, MNRAS 530,1436, https://academic.oup.com/mnras/article/530/2/1436/7632774). This strengthens the need to verify what DM values the existing search software expects for this preprocessed observation. Neither file header itself explicitly records `refdm`.


### Selected M62 central-beam readfile cross-check (2026-10-23)

User ran `readfile` **inside Singularity** against the exact selected file `M62_18U-trapum-pgb_cfbf00001sub_CB.fil`, independently confirming the manually parsed header:
`source_name=J1701-3006B`; UTC observation date `2022-04-20T23:13:45.4449`; RA `17:01:12.6700`; Dec `-30:06:49.0000`; MJD `59689.96788709412067`; sample time `60.2352941176 us`; channels 256, unsigned 8-bit, 2 polarizations summed; centre 815.93359375 MHz, low 544.99609375 MHz, high 1086.87109375 MHz, width 544 MHz, per-channel width 2.125 MHz; spectra per file 59285407, time per file 3571.07392753 sec; header bytes 291. `readfile` output also lists telescope MeerKAT and beam 0/1. All major fields agree with Python header parse.

**Segment proposal (not yet executed):** 2^22=4,194,304 samples at 60.2352941176 us gives approximately 252.65 seconds. This is a controlled short baseline, not the complete 59.52-minute observation. Use the raw archive original only through the project symlink, already verified readable in pinned container; avoid any copy of entire ~15GB observation at this stage.

**DM-processing gate remains open:** published TRAPUM M62 reduction reports prior DM114 incoherent dedispersion but exact handling by this built `peasoup` is not yet verified. Inspect the deployed help and implementation before setting trial DM or applying `--cdm`; do not blindly dedisperse raw DM 113.44 again, nor assume `--cdm` means subtract prior *incoherent* DM. The header contains no `refdm`.


### Stage 6 benchmark planning: 64 host CPUs and actual `--cdm` use in polynomial mode (2026-10-23)

User reports **64 logical CPUs available on node2** in addition to the previously verified two NVIDIA A40 GPUs. The number of CPUs, per-socket topology, core/hyperthread layout, CPU model, GPU assignment/affinity and competing jobs are not yet measured. For rigorous benchmarking, log `lscpu`, `nvidia-smi`, `SLURM_JOB_ID` if applicable, CPU affinity and I/O location. PRESTOzl should be tested at explicit CPU counts and compared with PULSEJET on identical data/search coverage.

**Important CLI semantics verified against source on development branch:** in `include/utils/cmdline.hpp`, `-t/--num_threads` is described as **"The number of GPUs to use"**, **not 64 CPU threads**. Keep `-t 1` for controlled single-A40 baseline (64 would be wrong); separately measure the second A40/multi-GPU scaling. In `src/pipeline_multi.cu`, polynomial-mode dedispersion uses `dedisperser.set_dm_list(dm_list_chunk)` and `dedisperser.dedisperse(...)`; `args.cdm` is used to build acceleration plans in the separate acceleration-only path (`acc_plan.generate_accel_list`), and to report acceleration-plan statistics; it does **not** appear to subtract a DM reference from explicit polynomial `-P` DM trials. The `--cdm` description "Coherent DM of filterbank file" does **not**, by itself, establish correct handling of this possibly *incoherently* prededispersed observational file. Do not set `--cdm 114` expecting `--dm_file 113.44` to become residual -0.56 automatically.

**Baseline policy:** start with an *uninjected, unmodified* 2^22-sample (~252.645 s) M62 segment searched at explicit **additional DM0** and one stationary polynomial template, with the known pulsar's ~278 Hz frequency included in the selected band. This is a read-only **pipeline/performance smoke test** under an assumed prior-DM-corrected input, **NOT** evidence the true residual DM has been optimized. The true residual may be negative and smear the known 3.6-ms pulsar; verify archival preprocessing, and design an appropriate residual-DM correction before claiming non-detection or performing sensitivity tests. Do not directly inject into the archival original or symlink; later create an isolated ~1 GiB segment for controlled injections.

Record whole-process `/usr/bin/time -v` timing, input path and cache state for every benchmark. Distinguish initial cold archive I/O timing from warm repeat timing, CPU-intensive preparation from GPU search, and benchmarking compared with matched PRESTOzl. No actual M62 runtime has yet been recorded.

### M62 baseline attempt 01: CUDA worker abort before search (FAILED) (2026-10-23)

**Status: failed; zero valid benchmark or recovered candidates.** First attempted search on M62 256-channel 8-bit original using verified symlink `stage6_m62/m62_original.fil`, search segment `--start_sample 0 --nsamples 4194304 --fft_size 4194304` (~252.65 seconds), single residual DM 0, polynomial stationary template `0 0`, `-t 1 -n 4 -m 7 --min_freq 200 --max_freq 350 --candidate_diagnostics -v`. Host `node2`, singularity with `--nv --bind /archive1:/archive1`, immutable PULSEJET SIF.

First two invocations never launched PULSEJET because host lacked `/usr/bin/time`; do not treat those attempts as runs. Third invocation used bash built-in `time`, stdout piped to `tee` with `set -o pipefail`, producing:

```text
Segment start sample: 0, Segment end sample: 4194304
Effective nsamples 4194304 points
Loaded 1 templates
1 DM trials
0
Executing dedispersion
Starting to dedisperse filterbank from Sample:0 to 4194304 samples, with gulp size of 1000000 samples
Setting FFT length to 4194304 points
Starting searching...
Joining worker threads
terminate called after throwing an instance of 'thrust::system::system_error'
what(): trivial_device_copy D->H failed: cudaErrorInvalidValue: invalid argument
```

**Exit 134 (Aborted), wall-clock to abort 13.577 s; CPU user 0.129 s; system 2.831 s**. These timings measure a failed startup/run and MUST NOT be reported as successful pipeline performance. The observation was read and dedispersed enough to reach GPU worker launch; worker failed before any debug output from per-DM preprocess or resampler, so neither candidate distillation nor full polynomial template search ran. Fatal exception may have arisen during GPU worker object setup; exact cause NOT established. Do not claim hardware failure, memory exhaustion, dedispersion bug, or jerk resampler bug based on this lone trace.

Next one-step isolation: rerun same real M62 file, same DM0/template/search options, but `--nsamples 1048576 --fft_size 1048576` (~63.16 s), new output directory and fresh bash wall-clock log. If successful, suggests data/FFT-size sensitivity; if failure persists, investigate input/config/GPU worker constructor and environment, then run device health checks. Keep original archive untouched; no code or distiller modifications without user approval.


### M62 baseline attempt 02: same CUDA error at 2^20 samples (2026-10-23)

Same M62 original through symlink; same DM0 and stationary polynomial template, same `-t 1 -n 4 -m 7 --min_freq 200 --max_freq 350`, but **2^20=1,048,576** samples (~63.16 s) and corresponding FFT length. Output `stage6_m62/baseline_1m_dm0_stationary_01.log` and `.time`.

Log reached `Starting searching...` and `Joining worker threads`, then failed with **the exact same** `thrust::system::system_error` / `trivial_device_copy D->H failed: cudaErrorInvalidValue: invalid argument`. Bash wall-clock to failure **9.973 s**, user CPU **0.099 s**, system CPU **2.149 s**, **exit 134**. No valid science products or end-to-end runtime. Failure is **not exclusive** to the 2^22 (~252-s) FFT size.

Important interpretation correction after source audit: in `src/pipeline_multi.cu`, worker writes verbose `std::cout` progress such as `Copying time series to device`, `Computing stats`, etc. However stdout was piped to `tee`, so C++ stdout may be *buffered* and lost on `std::terminate`; the absence of worker-level messages **does not prove** failure during worker constructors or before preprocessing. GPU statistics call `stats::stats` -> `GPU_rms/GPU_mean`, whose Thrust transform/reduce in `src/kernels.cu` may copy scalar results device-to-host, a **possible** D→H transfer site; this is **not yet a confirmed cause**.

Next diagnostic (no source edits): repeat the 2^20 DM0 stationary M62 search with **line-buffered stdout** (`stdbuf -oL -eL` inside SIF) and `CUDA_LAUNCH_BLOCKING=1` for synchronous CUDA error localization, new output directory. Treat its timing as diagnostic/non-comparable. Record the last reliably flushed worker progress line. Do not edit either distiller or the jerk resampler unless a concrete fix is discussed and approved.


### Root-cause candidate isolated: invalid PeakFinder frequency interval (2026-10-23)

Read-only instrumented M62 repeat (`stage6_m62/baseline_1m_cuda_debug_01/debug.log`) with `stdbuf -oL -eL` plus `CUDA_LAUNCH_BLOCKING=1`, single a=j=0 polynomial template and 2^20 samples, again aborted with 134. The last messages confirm `Copy from host complete`, `Removing baseline`, `Computing stats`, `Rednoise removal and zapping complete`, `Polynomial (acc+jerk) resampling complete`, `Normalising power spectrum`, `Harmonic summing`, `Finding peaks`, then `thrust::system::system_error ... trivial_device_copy D->H failed ... cudaErrorInvalidValue`. This **excludes the hypothesis that the observed crash necessarily occurred at early worker construction** and strongly localizes the failure to peak extraction/transfer; the causal site still awaits controlled test.

Source audit discovered a concrete inconsistent bin calculation in `include/transforms/peakfinder.hpp` around lines 78–86: `orig_size=2*(size-1)`, `nyquist=bin_width*size`, `start_idx=int(orig_size*(min_freq/nyquist)*2^nh)` implies approximately **2 * requested minimum frequency**, whereas `max_bin` uses only requested maximum. Thus command `--min_freq 200 --max_freq 350` gives internal start around 400Hz > end 350Hz. `src/kernels.cu:device_find_peaks` is then given `n-start_index < 0` to `thrust::copy_if`, which is an invalid iterator range and a strong explanation for the exception. An internal bug even when search completes: underreported coverage between requested minimum and ~2×minimum. Earlier synthetic `20–100Hz` trials could still detect 50Hz, so recovered 50Hz result stands, but 20–40Hz range was likely omitted.

Documented separately at [Open PeakFinder frequency-bound issue](../../tests/PEAKFINDER_FREQUENCY_BOUND_ISSUE.md). **No code changes**. Next diagnostic will rerun the same 2^20-sample M62 observation with `--min_freq 100 --max_freq 350`, effective starting boundary near 200Hz, and a new output directory; all other relevant arguments held fixed. Do not label the 9.973s/13.577s failed wall times benchmarks.


### M62 PeakFinder A/B workaround passes: first complete real-data smoke test (2026-10-23)

Read-only rerun of 2^20-sample (~63.16 s) M62 central-beam original via symlink and container on `node2`, with DM 0, stationary polynomial template `(a,j)=(0,0)`, `-t 1 -n 4 -m 7`, and `--max_freq 350`. Exactly one search-band parameter changed from aborting `[200,350]Hz` test: **`--min_freq 100` instead of 200**. Kept `CUDA_LAUNCH_BLOCKING=1` and line-buffered stdout for diagnosis.

**Exit status 0 / `all done`**. Search progressed beyond `Finding peaks` through harmonic and polynomial Doppler distillation, DM/final harmonic distillation, and wrote output files. Candidate diagnostics: DM trials 1, polynomial template trials 1, 3 raw spectral detections, 2 after harmonic grouping, 2 after polynomial Doppler grouping, 2 final representatives, 0 recursively nested associated nodes. Console internal `DM processing took 0.098978 seconds`; **no measured end-to-end elapsed time was collected**. Do NOT enter that internal number in the whole-pipeline benchmark column.

Source logic in `include/transforms/peakfinder.hpp` calculates the start bin using a `orig_size / pspec.get_nbins()` multiplier of ~2, effectively making a requested `[200,350]Hz` spectrum search into `[400,350]Hz` (negative iterator range); `[100,350]Hz` becomes approximately `[200,350]Hz` and succeeds. Controlled A/B behavior substantially corroborates [the open PeakFinder bug report](../../tests/PEAKFINDER_FREQUENCY_BOUND_ISSUE.md). This is an **unfixed code-level defect**; correct frequency bounds/empty-range safeguards and regression tests need explicit user approval before source changes. The successful `-P` search used an unmodified pinned image and its 2 final candidates have **not yet been physically checked** (XML frequencies, folded pulse). Absence/presence of pulsar J1701-3006B remains unconfirmed.

Next suitable read-only HPC action: inspect `stage6_m62/baseline_1m_frequency_fix_test_01/overview.xml`, saving or printing the two candidate frequencies/DM/SNR and relevant processing stats. That does not require a new GPU run. Future valid benchmark: after a user-approved minimal fix and rebuilt immutable image, search exactly the requested full frequency band and time entire successful process with an ordinary runtime environment (not CUDA_LAUNCH_BLOCKING=1).


### M62 first completed XML results: two low-S/N non-target candidates and stage timings (2026-10-23)

**Status:** first complete real-filterbank stationary/single-DM pipeline search; frequency-bound workaround in place, source bug still unfixed.

Input `/archive1/ridolfi/DATA/MeerKAT/ALL_TRAPUM_GC_CENTRAL_BEAMS/M62_18U-trapum-pgb_cfbf00001sub_CB.fil` through validated symlink. Source `J1701-3006B`. First 1,048,576 samples; `tsamp=60.2352941176 us`, segment midpoint MJD `59689.9682526108`. One DM 0 trial and single `(a,j)=(0,0)` polynomial bank template. `-t 1 -n 4 -m 7 --min_freq 100 --max_freq 350`; owing to confirmed PeakFinder bug this gives an effective start near 200 Hz, **not** the declared 100 Hz. `CUDA_LAUNCH_BLOCKING=1`, line-buffered output, SIF source commit `513e80d1ace21868fd3d3d37734bcd79782abce3`, GPU NVIDIA A40. Full XML:

`/home/rnag/PULSEJET_validation/stage6_m62/baseline_1m_frequency_fix_test_01/overview.xml`.

| Candidate XML id | Period (ms) | Derived f (Hz) | DM applied | a (m/s^2) | j (m/s^3) | Search S/N | Folded S/N |
|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 3.9310574956 | 254.384475708 | 0 | 0 | 0 | 9.076230 | not measured (`folded_snr=0` placeholder) |
| 1 | 4.5856271907 | 218.072677612 | 0 | 0 | 0 | 8.016245 | not measured (`folded_snr=0` placeholder) |

Both candidates have `nh=3`, `nassoc=0`, `is_physical=1` XML flags, which are **pipeline metadata, not independent astrophysical confirmation**. No candidates near published J1701-3006B f≈278.25 Hz; given DM/pre-dedispersion ambiguity, binary acceleration, short sample window and possible eclipses, **absence of the target in this limited search is not scientifically conclusive**. No independent PulsarX fold or RFI assessment has been carried out.

| XML `execution_times` component | Time (seconds) |
|---|---:|
| Reading | 0.0064640003 |
| Dedispersion | 0.0943040028 |
| Searching | 0.1018850058 |
| Folding | 0 |
| **Internal pipeline total** | **4.0568690300** |

These are measured internal instrumentation values from a **completed** run; the accompanying debug setup did **not** measure an outer process wall-clock time. `searching` != full execution time, and total internal time != end-to-end Singularity wall-clock. `CUDA_LAUNCH_BLOCKING=1` slows/synchronizes GPU execution and should be removed for formal performance benchmarks. Internal per-DM processing had been separately reported as 0.098978 s, not directly equivalent to wall-clock or XML total.

Diagnostic candidate diagnostics: 3 raw spectral detections -> 2 after per-template harmonic distillation -> 2 after per-DM polynomial grouping -> 2 after cross-DM and final harmonics, 0 nested association nodes. This supports successful XML output but not calibrated astrophysical correctness.

**Next:** preserve the existing issue/diagnostics; run the first ~253s baseline **without CUDA_LAUNCH_BLOCKING**, using the established `--min_freq 100 --max_freq 350` workaround and with independent Bash end-to-end elapsed timing; keep it designated *pre-fix provisional*. Then discuss and obtain explicit user approval for the minimal peakfinder lower-frequency computation correction and regression tests, build a new pinned SIF, and re-run the original true `[200,350]` request before treating benchmarks as paper grade.


### Published M62B UHF brightness/eclipse and INCEPTION real-filterbank injection capability (2026-10-23)

**M62B brightness and exact observation provenance:** Vleeschower et al. (2024, MNRAS 530 1436–1456, https://doi.org/10.1093/mnras/stae816), Table 4 gives M62B flux densities **S_816 = 0.78 mJy** and **S_1284 = 0.47 mJy**, calculated from combined observations **excluding eclipsed subintegrations**. M62B is an eclipsing redback in ~3.47 hr orbit, with reported UHF eclipses lasting ~22–25% of an orbit (depending on subband). The published observation table explicitly lists **2022-04-20 23:13 UTC, UHF 816 MHz, 60 min** as a session in which M62B was observed in **both eclipse ingress and egress**. This session matches the exact selected M62 filterbank's 2022-04-20T23:13:45.4449 header. As a result **four-minute detectability is plausible but not guaranteed**, especially at the beginning of the file; choose an out-of-eclipse interval from ephemeris/fold evidence before using the real M62B as a sensitivity reference. Earlier ~63-s stationary/DM0 search failing to report near 278.253Hz is not meaningful non-detection.

**INCEPTION-Lite existing-real-filterbank ability, code verification:** `Rouhin1997/inception_injection_test_tool` branch `dev/pulsejet-injections`, `inception_lite/runner.py` accepts a real input SIGPROC `filterbank` path and validates its header, invokes unchanged `injector/SCRIPT_inject_pulsars.py` with `--fb` and `--output`, and rejects pre-existing case directories; `injector/signal_injector.py` reads original byte data in multiple blocks and writes a **distinct new `.fil` output**. It already supports a **full-length real observation** in principle, subject to free disk storage and runtime, with block-wise processing and configurable multiprocessing `ncpu`. For an **arbitrary segment**, the current runner does **not directly expose** a simple `start_sample/nsamples` selection analogous to PULSEJET's CLI; prepare a separate valid SIGPROC sub-filterbank with header `tstart` advanced by `start_sample*tsamp/86400` and exactly the selected samples, then inject onto that file. Confirm segment extraction/header consistency and output truth folds with a small test before investing in 15GB full-length injection. Preserve original archive and existing symlink read-only.

**Physical injection caveat:** This M62 dataset is likely already incoherently pre-dedispersed at nominal DM 114 pc cm^-3 (published TRAPUM reduction method). Injection into the processed background must use a **consistent residual-DM model / reference-DM convention**, not blindly inject the full astrophysical DM 114 and then dedisperse 114 a second time. Confirm with the original preprocessing and injection code first; reconcile barycentric/topocentric frame and segment reference epoch for acceleration/jerk. `ncpu` belongs to INCEPTION multiprocessing, whereas PULSEJET `-t` counts GPUs. No observational injections or wall-clock benchmarks were performed yet.

### Stage 6 design discussion: inject full M62, search paired ~15 min windows (2026-10-23)

User prefers using the **entire M62 observational filterbank as INCEPTION-Lite injection input**, rather than manually extracting sub-filterbanks, then performing **longer ~15-minute PULSEJET searches** for injected plus natural astronomical signals. This is technically feasible: INCEPTION-Lite operates block-wise on full SIGPROC 8-bit file (injected output separate from archive source); PULSEJET supports selecting `--start_sample` + `--nsamples` on the full new observation, so segment extraction is not required. User's goal is an end-to-end combined artificial+real signal validation, not a lengthy series of uninjected short-baseline runs. The earlier 63s stationary run was merely an essential real-I/O/GPU smoke test that revealed the PeakFinder bug.

**Matched paired design:** retain immutable original `...00001sub_CB.fil` (~14.14GiB), make *one independently named full-length injected output* (~14.14GiB), and run the same start/length, DM plan, polynomial template bank, thresholds, and GPU settings on injected and original filterbanks. Compare exact candidate frequencies, acceleration, jerk, S/N and fold profiles to separate original celestial/RFI candidates from actual injected recovery; injection truth is known. A variety of injected pulsars can co-exist with the natural pulsars in a single filterbank. Search a 15-minute window selected with eclipse awareness for M62B (known ingress/egress during 2022-04-20 observation), later adjacent windows/full length. A 15min segment of full 59.52min observation yields only ~sqrt(15/59.52)~0.502 of the SNR for a stationary constant-brightness injection whose *nominal `SNR` is normalized for the full file*; set injected amplitudes or expectations appropriately. Injection acceleration epoch `ACCEPOCH=0.5` refers to the midpoint of the *full* 59.52-min file, not each 15min PULSEJET search segment; convert expected a/f at each segment midpoint before comparing.

**Science gate:** the processed M62 original was likely incoherently dedispersed at DM114. The upstream INCEPTION `injector/propagation_effects.py:get_DM_delays` uses parameter `DM` as *across-channel delay* (it does not subtract `cDM` there); `cDM` appears in the *intrachannel smearing* expression (`DM-cDM`) instead. Consequently, on a pre-dedispersed observed input, simply passing `DM=114` to the injector will reintroduce a large DM sweep; passing `DM≈0` will model only residual across-channel delay and may underrepresent physical intrachannel smearing. Need a scientifically controlled, documented residual-dispersion and intra-channel pulse broadening treatment before claiming a validated real-data injection sensitivity result. Do not change injection/Peasoup code without user approval.

**Engineering gate:** correct/test the known PeakFinder `start_idx` factor-of-two defect before science or performance runs to guarantee requested frequency coverage. Keep a pre-fix image for A/B comparison and build a separately pinned post-fix image. For 15-minute search, specify both `--nsamples` and an FFT size at least as large (usually next power of two) and verify padding. Record full external wall time for both original and injected, with same cached-I/O conditions, known CPU/GPU configuration. Disk/storage availability and INCEPTION 64-CPU scaling untested, so first full-injection dry-run/config validation with output on scratch, not archival path.


### Stage 6 agreed pilot: single full-length M62 acc+jerk injection and independent PulsarX truth fold (2026-10-23)

Research decision: user proposes **one injected accelerated+jerked pulsar added to full M62 UHF filterbank**, then independent **PulsarX confirmation fold and a proper diagnostic plot** *before* asking PULSEJET to recover it; once successful, sweep tailored `(DM,a,j)` grids, then generated polynomial-bank coverage tests and finally matched PRESTOzl comparison. Original natural signals remain in background; parallel DM coverage near M62B may later reveal the real pulsar, but **real source detection is secondary, not a precondition for injection**. User explicitly notes original header `J1701-3006B` may be only beam-pointing placeholder; specific beam's known pulsar presence is **unconfirmed**, among roughly 18 beams; don't equate filename/source_name with a detection.

Scientific provenance uncertainty: M62 TRAPUM paper Vleeschower et al. 2024 (https://doi.org/10.1093/mnras/stae816) says stored 256-channel filterbanks were *incoherently* dedispersed at cluster DM114; coherent beamforming does not itself entail coherent dedispersion. Nevertheless the actual selected file's **specific processing chain** is not independently documented in its header (`refdm=0` or absent). Avoid claiming coherent or incoherent file provenance absolutely. Deliberate synthetic injection uses a known **additional dispersive DM** relative to file as received; it is not an astrophysical total DM or a search DM for M62B.

**Pilot config committed to INCEPTION-Lite repo**, branch `dev/pulsejet-injections`: [`configs/m62_uhf_full_aj_truthfold_pilot.json`](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/configs/m62_uhf_full_aj_truthfold_pilot.json), commit `39b1db66ac3d246407e31fb79dd2d41027f06af2`. No injector or search algorithm source modified.

| Config parameter | Pilot value |
|---|---|
| Background .fil | `stage6_m62/m62_original.fil` (read-only symlink, full 59.52 min) |
| Output dir | `stage6_m62/injections_full_m62_aj_pilot_01` (new, original preserved) |
| Source ID | `PULSEJET_M62_PILOT_AJ` |
| P0 at full-file midpoint | 4.9 ms (f≈204.08163 Hz) |
| Additional injected DM | +6.0 pc/cm3 measured relative to supplied processed file |
| Acceleration a at midpoint | +120 m/s2 |
| Jerk j at midpoint | +0.15 m/s3 |
| Full-observation nominal injection S/N | 160, **not** predicted 15-min search S/N |
| Intrinsic duty cycle | 5% |
| Frame / epoch | topocentric, `ACCEPOCH=0.5`, no explicit `PEPOCH` |
| Deterministic seed | 20261023 |
| Injector CPUs | 8 (initially; 64 available), 0.02 GB gulp |
| Folding | integrated `psrfold_fil` with template `/usr/local/share/pulsarx/meerkat_fold.template`, 128 bins, 32 subbands, enabled |

One new full injected `.fil` is expected to be ~15.2 GB decimal (~14.14 GiB), plus fold archive/log/figures; check home/scratch filesystem free space and any account quotas **before** running. The pinned integrated image is `$HOME/PULSEJET_validation/images/inception_lite.sif` at commit `5a9cd1c9b252ffd1797575267c4528fa5b8e81c5`, subject to path/executable verification. The host `node2` has 64 CPU logical processors but not necessarily 64 free allocated cores. Use modest 8 initially.

**Plot quality requirement:** PULSEJET/INCEPTION currently has a fallback plot `inception_lite/fold_plots.py` rendering only a phase-averaged profile from a **real PulsarX .ar** archive. For publication-style verification, create/show multi-panel **pulse phase profile + subintegration/time vs phase + frequency vs phase** and optional DM or acceleration curves only when a real archive supports them; don't fabricate search diagnostic curves or label the fallback 1D profile as complete. Generated `.ar` and PNG reside on cluster; user must provide/upload actual figure for assistant to display here.

**Immediate next cluster step:** preflight exact integrated SIF, PulsarX executable, fold template, M62 symlink readability, and >~15GB free plus quotas. Then copy/paste pinned JSON config onto node2 (or git fetch) and perform INCEPTION `--dry-run`, then full injection with enabled PulsarX fold. Do NOT begin expensive CPU/GPU run or alter original file until preflight passes. Later search central ~15 min segment with a/j values calculated at selected segment midpoint, correct PeakFinder source bug as separately documented before any formal search grid, and compare against identical uninjected control search.


### First full-M62 INCEPTION run blocked by host user-site pandas/NumPy conflict (2026-10-23)

INCEPTION-Lite/PulsarX image preflight passed (`python3 -m inception_lite --help`, `psrfold_fil` executable, fold template, archive readability) and JSON `--dry-run` passed for full-length M62 single acc+jerk pilot. Actual invocation failed **before injection**, producing only `case_0001/resolved_injection.json` and `case_0001/inject.log` (no completed injected `.fil` and no PulsarX truth archive or plot). Wrapper printed subprocess command `/usr/bin/python3 /opt/inception/injector/SCRIPT_inject_pulsars.py ...` exited 1; wrapper exit code 2.

Diagnostic from `case_0001/inject.log`: on importing `injector.setup_manager` → `pandas`, Python resolved **host user-site** `/home/rnag/.local/lib/python3.10/site-packages/pandas`. That pandas requires NumPy >=1.22.4, but interpreter sees NumPy 1.21.5. Root cause is mixed incompatible Python dependencies due to Singularity home directory mount/user-site visibility, **not** a detected incompatibility with M62 filterbank itself nor a failure of pulsar signal synthesis. No claim that image's internal pandas is valid until tested.

Immediate read-only preflight: inside pinned `$HOME/PULSEJET_validation/images/inception_lite.sif`, invoke `env PYTHONNOUSERSITE=1 python3 -c 'import sys, numpy, pandas; print(...)'`. This asks Python to ignore `~/.local` and uses container/package installation; IMPORTANT: preserve image `PYTHONPATH=/opt/inception` (confirmed in `Dockerfile.inception-lite-folding`) rather than unsetting it, or the injector modules may become unimportable. Run only after verifying imports. For the actual retry, ensure `PYTHONNOUSERSITE=1` propagates to spawned injector `/usr/bin/python3` subprocess; use a **new unique output directory**, since INCEPTION-Lite deliberately refuses to overwrite any existing `case_0001` folder from the failed attempt. Preserve failed logs/provenance; do not delete user data, inject into archive, or rebuild image prematurely.


### Full-M62 injection throughput checkpoint: ~770 s per 10 chunks/worker; redesign proposed (2026-10-23)

The `PYTHONNOUSERSITE=1` workaround successfully allowed the full 59.52-min INCEPTION injection `injections_full_m62_aj_pilot_02` to start with 8 parallel CPU workers (`multiprocessing.Pool(8)`), first generating the injection report and then running the block-wise injection. At the time the user inspected `case_0001/inject.log`, each worker reported **190 total blocks**, approximately **766–781 wall seconds per 10 blocks**, and two 10-block increments (i.e., roughly 20/190 blocks/worker, 10.5% processed). This implies **~4.0–4.2 hours** full injection at current throughput, before PulsarX folding, with wide uncertainty due to CPU contention, filesystem and per-chunk work. No completed injected filterbank, `.ar` truth fold, or valid scientific recovery yet.

User proposed **cancelling the single injection and replacing it with a multi-source injection on the observational background**, spanning a broad range of accelerations, jerks, additional DMs and injected S/N, to reduce repeat file generation. This is scientifically attractive; INCEPTION-Lite `mode='together'` already supports multiple pulsars in one output `.fil`. But original `injector/signal_injector.py` computes `pulsar_signal += model.generate_signal(...)` for EACH pulsar on each chunk, so model generation cost grows with number of pulsars even if output disk I/O is shared; all PulsarX truth folds on the full file also scale roughly per source. A naive many-source full-length run could therefore be much slower than the ~4hr single-source projection. No new source or config changes approved at this stage.

Assistant advised a single Ctrl+C in the **original node2 process terminal** to stop the in-progress single-source experiment, not in the `tail -f` terminal, and NOT to delete or treat the preallocated `.fil.part` as valid output. Next request one read-only `ps` check for orphaned worker processes and confirmation of SIGINT; only after processes terminate safely clean up partial output if user approves, then design reproducible **small (4–6) distinct-frequency** multi-source pilot, ideally an automatically extracted correctly reheadered ~15min SIGPROC subset for computational feasibility or full 59.5min if user insists, with selected PulsarX folds, proper 3-panel archive-derived diagnostic, and subsequent 15-min PULSEJET paired control/real-data injection. Need settle execution duration vs scientifically required full observation; don't quietly redefine user's choice.


### M62 four-window extraction failed because SIGPROC `nsamples` header is optional (2026-10-23)

User attempted to split original M62 `.fil` using first-version `scripts/extract_sigproc_windows.py` in INCEPTION-Lite repo (`dev/pulsejet-injections`, commit `f34ccba2d4a9d90de17787a83acc3b19ed1a8185`). It stopped with `ValueError: Required SIGPROC header fields absent` at line 66, before creating output directory or writing any new `.fil`. Cause: extractor erroneously required the optional `nsamples` SIGPROC header keyword. The actual count can be derived from `(file_size - header_offset) * 8 /(nchans * nbits * nifs)`; earlier readfile/Peasoup reported 59,285,407 samples, but this is not evidence a literal `nsamples` keyword exists in input header.

Corrected extractor [scripts/extract_sigproc_windows.py](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/scripts/extract_sigproc_windows.py) commit **`dd1dfb5182d261440684686c07b8946e849976ff`**: require tstart, tsamp, nchans, nbits but not nsamples; validate optional nsamples if present (0 or actual count), update/verify nsamples only if originally present, otherwise preserve exact field set and derive payload count. Preserve original read-only and refuse output overwrite. Added [tests/test_extract_sigproc_windows.py](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/tests/test_extract_sigproc_windows.py) at `7fbf8f9876a74d5c3fb900443271ee7cc63ba4d9` for optional `nsamples` and refusal to overwrite. Tests committed but not yet executed on actual HPC/SIGPROC; no original file mutation.

Next: user reconnects to node2 (SSH dropped), redownloads fixed splitter from **pinned** SHA, confirms output dir absent and >=35GB free, executes four-window extraction and checks results/manifest. Then stage four already committed 5-source injection configs and start unattended, monitored scheduler jobs if runtime/storage allow. Maintain user's one-step-per-turn procedure.


### M62 four-window real filterbank extraction complete (2026-10-23 ~16:03)

**Status: successfully extracted four separate 256-channel observational SIGPROC filterbanks** from original 59.52-min M62 UHF `.fil` with the corrected optional-header extraction script. User provided terminal output. Input samples `59,285,407`, sample interval `6.02352941176e-05 s`, `256 bytes/sample`. Source remains unmodified. Windows:

| Window | Samples | Duration (seconds) | Path |
|---|---:|---:|---|
| W1 | 14,821,351 | 892.768 | `$HOME/PULSEJET_validation/stage6_m62/m62_15m_windows/W1_M62_background.fil` |
| W2 | 14,821,352 | 892.768 | `$HOME/PULSEJET_validation/stage6_m62/m62_15m_windows/W2_M62_background.fil` |
| W3 | 14,821,352 | 892.768 | `$HOME/PULSEJET_validation/stage6_m62/m62_15m_windows/W3_M62_background.fil` |
| W4 | 14,821,352 | 892.768 | `$HOME/PULSEJET_validation/stage6_m62/m62_15m_windows/W4_M62_background.fil` |

Output ~3.6 G decimal each, `windows_manifest.json` generated. Sum of window sample counts matches original: **59,285,407**. Extractor verifies output size, preserves original header field set (modifies `tstart`; if present, `nsamples`), selected first/mid/last payload samples, and avoids overwrites. Shell terminal did not show any failures. Still appropriate to independently validate `readfile`/PulsarX input compatibility on a pilot; per-window PULSEJET FFT size/timing still needs matching.

Already committed four distinct five-source real-noise injection configurations to INCEPTION-Lite `dev/pulsejet-injections`: `configs/m62_weekend_20_w1.json` (`4c741be60f9221c815ef4e06633987d0ec28a0ac`), `w2` (`0314a7164897c04c8d5c1b722bc477915af7fcb3`), `w3` (`ea9e5ee348f79ea4fbed3fbe1b47a32749360b1c`), `w4` (`6bd9feab17d8eba6397438e809e79cda1eb79463`). Each config sets `ncpu=16`, `mode=together`, fold enabled with actual PulsarX, source sample source-specific injection truth; `generate_fb` absent (preserve observed noise). No weekend jobs launched yet. Need user to stage all configs on node2, check no orphaned older injector processes and available scheduler (`sbatch` vs other); only launch unattended when cluster policy and storage/quotas permit.


### Weekend M62 injection job staging: all four configs dry-run passed and Slurm detected (2026-10-23)

**All four five-source pilot JSON configurations successfully staged and dry-run on `node2`** (`PYTHONNOUSERSITE=1`, pinned SIF), confirming exactly one `case_0001` per file with five sources and intended P0/DM/A0/A1. `W1` ids I01–I05, `W2` I06–I10, `W3` I11–I15, `W4` I16–I20. No physical injections launched yet.

System confirms Slurm commands `/usr/bin/sbatch` and `/usr/bin/srun`; qsub absent. `df -h stage6_m62` showed `/home` Lustre(?) shared `/scratch1` volume size 356 TB, used 320 TB, available 37 TB, 90% filled (not proof of user quota). `quota -s` gave no output. `ps` found no outstanding original single-injection child processes. User says `node3` (second node with 64 CPUs) can also be allocated. Intended Slurm layout is jobs W1/W2 on node2 and W3/W4 on node3, 16 CPUs/job each, subject to partition and node availability. Need inspect `sinfo` before launching.

Prepared guarded Slurm job script in INCEPTION-Lite repo `dev/pulsejet-injections`: [scripts/slurm_m62_weekend_single_window.sh](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/scripts/slurm_m62_weekend_single_window.sh), commit `cff0535cabc5a3a85c5e4d4f2c68688422fc768d`. Accepts window index, prevents overwrite, matches ncpu=16 to Slurm CPUs, uses SIF `env PYTHONNOUSERSITE=1`, runs INCEPTION + real PulsarX five folds, prints Slurm job metadata, tracks total process exit code and product sizes, no deletions. User has not yet fetched script to cluster. Distinguish job scripts being committed from jobs actually submitted.


### Slurm allocation check for weekend four-window injection (2026-10-23, ~16:00 local)

User ran scheduler inspection on `frontend2`: `sinfo -N` lists `node2` as **allocated** in `all*` and `gpu`, 64 CPUs and 515733 MB RAM; `node3` **idle**, 64 CPUs, 515733 MB RAM, visible in both partitions. `sinfo -o '%P | %a | %l | %C'` lists default `all*` up/infinite (368/528/0/896 CPU alloc/idle/other/total), `gpu` up/infinite (128/256/0/384), `cpu` up/infinite (240/272/0/512). `squeue -u rnag` shows one active job **66449**, partition `gpu`, job name `alloc_manual`, running on `node2`, requesting all **64** CPUs. Do not double allocate node2 through Slurm. User can additionally use idle node3. Recommended submit four independent `--partition=all --nodelist=node3 --ntasks=1 --cpus-per-task=16 --mem=64G` jobs (total 64 CPUs, 256GB requested memory on node3), each with separate Slurm logs and non-clobbering output dir. Production of 20 real-data injections and folds remains pending submission and completion.


### User requested 120-CPU two-node M62 injection allocation (2026-10-23)

User now explicitly prefers using both 64-CPU nodes `node2` and `node3`, totaling **120 cores** (leaving 4 each) for four 5-source M62 weekend injection jobs, rather than placing all four 16-core jobs on node3. Proposed layout: W1/W2 at 30 workers each on `node2`, W3/W4 at 30 each on `node3`. This is a **target layout only; no Slurm jobs submitted and no 30-worker pilot executed yet**. Increasing `ncpu` in each 5-source JSON config from16 to30 is required to actually use requested CPUs. Scaling is not guaranteed; potential RAM/Lustre throughput contention remains.

**Key Slurm complication:** `squeue` shows user's existing `gpu` partition allocation job `66449` named `alloc_manual` already owns **all 64 CPUs of node2**. Do not submit independent `sbatch --nodelist=node2` jobs in conflict. Options: create job steps via `srun --jobid=66449 -c30 --exact` *within* existing allocation, if step/resource mode allows and ongoing use permits, keeping the allocation and Slurm launcher alive safely across weekend; OR explicitly confirm user authorizes cancellation/release of job66449 and reallocate through separate batch jobs on two nodes. Must inspect active job steps/CPU usage first, do not cancel proactively. `node3` is idle and can be used with two Slurm batch jobs.

Next read-only check on frontend2: `scontrol show job 66449 | grep -E 'JobId=|JobState=|NumCPUs=|NodeList=|Command=|WorkDir='; squeue --steps -j 66449 -o '%i | %j | %T | %R | %C'`. Then proceed with correct resource-safe submission. Remember `PYTHONNOUSERSITE=1` in subprocess, don't overwrite `m62_15m_injections/W1`... folders; preserve original .fil; keep independent logs, PulsarX folds, manifest.


### Dual-node 120-worker Slurm launch enabled after canceling old node2 allocation (2026-10-23)

User stated they **cancelled** prior node2 Slurm allocation job 66449 (`alloc_manual`, 64 CPUs) to allow independently scheduled 5-source weekend injection jobs. Cancellation stated by user; pending independent `squeue` verification. Intended Slurm allocation: W1 and W2 each `--nodelist=node2 --cpus-per-task=30 --mem=64G`; W3 and W4 similarly on node3. Total **120 reserved CPUs**, leaving four unreserved CPUs per 64-core node (provided cluster does not impose whole-node exclusivity). Four Slurm jobs each with their own logs and outputs; not yet submitted as of this note.

Updated guarded launcher [scripts/slurm_m62_weekend_single_window.sh](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/scripts/slurm_m62_weekend_single_window.sh) to read `SLURM_CPUS_PER_TASK` and write a reproducible per-job resolved JSON config with `ncpu=30`, preserving all original five-source parameters and original source JSON without modifications. Final pinned source commit `99d6318eab9960400fce3400734c064f19cbf29b`, after correcting generated JSON terminal newline representation. Launcher checks input SIF/config/file, fails if output exists, logs worker count, runs `singularity exec ... env PYTHONNOUSERSITE=1 python3 -m inception_lite --perform-folds yes`, prints product manifest/exit status and elapsed time. No scientific source code changed; no new jobs yet launched. Submission should prevent duplicate job names and ensure previous allocation exited before scheduling.

### Weekend M62 20-source injection jobs submitted and RUNNING on two Slurm nodes (2026-10-23)

User executed the pinned INCEPTION-Lite Slurm launcher from `node2` with `--partition=all --nodelist=node{2,3} --cpus-per-task=30 --mem=64G --ntasks=1` for each of four real-data 14.88-minute five-source injection experiments. **All four sbatch submissions succeeded and returned RUNNING states**, as copied from user's `squeue` output:

| Job | Slurm ID | Node | Allocated CPUs | Status at submission |
|---|---:|---|---:|---|
| m62inj_W1 | 66450 | node2 | 30 | RUNNING |
| m62inj_W2 | 66451 | node2 | 30 | RUNNING |
| m62inj_W3 | 66452 | node3 | 30 | RUNNING |
| m62inj_W4 | 66453 | node3 | 30 | RUNNING |

Allocation totals **120 CPUs over two 64-CPU nodes**, with four CPUs not reserved by these jobs on each. Each window contains 5 known injected pulsars with distinct f, residual DM, a/j and nominal S/N (10–100); four independent real-background files already prepared and checked. `mode=together` with five injections per new `.fil`; Slurm wrapper writes unique per-job JSON with `ncpu=SLURM_CPUS_PER_TASK`, uses `PYTHONNOUSERSITE=1` to avoid pandas/NumPy user-site conflict, and invokes real `psrfold_fil` for five truth folds after injection. Output directories under `$HOME/PULSEJET_validation/stage6_m62/m62_15m_injections/W{1..4}` and separate scheduler logs under `$HOME/PULSEJET_validation/stage6_m62/weekend_slurm_logs/W{1..4}_JOBID.{out,err}`.

**Important qualification:** RUNNING is scheduler state only. As of this checkpoint no completed `.fil`, validated PulsarX `.ar`, PNG profile, or measured search recovery has been verified. Next inexpensive check: inspect tail of all four Slurm stdout/stderr logs to confirm worker launch and absence of early errors; later verify via `sacct -j 66450,66451,66452,66453 --format=JobID,JobName,State,ExitCode,Elapsed,NodeList` and manifests/folds. Avoid reporting weekend completion before inspecting actual products. Original M62 file remains read-only and intact. Keep failed original single-injection attempt logs as provenance.


### Four M62 weekend Slurm job startup logs confirmed (2026-10-23, 16:21 Europe/Rome)

User read `weekend_slurm_logs/W{1..4}_<jobid>.out` on `frontend2`. **All four jobs entered INCEPTION-Lite**, printed resolved per-job 30-worker JSON paths, correctly parsed five intended pulsars each and showed no stderr in the inspected logs:

| Window | Slurm job | Node | Controller startup |
|---|---:|---|---|
| W1 | 66450 | node2.cluster | 2026-10-23T16:21:36+0200; `m62_w1_job66450_30cpu.json`; I01–I05 |
| W2 | 66451 | node2.cluster | 2026-10-23T16:21:36+0200; `m62_w2_job66451_30cpu.json`; I06–I10 |
| W3 | 66452 | node3.cluster | 2026-10-23T16:21:36+0200; `m62_w3_job66452_30cpu.json`; I11–I15 |
| W4 | 66453 | node3.cluster | 2026-10-23T16:21:37+0200; `m62_w4_job66453_30cpu.json`; I16–I20 |

The logs confirm controller entry and correct Slurm CPU parameter propagation. **They do NOT yet demonstrate spawned worker progress or successful physical injection**, because INCEPTION-Lite redirects injector subprocess stdout and errors to `m62_15m_injections/W?/case_0001/inject.log`. Further investigate those 4 internal injector logs before asserting that workers are processing. No complete `.fil`, PulsarX `.ar`, or diagnostic figure verified. Slurm jobs survive SSH disconnect; later inspect both `sacct` final state and products.


### Final Friday evening injector startup check: 4 x 30 workers operational (2026-10-23, ~16:42 Europe/Rome)

On `frontend2`, user checked the actual per-case INCEPTION-Lite logs for all four Slurm jobs (`66450`–`66453`) and confirmed each reported `building 5 pulsar models...`, `writing fold files...`, `injection report written.`, `starting 30 workers, each builds its own models...`, `Models constructed, starting injection...`. Background sample mean/std from the log:

| Window | Mean | Stddev | CPU workers | Slurm node/state |
|---|---:|---:|---:|---|
| W1 | 128.0184975 | 1.8169686234421105 | 30 | node2 RUNNING (66450) |
| W2 | 128.0488675 | 1.8177889060698984 | 30 | node2 RUNNING (66451) |
| W3 | 128.0219100 | 1.8162967423932015 | 30 | node3 RUNNING (66452) |
| W4 | 128.0676625 | 1.8196374347275746 | 30 | node3 RUNNING (66453) |

No Python traceback in the user-shared tails; logs show the injector's worker pool is initialized. **No chunk-progress messages were present yet**, and success must not be inferred. User may safely disconnect, since Slurm batch jobs are independent of their interactive login session. On return (Monday), query `sacct -j 66450,66451,66452,66453 --format=JobID,JobName,State,ExitCode,Elapsed,NodeList`, inspect latest Slurm logs + per-case `inject.log`, verify exactly four final `.fil` outputs and up to twenty `.ar` PulsarX truth archives before plotting or attempting search. In particular the source has only a 1D pulse-profile fallback; user requested full authentic PulsarX folded pulse/time/frequency diagnostic, so create one from actual .ar archive as a separate validation step. Don't claim a 20/20 fold success without product checks.


### M62 20-source weekend campaign successfully completed (results checked 2026-10-26)

**Confirmed actual execution results (user `sacct -X` and file/log verification on frontend1).** Four jobs submitted 2026-10-23; finished Slurm state **COMPLETED, ExitCode `0:0`** on node2/node3:

| Window | Slurm ID | Node | Slurm elapsed | Launcher elapsed | Injected filterbank | PulsarX `.ar` | PNG | Manifest |
|---|---:|---|---|---:|---|---:|---:|---|
| W1 | 66450 | node2 | 01:36:44 | 5803 s | 3,794,266,147 bytes | 5 | 5 | present |
| W2 | 66451 | node2 | 01:35:23 | 5721 s | ~3.6 GB | 5 | 5 | present |
| W3 | 66452 | node3 | 01:45:36 | 6334 s | ~3.6 GB | 5 | 5 | present |
| W4 | 66453 | node3 | 01:42:54 | 6171 s | ~3.6 GB | 5 | 5 | present |

Four runs overlapped; makespan roughly 1h45m36s (6336s) measured as slowest Slurm elapsed, not sum of job times. Total verified output 4 injected ~3.6G .fil, 20 PulsarX `.ar`, 20 PNG, 4 `run_manifest.json`; full signed manifests and fold logs remain for detailed inspection. Filename convention `m62_15m_injections/W#/case_0001/W#_M62_background_m62_w#_five_injections_20261023_case_0001.fil`. The `.fil` output is separate from background and archive read-only input.

At completion `inject.log` prints `bits flipped: <count>/<total> (<fraction>)` per window, reflecting numeric values altered by injection in upstream code (despite wording 'bits'): W1 **8,506,432/3,794,265,856 = 0.224%**; W2 **7,775,472/3,794,266,112 = 0.205%**; W3 **7,395,029/3,794,266,112 = 0.195%**; W4 **4,733,987/3,794,266,112 = 0.125%**. These aren't a recovery metric. W1 displayed output file size 3,794,266,147 bytes = 291-byte SIGPROC header plus 3,794,265,856 data bytes.

**Scientific status:** all four jobs ended zero and outputs exist, meaning INCEPTION and PulsarX orchestrated successfully; the archives' correctness, pulse coherence, S/N, dispersion correction, profile diagnostics, phase/time/frequency behavior remain to be validated. There is still the known PULSEJET PeakFinder lower frequency-bound bug, and **no recovery searches of these injected filterbanks have occurred yet**. Existing fallback PNG from `inception_lite/fold_plots.py` is phase-profile-only, not full 3-panel pulsar plot; user wants authentic time-phase and frequency-phase plots from PulsarX `.ar` archives.

**Immediate next step:** inspect W1/I01 (stationary, high S/N control) `.ar` FITS SUBINT dimensions, data shape, and `fold.log`, without modifying; then construct honest full multi-panel diagnostic from PulsarX archive including polarization/scaling/weights as necessary. If this verifies, inspect lower-S/N and nonzero-jerk truth folds across windows and adjust scientific validation plan before editing search code.


### First PulsarX truth archive inspected: W1/I01 has full phase-time-frequency data (2026-10-26)

User inspected W1 stationary high-S/N pilot `M62_W1_I01` truth fold archive on `frontend1`: `/home/rnag/PULSEJET_validation/stage6_m62/m62_15m_injections/W1/case_0001/folds/M62_W1_I01/M62_W1_I01_59689.9678870941_cfbf00000_00001.ar`. Astropy FITS shows `SUBINT` extension `89R x 21C`, **NAXIS2=89, NPOL=1, NCHAN=32, NBIN=128, POL_TYPE='AA+BB', TBIN=0.0**. Columns include `TSUBINT`, `OFFS_SUB`, `PERIOD`, `DAT_FREQ`, `DAT_WTS`, `DAT_OFFS`, `DAT_SCL`, `DATA`, and `DATA` shape `(89,1,32,128)`. The PSRPARAM/T2PREDICT extensions exist but have 0 rows. **This is enough to make an actual three-panel pulsar truth diagnostic:** integrated phase profile, time-versus-phase and frequency-versus-phase, NOT yet proof of successful PULSEJET search recovery.

Added research-only plotting utility [scripts/plot_pulsarx_diagnostic.py](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/scripts/plot_pulsarx_diagnostic.py), pinned commit `19b399c8cd84ef9966668600969375781dce9d83`. Uses actual PulsarX `.ar` 4D SUBINT intensities, applies per-pol/channel `DAT_SCL` and `DAT_OFFS`, masks and weights using `DAT_WTS`, uses median-baseline and robust phase-noise normalization for visualization; plots 2 pulse cycles for integrated profile, time waterfall and frequency waterfall, using real `OFFS_SUB`,`TSUBINT`,`DAT_FREQ` axes. It explicitly labels relative intensity (not calibrated S/N or flux). No scientific code changed. **Not yet executed/visually QA'd on the actual archive**; next run this one case on the cluster with pinned script from GitHub and upload/view the resulting PNG, then refine plotting based on evidence before batch plotting 20 sources.


### Lightweight PulsarX truth-fold metadata panel added to diagnostic plotting utility (2026-10-26)

User reviewed uploaded W1/I01 PulsarX actual three-panel truth fold: sharply peaked at phase~0.5, aligned vertically in both time and frequency across approximately 14.834 minutes/544–1088 MHz. User prefers **simple three-panel plots for injection truth checks**, reserving full pulsar candidate diagnostics with genuine DM/period/frequency-derivative optimization and search-recovered S/N for PULSEJET search-validation later. Original truth-fold plotting PNG lacked any information about injected period, DM, acceleration, jerk or S/N.

Updated [scripts/plot_pulsarx_diagnostic.py](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/scripts/plot_pulsarx_diagnostic.py), pinned commit `b971f6c70d91c64f317a7cca68f3f6ffbd2165d6`, adding a separate compact metadata banner **'INJECTION TRUTH · Not search-recovered measurements'**, loaded from `case_0001/run_manifest.json` matched to the source ID from the archive parent folder. Displays true `P0` (ms), `f0` (Hz), **additional** injected DM (pc cm-3), acceleration (`A0`, m s-2), jerk (`A1`, m s-3), nominal injection S/N **target** (not measured), duty cycle, and `frame/ACCEPOCH` from `resolved_injection.json`. Source ID must match exactly; otherwise raise, never silently adopt another source's truth. Optional `--manifest` explicit path; if missing, plot explicitly says truth unavailable instead of fabricating data. Three archive-derived panels and intensity calibration/masking unchanged. Added [tests/test_plot_pulsarx_diagnostic.py](https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/tests/test_plot_pulsarx_diagnostic.py), commit `c12fc93428ba59e82d433952f73cfcb8d01fcfd7`, for manifest extraction, source mismatch guard, missing metadata; tests committed, not executed on cluster yet.

No need to reinject or refold; simply rerun updated plotting script on the existing `.ar` with `--manifest` pointed to W1 `case_0001/run_manifest.json`, write a **new** `_truth_annotated.png` to preserve original figure. User on Windows laptop transfers via SCP jump host `rouhin@fortalesa.oa-cagliari.inaf.it` to `rnag@clust-02.oa-cagliari.inaf.it`. Confirm layout using user-uploaded new image before batch plotting all 20.


### First 20-fold contact sheet visual QC: only W1/I01 unequivocal, investigate folding/DM (2026-10-26)

User supplied actual `all_20_truth_folds_montage.png` containing 20 manifest-annotated PulsarX known-parameter truth-fold panels, 5 rows x 4 columns. This is visual QA using real `.ar`-derived data, not synthetic pictures. **Important finding: W1/I01 stationary, injected DM_add=0, f=247Hz, SNR nominal100** displays a clear sharp profile repeated at phases 0.5 and 1.5 plus narrow, vertically phase-aligned continuous time and frequency tracks. **The other nineteen truth folds do NOT show comparably convincing coherent vertical tracks or clear narrow peaks** at the available montage scale. In particular **W3/I11** is stationary (`A0=0,A1=0`) and nominal SNR70 with `DM_add=4`, yet its fold resembles noisy undulations, without an obvious broadband coherent track. W1/I02 (`a40,j0,DM_add4,SNR60`) has structured ripple but no definite narrow coherent peak. Low-S/N cases may be invisibly weak and montage thumbnails too small for definitive exclusion. Successful process status and archive existence ≠ validated signal recovery or physically correct injection model. Do NOT label all 20 as scientifically confirmed, nor start broad sensitivity/PRESTO comparison or the previous suggested blind pipeline search. Keep original outputs unchanged.

Possible explanations require **tests rather than assumptions**: wrong DM sign/unit/reference-frame handling between upstream INCEPTION injection (`get_DM_delays` subtracts `DM*K/nu^2` from phase argument) and PulsarX `psrfold_fil` folding; phase/ref-epoch mismatch for accelerated/jerked cases; quantization and lower-than-expected nominal S/N in real 8-bit noise; plotting baseline/normalization or stronger RFI. Presence of apparently missing **stationary, nonzero-DM** source makes the DM/fold convention an early diagnostic priority. Publication-grade validation requires measuring coherent folded S/N with independent method/DM sweep; do not infer from scaled plotting 'peak relative folded intensity'.

Next ONE read-only HPC command: inspect `W3/case_0001/folds/M62_W3_I11/M62_W3_I11_phase_truth.cands`, its `fold.log`, and case-level `M62_W3_I11.candfile`, compare stationary injected truth. Then carry out an explicit refold varying trial DM using actual injected `.fil` with exactly identical period+epoch and no a/j, to discriminate DM correction mismatch, before more processing. Regenerated .ar archives must be in new diagnostic output dir, not overwrite the truth folds. Need also correct already-known PULSEJET PeakFinder `start_idx` bounds bug and verify realistic 15min FFT/template epochs before PULSEJET recovery tests.


### Epoch-convention investigation: PRESTO start vs PulsarX midpoint is not the observed failure (2026-10-26)

User challenged the visual QC interpretation and proposed the known convention difference: PRESTO `prepfold` tends to use observation-start period/period derivative, while PulsarX `psrfold_fil` defaults to observation midpoint. **Verified directly against injection image's pinned INCEPTION-Lite source commit `5a9cd1c9b252ffd1797575267c4528fa5b8e81c5`, and PulsarX upstream implementation.**

- INCEPTION `injector/observation.py:set_epochs` defaults `PEPOCH` to observation start for `frame='topo'`, sets `spin_ref=0`, and `accepoche = ACCEPOCH*obs_len`. For these injections `ACCEPOCH=0.5`; source `injector/pulsar_model.py:get_spin_functions` explicitly uses `phase_func_abs(t-self.accepoch,c)`: acceleration/jerk expansion is **centered on the observation midpoint**, with local `f0` being its spin frequency there.
- INCEPTION-Lite `inception_lite/runner.py:fold_truth` uses `mid_epoch=header.tstart+header.actual_nsamples*header.tsamp/(2*86400)`, constructs `f0=1/P0`, `f1=-f0*a/c`, `f2=-f0*j/c`, then passes `psrfold_fil --pepoch <mid_epoch> --nosearch` plus `#id DM acc F0 F1 F2 S/N` candidate file.
- PulsarX public `src/pulsar/psrfold_fil.cpp`: option `--pepoch` defines `F0/F1/F2/acc epoch (MJD)`; `folder.ref_epoch` set to provided epoch or to observation midpoint by default (line ~467–473). `src/pulsar/archivelite.cpp:prepare` computes `f1=-acc/CONST_C*f0` **only when passed `f1==0`**, so providing both a and corresponding nonzero f1 does NOT double-apply acceleration. Actual phase function in `include/archivelite.h` is `phi=f0*t+0.5*f1*t²+f2*t³/6` with `t=obs_time-ref_epoch`. PulsarX C++ source version deployed in pinned Docker base was not independently fingerprinted; inspect compiled SIF if a remaining issue contradicts this code.
- Peasoup README documents midpoint-to-start period correction specifically for PRESTO `prepfold`, corroborating the convention contrast: https://github.com/ewanbarr/peasoup .

**Conclusion:** The apparent start-vs-midpoint difference is **not presently supported as root cause** for weak 19/20 truth folds. Critical control W3/I11 (A0=A1=0, DM_add=4, nominal S/N70) has constant f regardless of epoch and changing epoch cannot smear it, only shift pulse phase. Our W1/I01 DM0 stationary shows strong fold, while I11 and most others weak. Therefore next diagnostic should focus on DM correction and possible power/normalization and folded archive plotting, without changing original INCEPTION engine or refolding all 20 blindly. Existing `--nosearch` disables correction optimization that previous PRESTO `prepfold` could have performed.

**Potential future precision issue:** PulsarX upstream `get_ffold` in `include/archivelite.h` displays `f0+f1*t+0.5*f2*t` (linear in t for f2) whereas expected frequency is `f0+f1*t+0.5*f2*t²`. Its **phase calculation** is correct cubic. If jerk-specific folds remain weak after DM controls, independently verify running PulsarX version and relevance before making claims. This has no direct effect on stationary I11, and no modifications were made.


### Stage 6 M62: all 20 INCEPTION truth folds visually validated after correcting PulsarX archive channel alignment (2026-10-27)

**Status: truth-fold/plotting gate passed; PULSEJET blind search on these 20 injected observational filterbanks has not begun.** Existing `inception_lite.sif` and `pulsejet_dev.sif` remain immutable. The new Python plotting code is committed exclusively to `inception_injection_test_tool:dev/pulsejet-injections` (not yet rebuilt into the old SIF). Original M62 observational background and injected `.fil` files were not changed during this diagnostic.

Root cause of initially weak/smeared PulsarX quicklook plots: upstream PulsarX's `ArchiveWriter::get_dedispersion` reintroduces a DM-dependent channel phase offset when writing `.ar`; our custom quicklook/three-panel functions were summing the resulting frequency-channel profiles directly. New shared `inception_lite.fold_plots.read_dedispersed_pulsarx_archive` interprets PSRFITS `DAT_SCL`, `DAT_OFFS`, `DAT_WTS`, `DAT_FREQ`, archive `SUBINT.DM` and each subintegration's `PERIOD` to reverse channel shifts before summing. The PulsarX folding engine and injection physics remain unchanged; PRESTO `.pfd` has a separate native format and is not passed through this reader.

For W3/I11 stationary, independent PRESTO fixed-parameter prepfold of the same injected `.fil` had reduced chi²=33.647 and `~60.8 sigma` according to its `.bestprof`. The PulsarX quicklook profile increased peak/MAD from 2.582 to 31.404 when archive channels were aligned; the two reported significance measures are **not interchangeable**.

The user executed `scripts/batch_m62_pulsarx_diagnostics.py` from updated INCEPTION development source on cluster and provided the resulting `m62_20_truth_fold_qc.csv` and **all twenty** three-panel PNGs for visual review. Reported measurements:

- 20/20 existing real-data M62 injected-source PulsarX `.ar` archives processed; five per W1/W2/W3/W4; no batch errors. All 20 archive DMs match injected DM.
- Each archive contains 89 subintegrations × 32 channels × 128 phase bins; weighted usable-cell fraction 1.0.
- For the 19 sources with positive additional DM, corrected profile peak/MAD strictly increases. For W1/I01 with DM=0, it remains **52.484 -> 52.484**, as expected.
- Median corrected peak/MAD = **25.128**; range **7.103–58.391**. These are descriptive profile contrast, **not calibrated detection S/N**. Lowest cases: W2/I10 (target S/N 10, peak/MAD 7.103), W4/I18 (target 12, 7.276), W4/I20 (target 15, 7.638).
- All 20 supplied PNGs show visible integrated-profile peaks near one narrow phase; strong cases show nearly vertical pulse tracks versus time and frequency after alignment. Weak injections remain noisy in waterfall displays, as expected. No obvious large systematic phase drift in these plots, but this is visual QC, not precise timing residuals or blind frequency/DM/a/j recovery.
- Data: `/home/rnag/PULSEJET_validation/stage6_m62/m62_15m_injections/W{1..4}/case_0001`. Outputs: `.../m62_15m_injections/pulsarx_diagnostics_corrected/` containing 20 PNGs and `m62_20_truth_fold_qc.csv`. Source plotting helper `https://github.com/Rouhin1997/inception_injection_test_tool/blob/dev/pulsejet-injections/scripts/plot_pulsarx_diagnostic.py`.

**Next stage (not yet executed): actual GPU candidate recovery from injected observational `.fil`.** Distinguish a controlled fixed-DM/fixed-template frequency recovery from an independently blind search in DM, acceleration and jerk. Current pinned PULSEJET SIF still has documented `PeakFinder` lower-band indexing error; reported `--min_freq` effectively behaves approximately as `2 × min_freq`, and an invalid internal range can crash CUDA/Thrust. A **provisional pilot** can use `--min_freq 110 --max_freq 260` to cover W1/I01's expected 247 Hz with effective ~220–260 Hz and stationary DM0 polynomial template, at 2^22 samples (252.65 s, `--nsamples == --fft_size`). PULSEJET source fix/regression/new pinned SIF still required before claiming complete frequency coverage or survey sensitivity.

For longer tests, full 14,821,351/352-sample windows (892.768 s) need `--fft_size 16777216` with explicit `--nsamples`, care with padding vs physical midpoint, and bank mismatch design. The acceleration/jerk truth parameters are defined at the *full window midpoint*, so shorter or off-center segments require transforming reference acceleration and frequency (`a(t)=a_0+j_0\,\Delta t`) before comparing search peaks. Do not assume the stationary 4m pilot verifies jerk recovery. All `.fil` inputs remain read-only; search outputs and logs must use new unique directories. Existing observational M62 background may contain natural pulsars/RFI, so candidate IDs must be cross-matched with injected frequency and DM and checked against uninjected controls. Do not change existing third-party polynomial Doppler distiller without a specific discussion.


**Stage 7 W1/I01 pilot launcher staged (not executed on HPC):**
`scripts/run_m62_w1_stationary_recovery_pilot.sh`, commit
`036fcc402f07c541012aa18bf285b66916cc09dd`. This guarded script
requires an allocated GPU with visible A40, reads existing
`W1/case_0001/*.fil`, writes a fresh
`$HOME/PULSEJET_validation/stage7_m62_recovery/w1_i01_dm0_a0j0_4m_v1/`
search plus separate terminal log and provenance, and refuses output overwrite.
It runs one DM=0, one (a,j)=(0,0) template, `--start_sample 0
--nsamples 4194304 --fft_size 4194304 -t 1 -n 4 -m 7
--min_freq 110 --max_freq 260 --candidate_diagnostics -v`.
The known old PeakFinder bug makes the effective search band approximately
220–260 Hz, encompassing 247 Hz I01 but not the M62 natural ~278 Hz pulsar.
This is a **restricted-band frequency discovery at fixed known DM and motion**,
and is not a full-parameter blind recovery. Check `overview.xml` and candidate
frequency/S/N before declaring success; user must explicitly run it on cluster.


### Stage 7 W1/I01 controlled GPU pilot executed on node3 (2026-10-27 11:05 cluster local)

User ran `scripts/run_m62_w1_stationary_recovery_pilot.sh` on the existing injected M62 W1 real-data filterbank. The pinned pre-fix PULSEJET SIF completed with **exit 0** and `all done` in **14 s external wall clock**. Input `W1/case_0001/W1_M62_background_m62_w1_five_injections_20261023_case_0001.fil`; `--start_sample 0 --nsamples 4194304 --fft_size 4194304`, MJD start `59689.9678870941`, computed/recorded search segment midpoint `59689.9693491609`. Requested frequency range `110–260 Hz`; existing PeakFinder bug means effective lower limit approximately `220 Hz`. One DM=0 trial and one a=j=0 stationary polynomial template; candidate S/N threshold in XML `7`. Search log:
`/home/rnag/PULSEJET_validation/stage7_m62_recovery/w1_i01_dm0_a0j0_4m_v1.log`.
Output XML:
`/home/rnag/PULSEJET_validation/stage7_m62_recovery/w1_i01_dm0_a0j0_4m_v1/overview.xml`.
Provenance:
`/home/rnag/PULSEJET_validation/stage7_m62_recovery/w1_i01_dm0_a0j0_4m_v1_provenance.txt`.

Candidate diagnostics: **12 raw spectral detections**, 5 after per-template harmonic distillation, 5 after per-DM polynomial, 5 after cross-DM and final harmonics, 5 final, 0 nested associated nodes. Search's `overview.xml` is 6.1 KB, but the user has only supplied its first 80 configuration lines; **no candidate frequencies or S/N have yet been read**, so **do not yet claim recovery of I01 at injected 247 Hz**. Next read-only check: inspect XML candidate records and identify any near 247 Hz, including possible harmonic relationships. No additional expensive GPU runs before evaluating first candidate list.


**Candidate-list continuation provided (2026-10-27):** W1/I01 4-minute pilot `overview.xml` yielded candidate 0 search S/N `52.2926330566406`, DM=0, a=j=0, nh=3, `folded_snr=0` because no independent fold was run in this search step. Its period was **not included** in the user's `tail -n 110` excerpt; therefore do **not** yet claim 247-Hz frequency agreement. Other survivors (computed as reciprocal of XML period) are approximately 222.1535034 Hz (S/N 10.48), 256.1626587 Hz (10.10), 254.7298279 Hz (9.60), 228.1084900 Hz (8.73). GPU-reported times: dedispersion 3.9924s, reading 0.1013s, searching 0.1457s, total internal 8.2136s, compared with outer measured wall time 14s. Injected I01 target S/N 100 on the full 892.768-s file; a naive square-root time adjustment for 252.645s gives ~53.2, close to candidate 0 S/N 52.29, **but injection target and FFT search S/N are different definitions, so this is contextual rather than calibrated confirmation**. Next query: show XML period and DM for candidate id=0, verify 1/period near 247 Hz and offset in Fourier bins (1/252.645 Hz); only then mark the first frequency recovery.


### Stage 7 W1/I01 first independent stationary frequency recovery PASSED (2026-10-27)

The previously missing candidate-0 XML fields have now been supplied by the user:
`<period>0.0040485812452019</period>`, `<dm>0</dm>`, `<acc>0</acc>`,
`<jerk>0</jerk>`, `<nh>3</nh>`, search `<snr>52.2926330566406</snr>`.
This corresponds to **247.00010681152344 Hz** versus injection truth
**247.00000000000000 Hz**, frequency error **+0.00010681152344 Hz**,
period error **−1.75075 ns**, approximately **0.02699 Fourier frequency bins**
for the 4,194,304-sample, 252.645135-s segment. Candidate 0 is the
strongest of five final candidates; other survivor S/N values
10.48, 10.10, 9.60 and 8.73. Successful executed pipeline with
outer wall time **14 s** and reported internal total **8.214 s**.

**Interpretation:** controlled *independent search-frequency* recovery of
the real-background W1/I01 injection at the correct spin frequency, with
DM=0 and polynomial template (a,j)=(0,0) supplied as trial inputs. This
does NOT establish blind DM/a/j estimation, full-window completeness,
calibrated detection sensitivity, or correctness of the known unpatched
PeakFinder lower-frequency bound. The 247-Hz signal is in the provisional
effective 220–260-Hz search band; old source remains unmodified.
No independent recovered-candidate PulsarX fold has yet been completed
for this Stage 7 search. Next validation is a controlled centered
multi-template acceleration search for W1/I02 (263 Hz, DM=4, a=+40 m/s²,
j=0), including neighboring templates, followed by jerk-bearing cases.
Avoid comparing segment-midpoint parameters against full-window midpoint
without time propagation.


**Next Stage 7 controlled acceleration pilot (staged, not run):**
`scripts/run_m62_w1_i02_acceleration_pilot.sh` (commit
`36557aaf2778373f6524c608e297829096d69b96`). It reuses the
already-injected W1 observation and pinned immutable image, reads a
centered 4,194,304-sample (252.645-s) segment from start sample
**5,313,523**, fixing the segment reference epoch to essentially the
full-window injection midpoint. I02 truth: **f=263 Hz, DM=4, a=+40 m/s²,
j=0**, target injection S/N 60 over the full window. One DM=4 trial,
five polynomial templates `(a,j)=(0,0),(20,0),(40,0),(60,0),(80,0)`,
and the old PeakFinder bug workaround requesting band `128–270 Hz`
(effective approximately 256–270 Hz). This is **frequency discovery
and discrete acceleration-template selection** with DM and jerk fixed,
and known truth included in the grid; not a blind search over all
four dimensions. Guarded launcher records log/provenance and refuses
overwrite; user must execute on allocated GPU node. Inspect candidates
near 263 Hz, their a/j and S/N; compare competing templates and
optional stationary-only control before interpreting motion recovery.


### Stage 7 centered W1/I02 acceleration-bank GPU execution: operationally passed; candidate parameters pending (2026-10-27)

User executed `bash scripts/run_m62_w1_i02_acceleration_pilot.sh` on `node3` after clean fast-forward pull to `d3e0ceb`. Pinned pre-fix PULSEJET A40 SIF enumerated two A40 GPUs and completed **exit status 0, outer wall time 14 s**. Read existing injected M62 W1 `.fil`; centered segment `--start_sample 5313523 --nsamples 4194304 --fft_size 4194304` (actual dedispersed samples transferred: `4193609`), near full-window injection midpoint. One DM=4 trial; a/j bank = `(0,0),(20,0),(40,0),(60,0),(80,0)`; requested `--min_freq 128 --max_freq 270` (unpatched PeakFinder effective start ~256 Hz) contains injected I02 f=263 Hz. All five polynomial resampling/FFT/harmonic stages ran and finished. Candidate diagnostics: 29 raw spectral detections, 8 after per-template harmonic grouping, 8 before and **3 after polynomial Doppler distillation**, 3 final candidates, **5 nested associations**, 1 DM and 5 template trials, reported internal per-DM processing 0.072171s (not outer wall time). Log `$HOME/PULSEJET_validation/stage7_m62_recovery/w1_i02_dm4_acc_bank_center4m_v1.log`; XML `.../w1_i02_dm4_acc_bank_center4m_v1/overview.xml`.

**Not yet demonstrated:** candidate frequency near 263 Hz and candidate acceleration +40 m/s²; no candidate `<period>`, `<acc>`, or `<snr>` records were pasted yet. The presence of 5 nested nodes does not identify which templates generated them because `overview.xml` only stores association counts. Next action is a read-only parse of all 3 XML candidate records, listing id, frequency=1/period, acceleration, jerk, harmonic number, S/N and number of associations. Do not claim acceleration recovery until those fields are checked.


### Stage 7 W1/I02 accelerated injection successfully recovered (2026-10-27)

User parsed the three output candidates from the completed centered `2^22`-sample W1/I02 real-background GPU acceleration-bank search:

| ID | Frequency (Hz) | DM (pc/cc) | Acc (m/s²) | Jerk (m/s³) | Search S/N | Harmonic level `nh` | Associations |
|---|---:|---:|---:|---:|---:|---:|---:|
| **0** | **263.000305** | **4** | **+40** | **0** | **29.89** | 3 | 4 |
| 1 | 261.626343 | 4 | 0 | 0 | 8.61 | 3 | 1 |
| 2 | 264.936340 | 4 | +40 | 0 | 8.08 | 4 | 0 |

Injection truth `M62_W1_I02`: **f=263.000000 Hz**, DM=4, a=+40 m/s², j=0, full-window target S/N=60. Leading candidate frequency error **+0.000305 Hz** = approximately **0.077 Fourier bins** at the 252.645-s controlled center segment. Correct acceleration template +40 m/s² was selected from bank `0,20,40,60,80` at fixed DM=4 and j=0; best candidate search S/N **29.89**, four nested associations. These do not expose per-template S/N records, so we cannot yet tell whether neighboring acceleration templates were almost as strong without individual-template control searches. The full-window injected S/N target versus segment search S/N is not a directly calibrated comparison.

**Conclusion:** Stage 7 W1/I02 controlled frequency discovery and discrete acceleration-template selection **PASSED**, alongside Stage 7 stationary W1/I01. Not yet unconstrained acceleration estimation, blind DM/jerk recovery, full-window completeness or search false-alarm calibration. Original polynomial resampler, PeakFinder (including known bug), and distillers unchanged.

### Stage 7 W3/I13 jerk-template selection pilot staged, not run (2026-10-27)

New guarded launcher:
`scripts/run_m62_w3_i13_jerk_pilot.sh`, commit
`711990715c33e1fc1e5a3bd6cb72e97135f34a47`.
Target W3/I13 truth `f=317 Hz, DM=20 pc/cc, a=0 m/s²,
j=+0.18 m/s³`, target injected S/N=50. A 4-minute segment is too
short to separate this jerk strongly from zero because the phase
perturbation at the segment edge is `f*j*T^3/(48*c)`, roughly
0.064 cycles for T=253 s. Instead read an exactly **centered
8,388,608 (2^23)-sample**, roughly **505.19-second** segment from
`W3/case_0001/*.fil`, start sample **3,216,372** (full W3 samples
14,821,352), with `--nsamples == --fft_size == 8388608`.
This makes the polynomial kernel midpoint and reported epoch coincide
with the INCEPTION injection's full-window midpoint, without an
extra 2^24 FFT padding shift. Edge jerk phase is then ~0.51 cycles.
Dedispersion itself can still trim/pad some samples; do not call this
a perfect 100%-filled FFT.

One fixed DM=20 trial, 15 two-dimensional (a,j) templates:
a={-20,0,+20} m/s² × j={-0.18,0,+0.09,+0.18,+0.27} m/s³.
Truth included; neighboring/wrong-sign/stationary controls included.
Requested frequency limits `154–325 Hz`, corresponding to effective
roughly `308–325 Hz` in the old unpatched PeakFinder SIF, enclosing
317 Hz. Uses `-t 1 -n 4 -m 7 --candidate_diagnostics -v`. 
Unique output/log/provenance under
`$HOME/PULSEJET_validation/stage7_m62_recovery/w3_i13_dm20_aj_bank_center8m_v1`;
refuses overwrite. No GPU run performed yet. After output, inspect
candidate f, DM, acceleration, jerk, S/N, harmonic number, associations;
follow with matched single-template j=0 versus j=+0.18 controls to
demonstrate a real jerk sensitivity gain, rather than relying solely
on the distiller's bank winner.


### Stage 7 W3/I13 first 2-D acceleration–jerk GPU search completed; recovered candidate parameters pending (2026-10-27)

The user ran `bash scripts/run_m62_w3_i13_jerk_pilot.sh` on `node3` after a clean fast-forward of development branch to `4755a31`. Pinned pre-fix PULSEJET Singularity image enumerated two NVIDIA A40 GPUs and successfully completed **exit 0** / `all done`; **outer wall time 17 s**. Existing injected observational input:
`stage6_m62/m62_15m_injections/W3/case_0001/W3_M62_background_m62_w3_five_injections_20261023_case_0001.fil`.
Centered 8,388,608-sample (roughly 505.19-s) segment **start=3,216,372; end=11,604,980**, with matching FFT size (`8388608`), so no padding-induced shift of the polynomial model's reference epoch. Following dedispersion, **8,385,135** samples were transferred to device before internal padding. The chosen data segment is centered on the source's injected full-window epoch to within sampling precision.

**Parameters**: one fixed DM=20 pc/cm³; 15 polynomial bank rows from a={-20,0,+20} m/s² × j={-0.18,0,+0.09,+0.18,+0.27} m/s³. Truth W3/I13: frequency **317 Hz**, a=0 and j=+0.18 m/s³. Requested `--min_freq 154 --max_freq 325` knowingly exploits the existing unpatched PeakFinder lower-bound bug, for approximate effective 308–325 Hz coverage. Both acceleration and jerk vary in templates, but DM is fixed and the bank explicitly contains the true a/j.

**Reported diagnostic counts:** 1 DM trial; 15 polynomial templates all completed resampling, FFT, peak finding and harmonic distillation; **335 raw spectral detections → 93 after harmonic distillation → 10 after polynomial Doppler distillation → 10 final representatives**, **88 nested associated nodes**. Per-DM processing diagnostic `0.133199 s` is not whole-run runtime. Search log:
`$HOME/PULSEJET_validation/stage7_m62_recovery/w3_i13_dm20_aj_bank_center8m_v1.log`.
Candidate XML:
`$HOME/PULSEJET_validation/stage7_m62_recovery/w3_i13_dm20_aj_bank_center8m_v1/overview.xml`.

**Status: successful GPU/algorithmic execution, NOT YET jerk recovery.** The user has not yet posted candidate `period`, `acc`, `jerk`, `snr` fields, and 88 associations do not provide those values for linked templates; do not infer the winner. Next step is read-only summary of the ten final XML candidates, including f=1/P, delta f from 317 Hz, DM, a, j, S/N, nh and nassoc, then fixed-template zero-jerk vs matched-jerk controls to quantify whether jerk increases recovery significance. Do not modify third-party distillers without explicit discussion.


### Stage 7 W3/I13 jerk injection recovered at correct 2-D template (2026-10-27)

User parsed all **10** final candidate records from the completed 15-template, centered ~505-s W3 observational-injection run. The leading survivor is:

| Candidate | Frequency (Hz) | Delta f from injected (Hz) | DM | a (m/s²) | j (m/s³) | S/N | nh | nassoc |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **0** | **316.999969** | **−0.000031** | **20** | **0** | **+0.180** | **39.96** | 3 | **14** |

Truth W3/I13: **f=317.000000 Hz, DM=20, a=0, j=+0.18 m/s³** (injection P0=0.0031545741324921135 s, total-observation target S/N 50). The selected candidate is the highest S/N across the 15-grid search, and the **frequency difference −3.1e−5 Hz is ≈−0.016 Fourier bins** for the 505.19-s segment. This is a controlled two-dimensional **acceleration–jerk template-selection success**, not an unconstrained blind estimate; DM fixed to 20, and exact truth included among templates. High background/other survivor candidates at 309.581207 Hz (S/N 30.24, a=j=0) and 313.448059 Hz (S/N 27.92, a=j=0), also 313.207092 Hz (S/N 17.34, a=20, j=-0.18), cannot currently be classified as astrophysical or RFI without uninjected controls.

**Next discriminating experiment staged, not yet run:** `scripts/run_m62_w3_i13_jerk_control_pair.sh`, commit `2afe3b421b152fe2097d870e8dbbfc99d02d68b3`. Run two **separate single-template** PULSEJET GPU searches of the exact same W3 injection and sample range `start=3216372, nsamples=fft_size=8388608`, one with (a=0,j=0) and one with (a=0,j=+0.18). DM20 and min/max search band workaround 154–325 Hz held constant; report whether/how much candidate S/N near 317 Hz improves for matching jerk without any polynomial-bank distillation confound. A missing thresholded control candidate does not mean zero signal. Only after this paired control should we claim quantified jerk-sensitivity improvement. No search source or distiller modifications.


### Stage 7 W3/I13 measured jerk-correction S/N gain in matched single-template controls (2026-10-27)

The user ran `bash scripts/run_m62_w3_i13_jerk_control_pair.sh` on GPU node3 with the original pinned PULSEJET SIF (PeakFinder lower-limit bug still unfixed), the **same** observational W3 injected `.fil`, `start_sample=3216372`, `nsamples=fft_size=8388608` (~505.19s), DM=20 and a=0 m/s², requested `--min_freq 154 --max_freq 325`. The only modeled signal parameter changed was jerk. Both searches completed normally (`all done`, exit 0), each with one polynomial template:

| Control | Candidate f (Hz) | a (m/s²) | j (m/s³) | Search S/N | `nh` | Outer wall clock | Candidates before/after harmonic grouping |
|---|---:|---:|---:|---:|---:|---:|---|
| A: no jerk correction | 316.999969 | 0 | 0 | **26.72** | 2 | **11s** | 19 → 8 |
| B: matched injected jerk | 316.999969 | 0 | +0.18 | **39.96** | 3 | **10s** | 22 → 6 |

Both returned a final candidate within 0.05 Hz of the injected 317 Hz; the matched jerk recovered the identical best f and `j=+0.18` truth. The relative search S/N increase is `(39.96 / 26.72 − 1) × 100 ≈ +49.55%`, ratio ≈1.4955, absolute increase 13.24 in the pipeline spectral S/N statistic. **This is direct controlled evidence that correcting the injected jerk enhances the search statistic on a real MeerKAT observational background with INCEPTION injection**, not just a distiller-selection artifact, because the runs use independent *single*-template banks. Harmonic `nh` differs (2 versus 3) and the statistic is not a standardized folded significance; the percent increase is not a measured flux-sensitivity/completeness increase. The 11s/10s are short single-shot wall clocks and do not justify performance claims. The noise/interference realization is fixed, not a population sensitivity study.

Control outputs:
`$HOME/PULSEJET_validation/stage7_m62_recovery/w3_i13_dm20_center8m_jerk_controls_v1_zero/overview.xml`,
`.../w3_i13_dm20_center8m_jerk_controls_v1_true/overview.xml`, respective `.log` files and
`.../w3_i13_dm20_center8m_jerk_controls_v1_provenance.txt`. **Checkpoint: controlled W1/I01 stationary, W1/I02 acceleration and W3/I13 jerk injection recovery and jerk benefit all passed.** Next scientifically discriminating test: combined high nonzero acceleration and jerk (e.g., W3/I15 at f=383 Hz, DM8, a=−235 m/s², j=−0.25 m/s³), initially using a physical midpoint-centered 2^23-sample segment and a small bank containing truth and mismatched controls; later test imperfect grid and noise-only/uninjected controls. Do not change original third-party distillers or the source without user discussion.


**Next experiment staged (not yet executed):** `scripts/run_m62_w3_i15_mixed_aj_pilot.sh`, commit `26d93254a44f5ff83a6b8d414714b691094e5261`, uses existing injected W3 real-background filterbank with the same centered 2^23-sample (~505s) segment as I13 and the unmodified pinned PULSEJET SIF. Source `M62_W3_I15` has **f=383 Hz, additional DM=8, acceleration a=−235 m/s², jerk j=−0.25 m/s³**, injected full-observation target S/N=65. One DM8 trial, 15 motion templates a={−255,−235,−215} m/s² × j={−0.40,−0.25,−0.10,0,+0.25} m/s³ (truth included), requested frequency band 187–395 Hz (effective approximately 374–395 Hz in pre-fix PeakFinder). Guarded unique search/log/provenance paths `stage7_m62_recovery/w3_i15_dm8_mixed_aj_center8m_v1*`; script auto-prints final XML candidate f, a, j, S/N and association counts after successful GPU run. This will exercise **mixed negative acceleration and negative jerk** rather than another pure jerk injection. Assess the candidate near 383 Hz and, if correct, follow with independent wrong-jerk controls. No change to scientific search engine or distillers.
