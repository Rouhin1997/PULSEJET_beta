# M62 SIGPROC filterbank window extractor — implementation and validation record

**Recorded:** 2026-10-29  
**Project/branch:** PULSEJET_beta / `dev/polynomial-search`  
**Status:** IMPLEMENTATION ARCHIVED; REAL-DATA LOSSLESS VALIDATION **PENDING**.  
**Scope:** Documentation of a previously used, external-to-PULSEJET SIGPROC extraction utility. **No PULSEJET CUDA, injector, search, or folding algorithms were altered here.**

## Source and provenance

The cluster has two byte-identical copies according to a zero-output `diff -u` provided on 2026-10-29:

- `/home/rnag/PULSEJET_validation/stage6_m62/extract_sigproc_windows.py`
- `/home/rnag/PULSEJET_validation/inception_injection_test_tool/scripts/extract_sigproc_windows.py`

The regression test was located at:

- `/home/rnag/PULSEJET_validation/inception_injection_test_tool/tests/test_extract_sigproc_windows.py`

The implementation and existing test have been **archived** in this repository as
[`scripts/extract_sigproc_windows.py`](../scripts/extract_sigproc_windows.py) and
[`tests/test_extract_sigproc_windows.py`](test_extract_sigproc_windows.py).
The archived content was transcribed from the cluster terminal listing supplied for audit.
**Before relying on exact code identity**, independently compare the repository copies against the corresponding cluster files (e.g. `diff -u` after pulling the branch, then `sha256sum`). The two cluster paths having matched does **not** by itself establish a cryptographic identity with the committed archive.

This is a **custom Python standard-library implementation**, using `struct` and raw binary file reads/writes. The source does not import or invoke sigpyproc, blimpy, PRESTO, or a third-party SIGPROC parser. This is a statement about the dependencies and code shown, **not** an assertion about the historical authorship of every programming idea.

## Motivation and exact observational context

The 2026-10-23 [M62 20-source design](M62_WEEKEND_20_SOURCE_PILOT_DESIGN.md) called for a *real* MeerKAT M62 UHF SIGPROC observation, not a newly synthesized Gaussian-noise filterbank. Four **disjoint** time windows supplied observational noise, RFI, and telescope-specific data structure for five injected signals per window (20 distinct injected pulsars in the pilot).

Recorded M62 input geometry (from cluster run notes; independently recheck when conducting the deferred audit):

| Item | Recorded value |
| --- | --- |
| Input basename | `M62_18U-trapum-pgb_cfbf00001sub_CB.fil` |
| Time samples | 59,285,407 |
| Sampling interval | approximately 60.235294 microseconds |
| Frequency channels | 256 |
| Bits per channel datum | 8 |
| Windows | W1–W4, approx. 892.768 s each |
| Sample counts (expected via floor division) | W1 14,821,351; W2–W4 14,821,352 |
| Approx. payload bytes per sample (if `nifs=1`) | 256 |
| Output names | `W1_M62_background.fil` etc. |

The M62 pilot consists of synthetic *signals* injected into **observed** background filterbank data. This is neither the same as injecting into wholly synthetic Gaussian noise nor proof of every signal's successful recovery. Historical design text may still say "NOT launched" because it was written as a proposal on October 23; subsequent cluster logs contain injection and recovery activity. Do not confuse a design status with a final results audit.

The current **100-injection** run is a separate, ongoing batch. Its status, inputs, outputs, and completeness have not been audited in this document; do not modify its active files or recalculate its experimental claims from the old 20-source plan.

## Extraction algorithm — implementation as archived

1. Open source `rb`, requiring a SIGPROC `HEADER_START` / `HEADER_END` stream with recognized keyword types.
2. Parse supported 32-bit little-endian integers, 64-bit little-endian doubles, length-prefixed UTF-8 strings, and single-byte `signed`. Record the **byte offsets** of header values and the first payload byte.
3. Compute `bytes_per_time_sample = nchans * nbits * nifs / 8` (default `nifs=1` if absent). Reject fractional bytes/time sample, invalid `tsamp`, zero/invalid payload, and a disagreeing nonzero header `nsamples`.
4. Derive time-sample count from the **actual payload length**, not rounded duration: `N = (file_size - header_bytes) / bytes_per_time_sample`.
5. For window `k = 0 .. divisions-1`, define integer bounds:

   ```text
   start_k = floor(k * N / divisions)
   stop_k  = floor((k + 1) * N / divisions)
   count_k = stop_k - start_k
   ```

   The bounds are adjacent, non-overlapping, and cover `[0,N)` exactly.
6. Copy the original header byte array, changing **only** `tstart`, and `nsamples` when that field exists:

   ```text
   tstart_k [MJD] = original_tstart + start_k * tsamp [s] / 86400
   nsamples_k     = count_k  (if present in header)
   ```

   All other header fields and their byte representations are left in place.
7. Seek in the input to `payload_start + start_k * bytes_per_time_sample`. Copy the payload range in at most 16 MiB blocks, **without decoding, dedispersing, filtering, rescaling, or transforming RFI**.
8. Write to a newly created `.fil.part`, flush and `fsync`. Check expected file length, read back parsed header fields, and compare the **first, middle, and last** time samples to the source. Rename the temporary file to the final name on these checks passing.
9. Write `windows_manifest.json` with source path, original header, original sample count, and each output's sample offsets, duration, epoch, and expected bytes.

The source is opened read-only and overwriting an existing final or `.part` output is explicitly prohibited.

**IMPORTANT:** In-code three-sample equality, read-back headers and output lengths are sanity checks, **not exhaustive byte-for-byte proof**. A valid fold or recovered pulsar also does not prove losslessness.

## Use and existing regression tests

Illustrative command; **do not run again on live 100-injection working files or existing outputs**:

~~~bash
python3 scripts/extract_sigproc_windows.py \
  --input /path/to/original_M62.fil \
  --output-dir /path/to/new_separate_empty_directory \
  --windows 4
~~~

The archived test can be exercised on isolated temporary **synthetic** data:

~~~bash
python3 -m unittest discover -s tests -p 'test_extract_sigproc_windows.py' -v
~~~

It constructs 41-sample, four-channel, 8-bit SIGPROC fixtures both with and without the optional `nsamples` header. It checks that execution succeeds, the input bytes remain unchanged, the manifest counts sum to 41, all four files exist, there are no leftover `.part` files, output sizes agree with the manifest, and an existing-output rerun is rejected. The extractor itself additionally checks all output header fields and three sample locations.

**Test scope:** These tests do not independently compare **all** payload bytes, check a general SIGPROC parser, or demonstrate correct operation on the full real M62 observation. Their source inspection is not proof they ran successfully in this documentation session.

## Limitations / risk register

- **Parser portability:** Supported keyword names and types are hard-coded. An unfamiliar legal SIGPROC keyword or a long length-prefixed field can cause a deliberate abort; not a general-purpose filterbank parser.
- **Byte-alignment assumption:** The utility requires whole bytes per time sample, so not every packed/quantized filterbank is supported.
- **Metadata representation:** `nsamples` uses signed 32-bit storage and can overflow for sufficiently large outputs; output `tstart` uses ordinary IEEE-754 doubles, with expected floating-point precision limits.
- **Missing metadata guards:** The code requires `tstart` but does not separately reject a non-finite `tstart`; some optional metadata validity is not checked.
- **Filename specialization:** Outputs are hard-coded to `W{k}_M62_background.fil` even for a non-M62 input.
- **Partial completion:** A failure after some windows have been finalized can leave a partially completed set (not a transaction across all windows). Temporary `.part` files may remain after failure.
- **Verification depth:** Only three payload samples per output are checked internally. The provided unit tests cover only tiny artificial data and do not exhaustively assert correct time sample mapping.
- **Potentially varied formats:** Consult independent SIGPROC software before processing other formats, unusually large `nsamples`, nonstandard headers, different IF counts, or other telescope systems.

These limitations do **not** establish a defect in the M62 outputs; they define what we have and have not proven.

## Deferred scientific validation: perform after current 100-injection batch

Do **not** alter the working original, the W1–W4 backgrounds, active injections, or any currently writing files. Validate in read-only mode once the batch is complete and its products are secured.

1. Identify the **exact original source**, existing W1–W4 background files, `windows_manifest.json`, extractor commit/version and recorded invocation. Confirm none are being written.
2. Record `stat` information and SHA-256 of each immutable existing file. Check that actual sample geometry and all manifest boundaries match the original's payload length; verify contiguous offsets, no overlaps, no gaps, and last `stop = N`.
3. Using parsed `header_bytes`, `start_sample`, `nsamples` and `bytes_per_sample`, compare **every byte** in each existing Wk payload to the corresponding byte range in the original; use streaming comparison or chunked SHA-256. Check header differences separately: expected `tstart` and optional `nsamples` only.
4. Independently parse original and all outputs with a separate known SIGPROC-capable reader (e.g. sigpyproc), verifying channel order, `fch1`, `foff`, `nchans`, `nbits`, `nifs`, `signed`, `tsamp`, `tstart`, duration, and any relevant dispersion metadata. Ensure that different reader versions or unrecognized header extensions are reported, not silently interpreted as validation failures.
5. Cross-check per-window epochs and total timing span from exact sample indices; confirm applicable search/folding reference epochs. **A physical W1–W4 file split is separate from PULSEJET's in-memory `--start_sample` / `--fft_size` analysis windows.**
6. Where practical, extract one controlled window independently with sigpyproc, compare data payload and equivalent metadata (allowing documented harmless header serialization differences).
7. Store commands, versions, hashes, comparison results, checker logs, manifest, cluster path references and any deviations in the PULSEJET development log. Label outcome explicitly **PASS / FAIL / INCOMPLETE**. Only then update status to **real-data lossless verified**.

**Release criterion:** every relevant payload byte matches the original range, correct metadata/epoch and full coverage are independently demonstrated, and findings are recorded. A PASS on the 41-sample test alone is insufficient.

## Follow-on

- Do not replace or patch this archived reference implementation during the 100-injection campaign.
- Consider an independently supported library extraction path for future observational campaigns after the M62 audit.
- If the splitter is revised later, create new tests for byte-level identity, unusual header layouts, multiple IFs, missing `nsamples`, all boundary samples, and recovery of payload by concatenation.
- This document is an implementation/provenance checkpoint, **not** a certification of the M62 science results or any current 100-injection processing.


## Concurrent read-only audit job: node11 or node12 (added 2026-10-29)

This is an **extraction-only** integrity audit of existing completed W1–W4 **background** filterbanks; it does not fold, inject, reformat, search, or read partially written 100-injection outputs. The injection-engine/model audit is a separate gate and is not claimed complete here. A PASS means byte-exact reconstruction of the original payload intervals and the expected limited header edits; independent third-party SIGPROC parsing remains to be done.

Files on branch:
- [`scripts/verify_m62_filterbank_integrity.py`](../scripts/verify_m62_filterbank_integrity.py): streams a **complete, exact** byte comparison of each segment against its section of the original, verifies manifest geometry and full raw header bytes (only `tstart` and optional `nsamples` may differ), and checks for files changing during the audit. Outputs one JSON result **outside** all input directories. Default approximate aggregate read cap: 64 MiB/s.
- [`scripts/run_m62_filterbank_integrity.slurm`](../scripts/run_m62_filterbank_integrity.slurm): single-node CPU Slurm job. Reserve 4 CPUs and 16 GiB RAM for this I/O-bound stage, even though up to 8–10 CPUs were available. Up to two hours requested; actual time is not yet measured.
- [`tests/test_verify_m62_filterbank_integrity.py`](test_verify_m62_filterbank_integrity.py): synthetic regression for a clean pass plus detection of an interior byte corruption that the original first/middle/last sample spot checks would not catch. **New tests must be executed before claiming a green result.**

Suggested independent working directory on cluster:

```text
/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/
    verify_m62_filterbank_integrity.py
    run_m62_filterbank_integrity.slurm
    logs/
    results/<slurm-job-id>/extraction_audit_result.json
```

**Deployment (frontend, no checkout/pull or modifications to the running injection pipeline):**

```bash
WD=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029
REPO=/home/rnag/PULSEJET_beta
mkdir -p "$WD"/logs "$WD"/results
git -C "$REPO" fetch origin dev/polynomial-search
git -C "$REPO" show origin/dev/polynomial-search:scripts/verify_m62_filterbank_integrity.py > "$WD/verify_m62_filterbank_integrity.py"
git -C "$REPO" show origin/dev/polynomial-search:scripts/run_m62_filterbank_integrity.slurm > "$WD/run_m62_filterbank_integrity.slurm"

# Identify the one correct existing extraction manifest; do NOT regenerate files.
find /home/rnag/PULSEJET_validation/stage6_m62 \
     /home/rnag/PULSEJET_validation/inception_injection_test_tool \
     -name windows_manifest.json -type f -print
```

Inspect the returned manifest and confirm `source` points to the **original immutable M62 filterbank** and each `segments[].path` points to the **existing W1–W4 background .fil**, not the injected .fil. These paths cannot be safely inferred from the repository.

**Local CPU-only synthetic regressions** (optional, in the existing repo without checkout):

```bash
cd /home/rnag/PULSEJET_beta
# Run from a workspace containing the new test and script, after preparing code;
# do NOT switch the active pipeline's checkout just to execute these tests.
python3 -m unittest tests/test_verify_m62_filterbank_integrity.py -v
```

**Submit (after setting the manifest from the `find` output):**

```bash
WD=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029
MANIFEST=/absolute/path/to/existing/windows_manifest.json
sinfo -N -n node11,node12 -o '%N %T %C %m'
squeue -w node11,node12
sbatch --nodelist=node11 \
  --export=ALL,AUDIT_WD="$WD",AUDIT_MANIFEST="$MANIFEST" \
  "$WD/run_m62_filterbank_integrity.slurm"
# If node11 is unavailable, instead submit with --nodelist=node12.
```

**Monitor** using the actual job ID returned by `sbatch`:

```bash
squeue -j <job-id>
tail -f /home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/m62_fil_integrity_<job-id>.out
cat /home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/<job-id>/extraction_audit_result.json
```

A failure or an aborted attempt should remain **FAIL_OR_INCOMPLETE** pending inspection; never convert it into a PASS from the mere presence of folded pulses. Logs/results remain in the new working directory. Source and background `.fil` are opened only for reading. Follow-up injection-geometry and model tests should be designed after reviewing the exact INCEPTION-Lite output manifests and injection quantization/scaling implementation; they should run only against **completed** outputs.
