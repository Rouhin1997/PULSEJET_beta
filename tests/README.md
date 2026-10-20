# PULSEJET candidate-distillation CPU tests

These tests run **the existing production C++ headers** without CUDA, a GPU,
SIGPROC filterbank, PSRFITS observation, or the `dedisp` library.

## Quick start

From the repository root on Linux (or in GitHub Actions):

```bash
bash tests/run_cpu_tests.sh
```

Requires only a C++17 compiler (`g++` by default) and a POSIX shell.

## Tests

- `test_polynomial_distiller.cpp`: characterize
  `Template_Bank_Polynomial_Distiller` with empty and single-candidate inputs,
  nearby detections, independent frequencies, acceleration/jerk differences,
  representative selection, associated-candidate metadata, and near-zero
  acceleration/jerk thresholds.
- `test_candidate_grouping.cpp`: characterize the *unchanged* upstream
  `DMDistiller` and `HarmonicDistiller`. Also log a diagnostic scenario where
  one candidate can be associated with two stronger representatives.

These are **characterization tests**, not evidence that the current candidate
matching is astrophysically optimal. In particular:

1. The polynomial distiller is currently defined but **not invoked** by the
   polynomial branch in `src/pipeline_multi.cu`. That branch currently
   invokes `Template_Bank_Polynomial_DopplerDistiller`.
2. Production polynomial distillation occurs *within* a DM trial; cross-DM
   candidate grouping happens subsequently through the shared `DMDistiller`.
3. A small relative tolerance around zero acceleration/jerk can leave nearby
   detections ungrouped. The test records this behavior but does not endorse it.
4. The shared base distillation loop does not exclude previously marked
   candidates from subsequent representatives' association lists. The overlap
   diagnostic reports this; it is **not yet a regression-test requirement**
   and is not repaired by this baseline change.

## Baselines and scope

- PULSEJET base commit: `09c427557113b236785c955cdb6c03086b3902b8`
  (`master`, 2025-10-28).
- Upstream reference: `vishnubk/peasoup`, commit
  `78cb72b2853b2069e19d6c03f073a51f882ea5f9` (2026-07-28).

The tests intentionally **do not modify** any pipeline, resampler, distiller,
candidate, or kernel implementation. The automatic workflow is separate from
the existing Docker/GPU build and does not require Docker Hub credentials.

Next: review results, isolate a failing scientifically justified candidate
grouping fixture, then develop a correction in a separate change.

## Step 2: labelled candidate-population experiments

`test_candidate_populations.cpp` is a deterministic CPU-only characterization
suite using the real production Peasoup/PULSEJET distillers. It reports for
each scenario: input candidate count, number of top-level representatives,
association count, unique event IDs represented, repeated memberships across
groups, groups mixing ground-truth sources, and the number of independently
represented source labels.

The labelled populations isolate **candidate grouping**, not signal detection.
Frequency offsets are deliberate stress-test values, not empirical models of
frequency-estimation scatter or the output of a time-series simulation.

Scenarios:

1. 40 DM trials, one polynomial template and three harmonics per DM;
   emulate the actual per-template harmonic -> per-DM Doppler -> cross-DM
   -> final harmonic sequence.
2. One source with a broader frequency scatter across 40 DMs.
3. Two separable spin frequencies within the default *relative* DM-distiller
   matching window (reveals false merging).
4. One source across nearby acceleration/jerk templates near zero; compare
   the user's polynomial rule with the currently wired Doppler rule.
5. Two distinct sources with equal detected spin frequencies but different
   acceleration/jerk (adversarial test of false merging).
6. One-bin separation for 30-s versus 3600-s observations (demonstrates the
   observation-length dependence missing from a fixed relative frequency
   tolerance).
7. Two well-separated spin frequencies across 20 DM trials.

**Interpreting passing results:** A passing characterization assertion can
identify *undesirable current behaviour*. See the `CHARACTERIZATION` prefix.
The experiments do not establish which matching policy should replace an
existing one, and do not replace physical signal-injection tests.

Run with `bash tests/run_cpu_tests.sh`; output lines start with
`[POPULATION]` and `[PASS]` or `[FAIL]`. All existing production
algorithms, the Doppler distiller, and Peasoup components remain unchanged.

## Step 2 results

See [STEP2_FINDINGS.md](STEP2_FINDINGS.md) for the measured candidate counts,
false-merge fixtures, limitations, and the next proposed diagnostic gate.


## Read-only candidate diagnostics in the actual polynomial search

Run a polynomial-only search with an optional flag:

```bash
./bin/peasoup -i observation.fil -P polynomial_templates.txt \
  --dm_file dm_trials.txt --fft_size 16777216 -t 1 \
  -o results --candidate_diagnostics
```

The summary in stdout is bracketed by `[POLYNOMIAL_DIAGNOSTICS]` and
`[END_POLYNOMIAL_DIAGNOSTICS]`. It reports the number of peaks before and
after per-template harmonic grouping, before and after per-DM polynomial
grouping, and before/after cross-DM and final harmonic grouping, and the
final output limit. An additional recursive count of *nested associated nodes*
is included. Associated nodes can appear in multiple groups, so this does
not claim a count of unique detections.

Each worker owns its counters; these are combined after the worker threads
join, across all DM chunks. No extra lock is required. The report is only
produced in polynomial mode, with `-P` and without an active Keplerian `-K`
search. It does not alter any resampling or distillation decision.

`test_candidate_diagnostics.cpp` tests accumulation, recursive association
counts and report formatting on CPU. **GitHub's CPU tests do not compile or
execute the full CUDA pipeline.** The integrated build and a sample GPU run
are still required before claiming the diagnostic works end-to-end.

## Phase A: polynomial timing and pre-deployment wiring

See [PHASE_A_FINDINGS.md](PHASE_A_FINDINGS.md) for the derived midpoint
acceleration–jerk arrival-time convention, a reproducible CPU pulsar-signal
injection experiment, the corrected polynomial-only kernel mapping, template
reader and XML metadata changes, and the Phase B container/GPU checklist.

The test runner also executes `test_polynomial_timing.cpp` and
`test_polynomial_templatebank.cpp`. The CPU GitHub workflow separately runs
`python3 tests/test_polynomial_wiring.py` to check the expected source-code
connections and container build configuration.

**Scope boundary:** Passing CPU/static checks does not prove NVCC compilation
or GPU parity. The manual container build and SIF runtime testing remain the
required next gate before observations.
