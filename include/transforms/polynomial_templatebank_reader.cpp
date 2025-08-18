#pragma once
#include <vector>
#include <string>
#include <sstream>
#include <fstream>
#include <iterator>
#include <stdexcept>
#include <iostream>
#include <map>
#include <cctype>

// Reads polynomial template banks with a header like:
// ---------------------------------------------
// Maximum acceleration used to generate template xxx.xx m/s^2
// Maximum Jerk used to generate template yy.yyyy m/s^3
// ---------------------------------------------
// acc m/s^2       jerk m/s^3
// 1.343           0.001
// 45.234          1.345
// ...

class Polynomial_TemplateBank_Reader {
private:
  std::vector<double> acc;   // acceleration values
  std::vector<double> jerk;   // jerk values
  int columns = 0;

  // store parsed header lines here
  // Keys used: "Maximum acceleration used to generate template", "Maximum Jerk used to generate template"
  std::map<std::string, std::string> metadata;

  static bool is_comment(const std::string& line) {
    // Treat dashed separators and empty lines as comments/ignorable.
    if (line.empty()) return true;
    for (char c : line) {
      if (!std::isspace(static_cast<unsigned char>(c)) && c != '-') return false;
    }
    return true; // line was only whitespace and/or dashes
  }

  static std::vector<std::string> split(const std::string& s) {
    std::stringstream ss(s);
    return {std::istream_iterator<std::string>(ss), std::istream_iterator<std::string>()};
  }

  static std::string trim(const std::string& s) {
    size_t start = s.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return "";
    size_t end = s.find_last_not_of(" \t\r\n");
    return s.substr(start, end - start + 1);
  }

  static std::string to_lower(std::string s) {
    for (auto& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return s;
  }

  static bool token_is_number(const std::string& t) {
    // Simple numeric test by trying stod
    try { (void)std::stod(t); return true; }
    catch (...) { return false; }
  }

  // Capture "KEY ... number ... (units)" style header lines into metadata.
  // Returns true if the line matched a known header key.
  bool try_parse_header_line(const std::string& line) {
    const std::string l = to_lower(trim(line));
    const std::string key1_l = "maximum acceleration used to generate template";
    const std::string key2_l = "maximum jerk used to generate template";

    auto starts_with = [](const std::string& s, const std::string& prefix){
      return s.size() >= prefix.size() && std::equal(prefix.begin(), prefix.end(), s.begin());
    };

    if (starts_with(l, key1_l)) {
      // store the full original (trimmed) line as value
      metadata["Maximum acceleration used to generate template"] = trim(line.substr(0));
      return true;
    }
    if (starts_with(l, key2_l)) {
      metadata["Maximum Jerk used to generate template"] = trim(line.substr(0));
      return true;
    }
    return false;
  }

public:
  Polynomial_TemplateBank_Reader(const std::string& filename) { load(filename); }

  void load(const std::string& filename) {
    std::ifstream in(filename);
    // Keep same pattern as your Keplerian reader; if ErrorChecker exists, this will compile.
    // Otherwise, the explicit check below throws a standard error.
    #ifdef ErrorCheckerAvailable
    ErrorChecker::check_file_error(in, filename);
    #endif
    if (!in) {
      throw std::runtime_error("Failed to open template bank file: " + filename);
    }

    std::string line;
    while (std::getline(in, line)) {
      const std::string t = trim(line);
      if (t.empty() || is_comment(t)) continue;

      // Capture the two header lines if present
      if (try_parse_header_line(t)) continue;

      // Skip a potential column header like "a j" (non-numeric tokens)
      {
        auto tokens = split(t);
        if (tokens.size() == 2 && !(token_is_number(tokens[0]) && token_is_number(tokens[1]))) {
          // Looks like a column header; ignore
          continue;
        }
      }

      // Parse data rows (expect exactly two numeric columns: a, j)
      auto tokens = split(t);
      if (columns == 0) columns = static_cast<int>(tokens.size());

      if (tokens.size() == 2 && token_is_number(tokens[0]) && token_is_number(tokens[1])) {
        acc.push_back(std::stod(tokens[0]));
        jerk.push_back(std::stod(tokens[1]));
      } else {
        // Ignore any stray non-data lines gracefully, but if it's clearly malformed numeric data, throw.
        bool any_numeric = false;
        for (const auto& tok : tokens) any_numeric = any_numeric || token_is_number(tok);
        if (any_numeric) {
          throw std::runtime_error(
            "Polynomial_TemplateBank_Reader: Invalid data line with " +
            std::to_string(tokens.size()) + " tokens. Expected exactly 2 numeric columns (a, j). Line: " + t
          );
        }
        // else: benign non-data text; continue
      }
    }
  }

  const std::vector<double>& get_acc() const { return acc; }
  const std::vector<double>& get_jerk() const { return jerk; }
  int get_num_columns() const { return columns; }
  const std::map<std::string, std::string>& get_metadata() const { return metadata; }
};
