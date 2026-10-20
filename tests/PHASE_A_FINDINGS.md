# PULSEJET Phase A — polynomial acceleration–jerk timing validation

**Status:** Independent mathematical and CPU signal-level validation passed.
**Source-wiring:** Static audit passed; compiled CUDA executable not yet verified.
**Branch:** dev/polynomial-search. **Base:** master at
09c427557113b236785c955cdb6c03086b3902b8.

## Physical convention

We define acceleration a (m/s²) and jerk j (m/s³) at the midpoint of
the FFT segment. The (unmodelled) constant propagation delay and
line-of-sight velocity at that epoch are absorbed into spin phase and
spin frequency; the model uses zero *relative* reference velocity.
Positive a is positive line-of-sight acceleration away from the observer,
with positive light-travel-time delay.

Let t be uniform emission/reference time, t_mid = (N/2) dt, and
tau = t - t_mid. The time at which to **read the observed signal** is

    t_arr(t) = t + [a tau²/2 + j tau³/6]/c,

    dt_arr/dt = 1 + [a tau + j tau²/2]/c.

For corrected output sample i, the unrounded input index is

    i_in = i + (a dt/(2c))(i - N/2)²
             + (j dt²/(6c))(i - N/2)³.

Input samples use nearest-even rounding and zero padding outside
[0,N). The expressions are valid when velocities remain nonrelativistic
and the time map is monotonic; they are a truncated local binary-motion
model, not an exact Keplerian orbit. The reference time is the *sample
midpoint N/2* rather than the midpoint of indices (N-1)/2.

## Defect identified in the historical polynomial mapping

Original kernel acceleration term:

    (a dt/(2c)) i (i-N/2).

This corresponds to a different first derivative at the reference
epoch, and is not equivalent to the midpoint acceleration time delay
plus an additive constant. In particular, it differs from the existing
Peasoup acceleration-II mapping i(i-N). The original Peasoup mapping
and the new midpoint mapping *do* differ only by a constant offset when
j=0, so their frequency-drift corrections match.

This issue is isolated to the **polynomial CUDA kernel**. The Peasoup
acceleration-only, circular and Keplerian resamplers were not modified.

## Synthetic periodic-signal test

Independent injector: for each sampled arrival time, solve the
arrival-time equation for the emitting time using Newton iteration,
then evaluate sin(2π f0 t_emit). This does **not** use PULSEJET's
resample-index function to generate the input.

Parameters: 16,384 samples, dt=0.02 s, f0=9 Hz; deliberately strong
a/j values to stress the mapping. The CPU test measures normalized
coherent Fourier amplitude at the known intrinsic spin frequency.
These experiments contain no radio noise, dispersive propagation,
dedispersion or CUDA execution and are **not** a detection-sensitivity
or survey-performance estimate.

| a (m/s²) | j (m/s³) | Uncorrected | Corrected linear-interpolated | Corrected nearest |
|---:|---:|---:|---:|---:|
| +2500 | 0 | 0.3004 | 0.9063 | 0.9532 |
| 0 | +40 | 0.3920 | 0.9192 | 0.9607 |
| +2500 | +40 | 0.5940 | 0.9190 | 0.9627 |
| -2500 | -40 | 0.5942 | 0.9187 | 0.9627 |
| +1000 | -50 | 0.4121 | 0.9222 | 0.9628 |

For (+2500,+40), the historical *nearest-sample* polynomial mapping
recovers **0.0040**, against **0.9627** with the midpoint model.
The old formula was not tested on the GPU; the CPU test emulated its
source-index expression.

Corrected-linear values are lower than corrected-nearest in this
noiseless test because linear interpolation filters higher-frequency
content. This is not a recommendation that nearest interpolation is
globally optimal.

## Code changes justified by Phase A and the wiring audit

1. **New \`include/transforms/polynomial_timing.hpp\`:** one pure
   timing expression compiled on both CPU and CUDA. Documented reference
   epoch, sign and valid derivative.
2. **Polynomial CUDA kernel only (\`src/kernels.cu\`):** uses the
   verified index expression, checks negative and out-of-range
   floating positions before converting to unsigned, preserves nearest
   neighbour and explicit zero padding. Actual GPU output remains
   untested.
3. **Dedicated \`include/transforms/polynomial_resampler.hpp\`:**
   connects the pipeline to polynomial CUDA logic without altering
   Peasoup's original \`TimeDomainResampler\`.
4. **Double precision:** acceleration, jerk and sampling interval
   are passed as double from the template bank through the polynomial
   wrapper to the kernel. **Limitation:** the shared \`SearchParams\`
   and \`Candidate\` acceleration/jerk metadata remain float (upstream
   compatibility), so XML candidate parameters still have float
   precision. We should not claim full double precision end-to-end.
5. **Template bank validation:** rejects empty/header-only files,
   NaN/Inf, partially numeric rows, malformed numeric column counts,
   and values beyond representable candidate-float range. Valid bank
   values and recognized metadata remain supported.
6. **XML output:** records the polynomial bank filename and available
   header metadata, declares midpoint/zero-relative-velocity timing
   and nearest-neighbour sampling. The existing Peasoup acceleration
   \`segment_pepoch\` already selects the segment midpoint and is
   retained for polynomial mode.
7. **Progress reporting:** when polynomial mode is selected, trial
   estimate is DM count times polynomial bank length instead of
   the acceleration-only plan estimate. Keplerian priority if both
   -K and -P are present is unchanged.
8. **Development container source pinning:** \`Dockerfile\` now
   copies the GitHub Actions checked-out source, preventing the
   historical Docker build from silently re-cloning \`master\` while
   triggered on a development branch.
9. **Manual development-image workflow:** \`.github/workflows/build-dev.yml\`
   builds a commit-tagged Docker image, without triggering an
   expensive build on every CPU-test push. **This Docker workflow has
   not yet been run or verified**.

No original Peasoup distiller, original acceleration resampler, original
Keplerian search or Doppler distiller was changed. The user's polynomial
distiller remains defined but inactive; Step 2 documented why no
candidate-matching correction should be rushed into Phase A.

## CPU verification

Run:

    bash tests/run_cpu_tests.sh
    python3 tests/test_polynomial_wiring.py

There are seven C++ suites: 12 + 8 + 17 + 12 + 5 + 31 + 10 =
**95 assertions**, plus **15 static source-wiring checks**.

CPU assertions exercise:

- exact zero-motion sample identity;
- analytic arrival-time derivative and midpoint epoch;
- constant-acceleration limiting relationship to Peasoup;
- an independent simulated pulsar time stream;
- positive/negative a and j;
- zero padding and historical formula comparison;
- template parsing and error handling;
- previous candidate-population and diagnostic tests.

Source-wiring checks are assertions on the checked-in code. They do
not substitute for compiling or executing the CUDA code.

## Phase B / Singularity preflight gate

1. On GitHub, manually dispatch
   \`build-pulsejet-development-image\` on \`dev/polynomial-search\`.
   Confirm Docker image compile, \`peasoup --help\`, and the exact
   revision baked into the image. Do not assume a CPU-only workflow
   proves the NVCC build.
2. If credentials and external dependency builds succeed, the image
   will be tagged
   \`<dockerhub-user>/pulsejet:dev-polynomial-<full-git-commit-sha>\`.
   Pin the SIF to a **commit tag**, not the mutable latest tag.
3. Where permitted, pull and convert on the cluster using
   \`apptainer pull some-name.sif docker://<user>/pulsejet:<commit-tag>\`.
   This produces a read-only SIF, **not** a writable sandbox.
   If the cluster prohibits conversion, produce the SIF elsewhere
   and transfer it via the approved HPC procedure.
4. Alternative: use an existing *development* SIF with nvcc/dedisp
   and a writable, host-mounted source checkout. Recompile the
   branch into a bound work directory on each iteration.
5. First GPU check: compare selected CUDA output sample indices and
   time series against the CPU model, including negative indices,
   endpoint padding, the zero-motion case and both signs of a/j.
6. Then run controlled SIGPROC filterbank injections and assess
   recovered candidate frequency, acceleration, jerk, signal-to-noise,
   false merges and resource usage.

Before using a SIF, check the GPU driver compatibility with its CUDA
version and the cluster's Apptainer/Singularity policy. The master
Docker image uses CUDA 12.6, dedisp, and the original Makefiles;
none of these system dependencies have been validated on the cluster
in Phase A.

**Conclusion:** Phase A mathematics and CPU/static preflight pass,
but CUDA compilation, a built development image, GPU kernel parity,
and filterbank sensitivity are **pending Phase B**.
