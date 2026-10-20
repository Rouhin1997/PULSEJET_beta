// CPU-only smoke tests for the polynomial diagnostics CLI switch.
#include "test_support.hpp"
#include <utils/cmdline.hpp>
#include <string>
#include <vector>

using namespace pulsejet_test;

static bool parse_args(std::vector<std::string> tokens, CmdLineOptions& out) {
  std::vector<char*> argv;
  for (auto& token : tokens) argv.push_back(&token[0]);
  return read_cmdline_options(out, static_cast<int>(argv.size()), argv.data());
}

int main() {
  TestSuite t;
  CmdLineOptions off;
  t.expect(parse_args({"peasoup","-i","observation.fil","-P","templates.txt"}, off),
           "Polynomial CLI parses without diagnostic flag");
  t.expect(!off.candidate_diagnostics,
           "Diagnostics disabled by default");
  t.expect(off.polynomial_tb_file == "templates.txt",
           "Polynomial bank path is preserved");
  CmdLineOptions on;
  t.expect(parse_args({"peasoup","-i","observation.fil","-P","templates.txt",
                       "--candidate_diagnostics"}, on),
           "Polynomial CLI parses with diagnostic flag");
  t.expect(on.candidate_diagnostics,
           "Diagnostics explicitly enabled");
  return t.finish();
}
