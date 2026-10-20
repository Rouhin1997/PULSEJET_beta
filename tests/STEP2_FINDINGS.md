# Step 2 — Synthetic candidate-population diagnosis (CPU only)

Status: **characterization complete, no production algorithms modified**.

- PULSEJET baseline: master at 09c427557113b236785c955cdb6c03086b3902b8.
- Comparison upstream: vishnubk/peasoup at 78cb72b2853b2069e19d6c03f073a51f882ea5f9.
- Reproducible GitHub Actions run: https://github.com/Rouhin1997/PULSEJET_beta/actions/runs/39395208451
- Driver: tests/test_candidate_populations.cpp
- Command: bash tests/run_cpu_tests.sh
- Suite result in the run above: 12/12 + 8/8 + 17/17 assertions passed.

## Interpretation first

A passing CHARACTERIZATION test records observed behaviour of the current code.
It is not proof of astrophysical correctness. All detections and source IDs in
this experiment are deliberately constructed on the CPU; none were recovered
from a synthetic time series or an injected radio observation.

The current polynomial search calls the Doppler distiller **per DM**, after
per-template harmonic distillation. The user's
Template_Bank_Polynomial_Distiller is defined but **not wired** into this path.
The shared DMDistiller and final HarmonicDistiller act later, after results from
DM trials have been collected.

For this reason, excessive independent output candidates from **one
acceleration/jerk template** cannot be ascribed solely to the per-DM polynomial
distiller. Cross-DM frequency matching is an important independent cause to
investigate with real candidates.

## Measurements

Default relative frequency tolerance = 1e-4; for tests at f=100 Hz, this is
approximately +/-0.01 Hz. Observation duration in Doppler examples = 1800 s.
User polynomial tolerance examples = 1% acceleration, 2% jerk (arbitrary,
not scientifically calibrated).

| Labelled input / treatment | Input | Output representatives | Association count | Mixed-truth groups |
|---|---:|---:|---:|---:|
| 40 DMs x three harmonics, per-template harmonic step | 120 | 40 | 0 | 0 |
| Same, within-DM polynomial Doppler step | 40 | 40 | 0 | 0 |
| Same, cross-DM step | 40 | 1 | 39 | 0 |
| One source, intentionally wide frequency scatter, cross-DM | 40 | 5 | 35 | 0 |
| Two distinct sources 0.005 Hz apart, cross-DM | 40 | 1 | 39 | 1 |
| One source over 11 nearby acceleration+jerk templates, user's polynomial rule | 11 | 11 | 0 | 0 |
| Same 11, current Doppler rule | 11 | 1 | 10 | 0 |
| Two sources, same spin frequency but unlike motion parameters, user's rule | 2 | 2 | 0 | 0 |
| Same two sources, current Doppler rule | 2 | 1 | 1 | 1 |
| Same-source detections separated by 1 bin at Tobs=30 s, cross-DM | 2 | 2 | 0 | 0 |
| Same-source detections separated by 1 bin at Tobs=3600 s, cross-DM | 2 | 1 | 1 | 0 |
| Two well-separated sources over 20 DMs, cross-DM | 40 | 2 | 38 | 0 |

The intentionally broad 40-DM scatter spans +/-0.022 Hz at 100 Hz, many
Fourier bins for an 1800-s example observation. It is a **stress test of the
matching rule**, not a predicted frequency-error distribution.

Likewise, the equal-spin-frequency/two-acceleration case is an adversarial
matching-policy check, not a claim that such distinct sources are easily
separable in every observation.

The 0.005-Hz two-source separation exceeds the Fourier bin width of
1/1800 ~= 0.000556 Hz, yet falls within the 0.01-Hz cross-DM matching window
at 100 Hz. Fourier resolution alone is not a full distinguishability model.

## Other observed edge case

Existing CPU tests also record that a weaker event can be associated with
two stronger representatives if both satisfy the original Peasoup
BaseDistiller-based frequency predicates. This can duplicate an association
without increasing the number of top-level output candidates; do not confuse
"associations" with "independent representatives".

## Hypotheses for the historical high output count

1. Expected multiplicity: one periodic source can generate peaks over several
   DM trials, neighboring FFT frequency bins, and harmonics.
2. Inadequate grouping: fixed relative frequency matching across DMs can
   leave multiple groups if the detections span more than one matching window.
3. Incorrect grouping: the same fixed tolerance can also incorrectly merge
   two distinct frequency-near sources.
4. Template-level grouping differs: the currently wired Doppler and inactive
   user polynomial methods have opposite strengths and failure modes in the
   controlled examples.
5. A duplicate *association* is not necessarily a duplicate top-level XML
   candidate. Both counts should be measured independently.

None is confirmed as the sole cause of the previous run, because its XML and
source-level event history have not yet been reproduced.

## Recommended next implementation gate

Before modifying matching rules:

1. Add optional **non-algorithmic** candidate-count instrumentation at the
   per-template harmonic, per-DM polynomial, cross-DM, and final harmonic steps,
   reporting top-level and nested association counts separately.
2. Consider a sample of actual candidate parameters when a GPU execution is
   available, especially frequency, DM, harmonic index, acceleration, jerk,
   and the observation's FFT duration.
3. Agree on the scientifically appropriate relationship for deciding two
   detections are the same source. It should account for frequency resolution,
   search-template mismatch/parameter covariance, and possibly DM response
   rather than relying only on parameter-relative tolerances.
4. Put any revised **polynomial-only** distillation behind a distinct module
   and run the existing synthetic false-merge tests as regressions. Leave
   upstream Peasoup and the existing Doppler distiller intact.
5. Validate on CPU signal-level models and then on injected data/CUDA before
   drawing sensitivity or recovery conclusions.

**No existing distiller, CUDA resampler, or pipeline code has been edited in
Step 2's synthetic experiments.**
