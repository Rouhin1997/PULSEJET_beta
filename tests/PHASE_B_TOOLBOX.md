# Phase B — PULSEJET + PulsarX candidate toolbox

## Added tools

PULSEJET GPU search; PulsarX psrfold_fil, psrfold_fil2, psrheader,
filtool, dedisperse_all_fil, pulsar_injector; PlotX and XLibs;
Python 3 with NumPy, SciPy, Astropy, Matplotlib, pandas and YAML.
PulsarX source revisions are pinned in Dockerfile. A MeerKAT
fold template is installed as
/usr/local/share/pulsarx/meerkat_fold.template.

PRESTO, DSPSR, PSRCHIVE, TEMPO2 and binary-timing suites remain
optional, not requirements for the initial search-fold-recover tests.

## Convert polynomial XML to a PulsarX candidate file

PULSEJET overview.xml does not directly work as psrfold_fil --candfile.
Use the included command:

    pulsejet_xml_to_pulsarx results/overview.xml \
        -o results/pulsarx.cands \
        --manifest results/pulsarx.json --min-snr 7 --limit 100

PulsarX accepts candidate rows with seven columns:

    #id DM acc F0 F1 F2 S/N

Our midpoint reference epoch and positive-away acceleration convention
imply frequency derivatives:

    F0 = 1 / period
    F1 = -acc * F0 / c
    F2 = F0 * (2 * (acc/c)^2 - jerk/c)

PulsarX accepts F2 and uses a cubic spin phase. The converter stores
the XML reference MJD and searched segment information in its JSON
provenance file. It refuses missing midpoint metadata by default.
Do not enable --allow-legacy without independently checking the
historical timing convention.

## Fold the same segment

Illustrative command ONLY for a full-length observation where the
PULSEJET FFT covers the exact file interval:

    psrfold_fil --candfile results/pulsarx.cands \
        --pepoch <MJD_FROM_CONVERTER> \
        --template /usr/local/share/pulsarx/meerkat_fold.template \
        --nosearch -n 32 -b 64 \
        -f observation.fil -o folded_run

The mandatory epoch comes from segment_parameters/segment_pepoch.
PulsarX provides --jump and --frac to select a subrange. If the
PULSEJET search used --start_sample, a truncated segment or zero
padding, configure the folding interval to match; do not silently
fold the entire original file.

Start with --nosearch to test the input parameters without
optimization. Compare later to explicit --f2search refinement.
Re-optimizing S/N does not by itself establish correct jerk recovery.

## Important upstream PulsarX caveat

The pinned PulsarX code reads both F1 and F2 from seven-column files
and uses cubic phase F0*t + F1*t^2/2 + F2*t^3/6. But its
include/archivelite.h implementation of get_ffold seems to have
0.5*F2*t rather than 0.5*F2*t*t. We did not patch third-party
source. Verify reported folding frequencies during GPU/injection
validation before claiming complete correctness.

The converter includes both acceleration and equivalent F1. PulsarX
derives F1 from acceleration only when F1 is zero; passing consistent
values does not apply acceleration twice.

## Validation and reproducibility

The extended Docker image must pass a new GitHub build with
psrfold_fil and psrfold_fil2 smoke tests, and the XML converter's
independent CPU unit tests. A successful build is NOT a successful
fold test.

On SingularityCE 3.11, pull a commit-tagged Docker image into a
read-only SIF. Use --nv when running PULSEJET; PulsarX folding is
generally CPU-only. If site policy blocks on-cluster image conversion,
build the SIF externally and transfer using approved HPC procedures.

Before real data: compare CPU and CUDA kernel indices; inject synthetic
SIGPROC filterbank signals; search; convert XML; fold exactly the same
segment; compare F0, F1, F2, DM and profile coherence against injected
truth; preserve the SIF version and all intermediate outputs.

The shared Peasoup Candidate structure stores acceleration and jerk
as float even though the polynomial resampler now accepts double.
This limits output parameter precision.

## First expanded image build result (2026-10-20)

GitHub Actions build: https://github.com/Rouhin1997/PULSEJET_beta/actions/runs/39408031261

Outcome: **SUCCESS**, published both a commit-specific tag and a mutable
`dev-polynomial-latest` tag. Pin the immutable commit tag for SIF conversion.

- Git commit: `513e80d1ace21868fd3d3d37734bcd79782abce3`
- OCI manifest-list digest: `sha256:7d60ac506e48af31ad9dfbb4cb9c2a206d585156ce56333c818ef8ecf9b9a53c`
- Docker Hub image: `<existing-dockerhub-namespace>/pulsejet:dev-polynomial-513e80d1ace21868fd3d3d37734bcd79782abce3`
- Core PULSEJET CUDA `sm_86` compile: from existing build setup, successful.
- PulsarX  native binaries linked and installed: `psrfold_fil`, `psrfold_fil2`, `pulsar_injector`, `psrheader` and others.
- Python import smoke check: numpy, scipy, astropy, matplotlib, pandas successful.
- CLI smoke checks: both folding programs and XML converter successful.
- Converter scientific validation: CPU unit tests passed.

**Not yet tested:** SingularityCE conversion/runtime on the A40 cluster,
actual folded synthetic pulse profile, correct relative phase after matching
a filtered/zero-padded data segment, and independent verification of PulsarX
F2 reporting. The compiled PulsarX binaries used `-mavx2 -mfma` CPU flags,
so verify those CPU features exist on your cluster's compute nodes before
relying on these binaries (or rebuild for a portable target).
