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
