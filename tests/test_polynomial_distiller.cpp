// CPU-only characterization tests for the existing polynomial distiller.
// These tests deliberately use the production C++ header without modifying it.
#include "test_support.hpp"
#include <transforms/distiller.hpp>

#include <vector>

using namespace pulsejet_test;

int main() {
    TestSuite t;

    {
        std::vector<Candidate> input;
        Template_Bank_Polynomial_Distiller distiller(1e-4f, 0.01f, 0.02f);
        const auto result = distiller.distill(input);
        t.expect(result.empty(), "Empty input produces no candidates");
    }

    {
        std::vector<Candidate> input = {
            make_candidate(100.0f, 15.0f, 50.0f, 0, 20.0f, 0.002f)
        };
        Template_Bank_Polynomial_Distiller distiller(1e-4f, 0.01f, 0.02f);
        const auto result = distiller.distill(input);
        t.expect(result.size() == 1, "Single candidate is preserved");
        t.expect(result.size() == 1 && result[0].count_assoc() == 0,
                 "Single candidate has no associations");
    }

    {
        // Two nearby detections with compatible acceleration/jerk. Distiller
        // itself does not compare DM; this is tested independently of the
        // pipeline's current per-DM invocation.
        std::vector<Candidate> input = {
            make_candidate(100.003f, 12.0f, 50.5f, 1, 20.1f, 0.00201f),
            make_candidate(100.0f,   15.0f, 50.0f, 0, 20.0f, 0.00200f)
        };
        Template_Bank_Polynomial_Distiller distiller(1e-4f, 0.01f, 0.02f);
        const auto result = distiller.distill(input);
        t.expect(result.size() == 1, "Nearby parameter-matched detections collapse");
        t.expect(result.size() == 1 && near(result[0].snr, 15.0f),
                 "Highest-S/N detection is retained as representative");
        t.expect(result.size() == 1 && result[0].count_assoc() == 1,
                 "Weaker detection remains associated with representative");
        t.expect(result.size() == 1 && result[0].assoc.size() == 1 &&
                     near(result[0].assoc[0].dm, 50.5f),
                 "Association retains the weaker detection's DM");
    }

    {
        std::vector<Candidate> input = {
            make_candidate(100.0f, 15.0f, 50.0f, 0, 20.0f, 0.002f),
            make_candidate(105.0f, 12.0f, 50.0f, 0, 20.0f, 0.002f)
        };
        Template_Bank_Polynomial_Distiller distiller(1e-4f, 0.01f, 0.02f);
        t.expect(distiller.distill(input).size() == 2,
                 "Distinct frequencies remain separate");
    }

    {
        std::vector<Candidate> input = {
            make_candidate(100.0f,   15.0f, 50.0f, 0, 20.0f, 0.002f),
            make_candidate(100.003f, 12.0f, 50.0f, 0, 21.0f, 0.002f)
        };
        Template_Bank_Polynomial_Distiller distiller(1e-4f, 0.01f, 0.02f);
        t.expect(distiller.distill(input).size() == 2,
                 "Acceleration difference outside relative tolerance remains separate");
    }

    {
        std::vector<Candidate> input = {
            make_candidate(100.0f,   15.0f, 50.0f, 0, 20.0f, 0.0020f),
            make_candidate(100.003f, 12.0f, 50.0f, 0, 20.0f, 0.0022f)
        };
        Template_Bank_Polynomial_Distiller distiller(1e-4f, 0.01f, 0.02f);
        t.expect(distiller.distill(input).size() == 2,
                 "Jerk difference outside relative tolerance remains separate");
    }

    {
        // Characterize the existing near-zero acceleration rule. This is not
        // an endorsement of the physical matching threshold.
        std::vector<Candidate> input = {
            make_candidate(100.0f,   15.0f, 50.0f, 0, 0.0f,   0.002f),
            make_candidate(100.003f, 12.0f, 50.0f, 0, 0.001f, 0.002f)
        };
        Template_Bank_Polynomial_Distiller distiller(1e-4f, 0.01f, 0.02f);
        t.expect(distiller.distill(input).size() == 2,
                 "CHARACTERIZATION: near-zero acceleration has a very narrow window");
    }

    {
        std::vector<Candidate> input = {
            make_candidate(100.0f,   15.0f, 50.0f, 0, 20.0f, 0.0f),
            make_candidate(100.003f, 12.0f, 50.0f, 0, 20.0f, 1e-5f)
        };
        Template_Bank_Polynomial_Distiller distiller(1e-4f, 0.01f, 0.02f);
        t.expect(distiller.distill(input).size() == 2,
                 "CHARACTERIZATION: near-zero jerk has a very narrow window");
    }

    return t.finish();
}
