// CPU-only verification of the polynomial template-bank reader's behaviour.
#include "test_support.hpp"
#include <transforms/polynomial_templatebank_reader.hpp>

#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <functional>
#include <string>

using namespace pulsejet_test;

int main() {
  TestSuite t;
  const auto file = std::filesystem::temp_directory_path() /
      ("pulsejet_polybank_" + std::to_string(
         std::chrono::high_resolution_clock::now().time_since_epoch().count()) + ".txt");

  auto put = [&](const std::string& text) {
    std::ofstream out(file);
    out << text;
    out.close();
  };
  auto reject = [&](const std::string& source) {
    put(source);
    try {
      Polynomial_TemplateBank_Reader reader(file.string());
      return false;
    } catch (const std::runtime_error&) {
      return true;
    }
  };

  put("------------------------------------------------\n"
      "Maximum acceleration used to generate template 500 m/s^2\n"
      "Maximum Jerk used to generate template 0.05 m/s^3\n"
      "acc m/s^2       jerk m/s^3\n"
      "0.0 0.0\n-20.125 0.00000234123456789\n20 0.0001\n");
  {
    Polynomial_TemplateBank_Reader bank(file.string());
    t.expect(bank.get_acc().size() == 3 && bank.get_jerk().size() == 3,
             "Valid bank preserves aligned acceleration/jerk columns");
    t.expect(bank.get_num_columns() == 2,
             "Column count is determined by numeric data, not descriptive headers");
    t.expect(std::abs(bank.get_jerk()[1]-0.00000234123456789) < 1e-19,
             "Bank retains jerk numerical precision in double");
    t.expect(bank.get_metadata().count("Maximum acceleration used to generate template") == 1,
             "Existing metadata header is preserved");
  }
  t.expect(reject("acc m/s^2 jerk m/s^3\n"), "Empty/header-only bank is rejected");
  t.expect(reject("nan 0.01\n"), "Non-finite acceleration is rejected");
  t.expect(reject("inf 0.01\n"), "Infinite acceleration is rejected");
  t.expect(reject("100.0garbage 0.001\n"), "Partially numeric malformed row is rejected");
  t.expect(reject("100.0 0.001 300.0\n"), "Three-column numeric row is rejected");
  t.expect(reject("1e40 0.001\n"), "Candidate-unrepresentable acceleration is rejected");
  std::filesystem::remove(file);
  return t.finish();
}
