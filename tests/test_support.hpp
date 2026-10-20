#pragma once

#include <data_types/candidates.hpp>

#include <cmath>
#include <iostream>
#include <string>

namespace pulsejet_test {

struct TestSuite {
    int checks = 0;
    int failures = 0;

    void expect(bool condition, const std::string& description) {
        ++checks;
        if (condition) {
            std::cout << "[PASS] " << description << '\n';
        } else {
            ++failures;
            std::cerr << "[FAIL] " << description << '\n';
        }
    }

    int finish() const {
        std::cout << "\n" << (checks - failures) << "/" << checks
                  << " assertions passed.\n";
        return failures == 0 ? 0 : 1;
    }
};

inline Candidate make_candidate(float freq, float snr, float dm,
                                int dm_idx, float acc, float jerk, int nh = 0) {
    return Candidate(dm, dm_idx, acc, jerk,
                     0.0, 0.0, 0.0, 0.0, 0.0, nh, snr, freq);
}

inline bool near(float actual, float expected, float tolerance = 1e-4f) {
    return std::fabs(actual - expected) <= tolerance;
}

} // namespace pulsejet_test
