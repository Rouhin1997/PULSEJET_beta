#!/usr/bin/env python3
"""Read-only CPU source wiring audit; this is not a CUDA build."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]

def source(path):
    return (root / path).read_text(encoding="utf-8")

def check(label, condition):
    if not condition:
        raise AssertionError(label)
    print("[WIRING PASS]", label)

pipeline = source("src/pipeline_multi.cu")
kernels = source("src/kernels.cu")
decl = source("include/kernels/kernels.h")
reader = source("include/transforms/polynomial_templatebank_reader.hpp")
output = source("include/utils/output_stats.hpp")
cmdline = source("include/utils/cmdline.hpp")
docker = source("Dockerfile")
workflow = source(".github/workflows/build-dev.yml")
timing = source("include/transforms/polynomial_timing.hpp")
wrapper = source("include/transforms/polynomial_resampler.hpp")

check("-P parser connects to bank reader",
      "arg_polynomial_template_bank_filename" in cmdline and
      "polynomial_tb.emplace(args.polynomial_tb_file)" in pipeline)
check("Double-precision parameters reach isolated polynomial wrapper",
      "double acc, double jerk, double tsamp" in pipeline and
      "PolynomialTimeDomainResampler resampler" in pipeline and
      "resampler.resample(d_tim.get_data()" in pipeline)
check("No direct polynomial CUDA function call from worker pipeline",
      "device_resample_acc_jerk(" not in pipeline)
check("Polynomial CUDA declaration and implementation use double",
      re.search(r"device_resample_acc_jerk\([^;]*double acc_value,\s*double jerk_value,\s*double tsamp", decl, re.S) is not None and
      re.search(r"void device_resample_acc_jerk\([^)]*double acceleration,\s*double jerk,\s*double tsamp", kernels, re.S) is not None)
check("CUDA kernel uses same midpoint index model as CPU tests",
      "polynomial::input_sample_index(" in kernels and
      "poly::input_sample_index(" in source("tests/test_polynomial_timing.cpp") and
      "tau * tau" in timing)
check("CUDA checks boundaries before unsigned index conversion",
      kernels.index("source >= 0.0 && source <") < kernels.index("__double2ull_rn(source)"))
check("Candidate stages still wired with counters",
      "candidate_diagnostics.record_dm(" in pipeline and
      "diagnostics->record_template(" in pipeline)
check("Cross-DM and final harmonic grouping remains connected",
      "dm_still.distill(dm_cands.cands)" in pipeline and
      "harm_still.distill(dm_cands.cands)" in pipeline)
check("Original Doppler distiller remains connected",
      "poly_dopp_dist.distill(polynomial_search_cands.cands)" in pipeline)
check("Progress counts polynomial trial bank",
      "full_dm_list.size() * polynomial_tb->get_acc().size()" in pipeline)
check("Output records polynomial metadata and timing reference",
      "polynomial_template_bank_file" in output and
      "polynomial_reference_epoch" in output and
      "stats.add_search_parameters(args, nullptr, &*polynomial_tb)" in pipeline)
check("Output uses midpoint for polynomial segment epoch",
      'if (args.keplerian_tb_file != "none")' in output and
      "f.get_segment_pepoch_accel_search()" in output)
check("Template bank rejects empty and non-finite entries",
      "no usable acceleration-jerk templates" in reader and
      "std::isfinite(aval)" in reader)
check("Development Docker build uses checked-out code",
      "COPY . /software/peasoup" in docker and
      "git clone https://github.com/Rouhin1997/PULSEJET_beta.git" not in docker)
check("Versioned development image can be built manually",
      "workflow_dispatch" in workflow and
      "dev-polynomial-" in workflow and "github.sha" in workflow)
print("All static wiring assertions passed; CUDA linkage/runtime NOT verified.")
