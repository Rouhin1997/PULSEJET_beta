#pragma once
// Read-only CPU-side counters; no CUDA dependencies.
#include <data_types/candidates.hpp>
#include <cstddef>
#include <ostream>
#include <vector>

namespace pulsejet {
inline std::size_t count_associated_nodes(const Candidate& candidate) {
  std::size_t n = candidate.assoc.size();
  for (const auto& x : candidate.assoc) n += count_associated_nodes(x);
  return n;
}
inline std::size_t count_associated_nodes(const std::vector<Candidate>& candidates) {
  std::size_t n = 0;
  for (const auto& x : candidates) n += count_associated_nodes(x);
  return n;
}

struct CandidateDiagnostics {
  std::size_t dm_trials=0, polynomial_templates=0, raw_peaks=0;
  std::size_t after_template_harmonic=0, before_polynomial=0, after_polynomial=0;

  void record_template(std::size_t raw, std::size_t after_harmonic) {
    ++polynomial_templates;
    raw_peaks += raw;
    after_template_harmonic += after_harmonic;
  }
  void record_dm(std::size_t before, std::size_t after) {
    ++dm_trials;
    before_polynomial += before;
    after_polynomial += after;
  }
  CandidateDiagnostics& operator+=(const CandidateDiagnostics& rhs) {
    dm_trials += rhs.dm_trials;
    polynomial_templates += rhs.polynomial_templates;
    raw_peaks += rhs.raw_peaks;
    after_template_harmonic += rhs.after_template_harmonic;
    before_polynomial += rhs.before_polynomial;
    after_polynomial += rhs.after_polynomial;
    return *this;
  }
};

// All counters except nested nodes count top-level candidates.
// Nested association nodes may repeat across groups, so are not unique events.
inline void print_candidate_diagnostics(
    std::ostream& os, const CandidateDiagnostics& s,
    std::size_t pre_dm, std::size_t post_dm,
    std::size_t post_harmonic, std::size_t post_limit,
    std::size_t nested) {
  os << "[POLYNOMIAL_DIAGNOSTICS]\n"
     << "DM trials processed: " << s.dm_trials << '\n'
     << "Polynomial template trials: " << s.polynomial_templates << '\n'
     << "Raw spectral detections: " << s.raw_peaks << '\n'
     << "After per-template harmonic distillation: " << s.after_template_harmonic << '\n'
     << "Before per-DM polynomial distillation: " << s.before_polynomial << '\n'
     << "After per-DM polynomial distillation: " << s.after_polynomial << '\n'
     << "Collected before cross-DM distillation: " << pre_dm << '\n'
     << "After cross-DM distillation: " << post_dm << '\n'
     << "After final harmonic distillation: " << post_harmonic << '\n'
     << "After output candidate limit: " << post_limit << '\n'
     << "Nested associated nodes in final output: " << nested << '\n'
     << "[END_POLYNOMIAL_DIAGNOSTICS]\n";
}
} // namespace pulsejet
