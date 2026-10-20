// CPU test for opt-in read-only stage statistics.
#include "test_support.hpp"
#include <utils/candidate_diagnostics.hpp>
#include <sstream>
#include <string>
#include <vector>
using namespace pulsejet_test;
int main() {
  TestSuite t;
  pulsejet::CandidateDiagnostics a, b;
  a.record_template(30, 8);
  a.record_template(12, 5);
  a.record_dm(13, 4);
  b.record_template(10, 2);
  b.record_dm(2, 1);
  a += b;
  t.expect(a.dm_trials == 2, "DM counts combine between workers");
  t.expect(a.polynomial_templates == 3, "Template counts combine between workers");
  t.expect(a.raw_peaks == 52, "Raw peak totals combine");
  t.expect(a.after_template_harmonic == 15, "Post-harmonic counts combine");
  t.expect(a.before_polynomial == 15 && a.after_polynomial == 5,
           "Pre/post polynomial counts recorded separately");
  Candidate c = make_candidate(100, 12, 50, 0, 20, 0.001f);
  Candidate d = make_candidate(100.1f, 10, 50.1f, 1, 20, 0.001f);
  Candidate e = make_candidate(100.2f, 8, 50.2f, 2, 20, 0.001f);
  d.assoc.push_back(e);
  c.assoc.push_back(d);
  std::vector<Candidate> candidates{c,make_candidate(120,6,51,3,20,0.001f)};
  const auto prior = candidates.size();
  t.expect(pulsejet::count_associated_nodes(candidates) == 2,
           "Nested associations counted recursively");
  t.expect(candidates.size() == prior && candidates[0].assoc.size() == 1,
           "Association counting does not change data");
  t.expect(pulsejet::count_associated_nodes(std::vector<Candidate>{}) == 0,
           "Empty candidates have zero associated nodes");
  std::ostringstream oss;
  pulsejet::print_candidate_diagnostics(oss,a,5,2,1,1,2);
  const auto report=oss.str();
  t.expect(report.find("Raw spectral detections: 52") != std::string::npos,
           "Report gives raw peak counts");
  t.expect(report.find("Collected before cross-DM distillation: 5") != std::string::npos,
           "Report distinguishes cross-DM stage");
  t.expect(report.find("Nested associated nodes in final output: 2") != std::string::npos,
           "Report gives nested counts");
  t.expect(report.find("[END_POLYNOMIAL_DIAGNOSTICS]") != std::string::npos,
           "Report has a closing marker");
  return t.finish();
}
