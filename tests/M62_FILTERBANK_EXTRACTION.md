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

## Scientific validation: read-only extraction audit now; injection checks after current batch

Do **not** alter the working original, W1–W4 backgrounds, active injections, or any currently writing files. The **extraction-only, throttled, read-only** audit may run concurrently on a separate node, provided the original and W1–W4 backgrounds are stable. Defer injection-engine/model checks against the active 100-injection outputs until those outputs are finished and secured.

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
    scripts/verify_m62_filterbank_integrity.py
    scripts/extract_sigproc_windows.py
    tests/test_verify_m62_filterbank_integrity.py
    tests/test_extract_sigproc_windows.py
    run_m62_filterbank_integrity.slurm
    code_commit.txt
    code_checksums.sha256
    logs/
    results/<slurm-job-id>/extraction_audit_result.json
```

**Recommended one-time preparation** (frontend; creates only this new working directory, copies pinned scripts with `git show`, runs tiny synthetic tests, and checks the exact known M62 manifest; no local branch checkout, no Slurm submission):

```bash
REPO=/home/rnag/PULSEJET_validation/PULSEJET_dev_source
(cd "$REPO" && git fetch origin)
set -o pipefail
(cd "$REPO" && git show origin/dev/polynomial-search:scripts/prepare_m62_filterbank_integrity.sh) | bash
```

The original observation was recorded at `/archive1/ridolfi/DATA/MeerKAT/ALL_TRAPUM_GC_CENTRAL_BEAMS/M62_18U-trapum-pgb_cfbf00001sub_CB.fil`, and the existing manifest was recorded at `/home/rnag/PULSEJET_validation/stage6_m62/m62_15m_windows/windows_manifest.json`. The preparation script checks that the manifest and its referenced inputs exist, but cannot guarantee that no other process is writing to them; the auditor checks file metadata during its read. The 100-injection output directory is not accessed.

**Manual deployment alternative (frontend, no checkout/pull or modifications to running pipeline):**

```bash
WD=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029
REPO=/home/rnag/PULSEJET_validation/PULSEJET_dev_source
mkdir -p "$WD"/scripts "$WD"/tests "$WD"/logs "$WD"/results
(cd "$REPO" && git fetch origin)
(cd "$REPO" && git show origin/dev/polynomial-search:scripts/verify_m62_filterbank_integrity.py) > "$WD/scripts/verify_m62_filterbank_integrity.py"
(cd "$REPO" && git show origin/dev/polynomial-search:scripts/extract_sigproc_windows.py) > "$WD/scripts/extract_sigproc_windows.py"
(cd "$REPO" && git show origin/dev/polynomial-search:tests/test_verify_m62_filterbank_integrity.py) > "$WD/tests/test_verify_m62_filterbank_integrity.py"
(cd "$REPO" && git show origin/dev/polynomial-search:tests/test_extract_sigproc_windows.py) > "$WD/tests/test_extract_sigproc_windows.py"
(cd "$REPO" && git show origin/dev/polynomial-search:scripts/run_m62_filterbank_integrity.slurm) > "$WD/run_m62_filterbank_integrity.slurm"

# Identify the one correct existing extraction manifest; do NOT regenerate files.
find /home/rnag/PULSEJET_validation/stage6_m62 \
     /home/rnag/PULSEJET_validation/inception_injection_test_tool \
     -name windows_manifest.json -type f -print
```

Inspect the returned manifest and confirm `source` points to the **original immutable M62 filterbank** and each `segments[].path` points to the **existing W1–W4 background .fil**, not the injected .fil. These paths cannot be safely inferred from the repository.

**Run CPU-only synthetic regressions in the isolated working directory** (before submitting real-data audit):

```bash
WD=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029
python3 -m unittest discover -s "$WD/tests" -p "test_extract_sigproc_windows.py" -v
python3 -m unittest discover -s "$WD/tests" -p "test_verify_m62_filterbank_integrity.py" -v
```

**Submit** (only after preparation and synthetic tests succeed; default manifest points to the known W1–W4 backgrounds):

```bash
WD=/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029
MANIFEST=/home/rnag/PULSEJET_validation/stage6_m62/m62_15m_windows/windows_manifest.json
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

## Observed execution result — 2026-10-29, Slurm 66707 (node11)

**Evidence supplied:** terminal output of `tail -f` on `/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/m62_fil_integrity_66707.out`. This subsection records the **observed log**, not an independently retrieved cluster report or a blanket science-validation certificate.

- Preflight on frontend2: original extractor synthetic regression **2/2 tests passed**; new full-payload integrity verifier's positive/negative corruption test **1/1 passed**. The preparation check found the source M62 observation and W1–W4 backgrounds.
- Job ID **66707**, running on `node11.cluster`; audit began **2026-10-29T12:38:36+0100**.
- Input manifest: `/home/rnag/PULSEJET_validation/stage6_m62/m62_15m_windows/windows_manifest.json`.
- Read rate cap: approx. **64 MiB/s** across source and window reads.
- The verification script printed the following **four PASS lines**:

| Window | Time samples | Payload bytes compared | Reported result |
| --- | ---: | ---: | --- |
| W1 | 14,821,351 | 3,794,265,856 | PASS |
| W2 | 14,821,352 | 3,794,266,112 | PASS |
| W3 | 14,821,352 | 3,794,266,112 | PASS |
| W4 | 14,821,352 | 3,794,266,112 | PASS |
| **Total** | **59,285,407** | **15,177,064,192** | **4/4 per-window checks passed** |

The verifier emits each `PASS Wk` only after exact binary payload comparison, expected source-to-segment indexing, and raw-header checks (with `tstart` and optional `nsamples` being the only allowed differences). It also checked input stat metadata stability at completion of each window.

The excerpt ended with:
```text
REPORT /home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/66707/extraction_audit_result.json
```

**Not yet independently read here:** the JSON contents, final `AUDIT FINISHED` log line, `sacct` exit status, and third-party SIGPROC parser result. Please obtain these before marking the *entire Slurm job* finalized. The per-window full-payload comparison **has passed**. This directly supports that the splitter preserved the existing observational sample bytes, not that injection generation, injector S/N, or folding were validated. These remain separate gates.

Finalization command on cluster:

```bash
cat /home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/66707/extraction_audit_result.json
tail -n 5 /home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/m62_fil_integrity_66707.out
sacct -j 66707 --format=JobID,State,ExitCode,Elapsed,NodeList
```

## Final verification confirmation — Slurm 66707 (2026-10-29)

**Status: PASS — extraction payload and permitted-header-change integrity verified on existing real M62 observational data.**

The operator subsequently inspected the persisted JSON report and final stdout log. Confirmed outputs:

```text
"status": "PASS",
"total_payload_bytes_compared": 15177064192,
AUDIT FINISHED 2026-10-29T12:46:09+0100
```

The reported `elapsed_seconds` is **452.847 s** (7 min 32.847 s). The audit started at **2026-10-29T12:38:36+0100** on **node11.cluster** (Slurm **66707**). All four complete source-to-window payload comparisons passed: W1 3,794,265,856 bytes; W2/W3/W4 3,794,266,112 bytes each. Total: **15,177,064,192 payload bytes = 59,285,407 time samples** for 256 bytes per time sample. The verification also checked exact permitted header-byte differences (`tstart`, optional `nsamples`), source sample positions, sample counts, output sizes, expected epochs, and file metadata stability.

**Scientific interpretation:** the four existing M62 windows are verified exact, byte-preserving extracts of the corresponding original observational payload. The original observational noise and any RFI encoded in those samples were not modified by the splitter. This confirms the extraction gate used by the 20-source pilot and as background for subsequent experiments; it does **not** validate the injection engine, S/N scaling, timing model, or folds. Independent third-party SIGPROC reader validation remains optional follow-up for interoperability. The `sacct` status was not available in the supplied output, but the report status and final `AUDIT FINISHED` line are both confirmed.

**Permanent cluster artifacts:**
- `/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/results/66707/extraction_audit_result.json`
- `/home/rnag/PULSEJET_validation/m62_filterbank_validation_20261029/logs/m62_fil_integrity_66707.out`

**Next gate:** inception_lite injection integrity and modeled signal truth on completed outputs; do not disturb the active 100-injection batch. The S/N-versus-RFI study is reserved for the subsequent pipeline-paper analysis.
