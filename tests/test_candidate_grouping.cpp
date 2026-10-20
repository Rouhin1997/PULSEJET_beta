// CPU-only tests for existing upstream Peasoup DM and harmonic distillers.
// No production grouping criteria are changed here.
#include "test_support.hpp"
#include <transforms/distiller.hpp>

#include <cmath>
#include <iostream>
#include <vector>

using namespace pulsejet_test;

int main() {
    TestSuite t;

    {
        std::vector<Candidate> input = {
            make_candidate(100.005f, 10.0f, 51.0f, 1, 20.0f, 0.001f),
            make_candidate(100.0f,   18.0f, 50.0f, 0, 20.0f, 0.001f)
        };
        DMDistiller distiller(1e-4f, true);
        auto result = distiller.distill(input);
        t.expect(result.size() == 1, "DM distiller groups close frequencies");
        t.expect(result.size() == 1 && result[0].count_assoc() == 1,
                 "DM distiller retains an associated detection");
    }

    {
        std::vector<Candidate> input = {
            make_candidate(100.0f, 18.0f, 50.0f, 0, 20.0f, 0.001f),
            make_candidate(105.0f, 10.0f, 51.0f, 1, 20.0f, 0.001f)
        };
        DMDistiller distiller(1e-4f, true);
        t.expect(distiller.distill(input).size() == 2,
                 "DM distiller keeps widely separated frequencies");
    }

    {
        // This is intentional characterization: DM itself is not part of the
        // matching predicate in the existing upstream DMDistiller.
        std::vector<Candidate> input = {
            make_candidate(100.0f, 18.0f, 50.0f, 0, 20.0f, 0.001f),
            make_candidate(100.0f, 10.0f, 80.0f, 1, 20.0f, 0.001f)
        };
        DMDistiller distiller(1e-4f, true);
        t.expect(distiller.distill(input).size() == 1,
                 "CHARACTERIZATION: DM distiller matches frequency regardless of DM distance");
    }

    {
        std::vector<Candidate> input = {
            make_candidate(100.0f, 18.0f, 50.0f, 0, 20.0f, 0.001f),
            make_candidate(200.0f, 12.0f, 50.0f, 0, 20.0f, 0.001f)
        };
        HarmonicDistiller distiller(1e-4f, 16, true);
        auto result = distiller.distill(input);
        t.expect(result.size() == 1, "Harmonic distiller groups 2:1 frequencies");
        t.expect(result.size() == 1 && result[0].count_assoc() == 1,
                 "Harmonic association is retained");
    }

    {
        std::vector<Candidate> input = {
            make_candidate(100.0f, 18.0f, 50.0f, 0, 20.0f, 0.001f),
            make_candidate(103.0f, 12.0f, 50.0f, 0, 20.0f, 0.001f)
        };
        HarmonicDistiller distiller(1e-4f, 16, true);
        t.expect(distiller.distill(input).size() == 2,
                 "Harmonic distiller preserves unrelated frequencies");
    }

    {
        // Diagnostic only: A and C are outside each other's tolerance, while
        // the weaker B falls inside both windows. Existing BaseDistiller-derived
        // matchers may associate B with both representatives.
        std::vector<Candidate> input = {
            make_candidate(100.0f,     20.0f, 50.0f, 0, 20.0f, 0.001f), // A
            make_candidate(100.0015f,  18.0f, 50.0f, 0, 20.0f, 0.001f), // C
            make_candidate(100.00075f, 12.0f, 50.0f, 0, 20.0f, 0.001f) // B
        };
        DMDistiller distiller(1e-5f, true);
        auto result = distiller.distill(input);
        t.expect(result.size() == 2,
                 "Overlap fixture produces two representative frequency groups");

        int memberships = 0;
        for (const auto& representative : result) {
            for (const auto& associated : representative.assoc) {
                if (near(associated.freq, 100.00075f, 2e-5f)) {
                    ++memberships;
                }
            }
        }
        std::cout << "[DIAGNOSTIC] Middle candidate is associated "
                  << memberships << " time(s) across representatives.\n"
                  << "             Duplicate associations are recorded, not fixed, "
                     "by this baseline suite.\n";
    }

    return t.finish();
}
