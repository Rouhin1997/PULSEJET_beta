// Deterministic, CPU-only, labelled candidate-population experiments.
// Production distillers and Candidate classes are used without modification.
// This tests grouping of detected candidates, NOT simulated filterbank voltages
// or recovery sensitivity of the CUDA resampler.
#include "test_support.hpp"
#include <transforms/distiller.hpp>

#include <cmath>
#include <iomanip>
#include <iostream>
#include <map>
#include <set>
#include <string>
#include <vector>

using namespace pulsejet_test;

namespace {

constexpr float FREQ_TOL = 1e-4f;
constexpr double T_OBS = 1800.0;  // seconds; only used by the Doppler distiller

struct Population {
    std::vector<Candidate> candidates;
    std::map<float, int> signal_by_snr;

    void add(int signal_id, float freq, float dm, int dm_idx,
             float acc, float jerk, int harmonic_number = 0) {
        // Exactly representable increments avoid ambiguous event identities
        // after the candidate is copied into an association.
        const float snr = 60.0f - 0.03125f *
                           static_cast<float>(signal_by_snr.size());
        candidates.push_back(make_candidate(freq, snr, dm, dm_idx,
                                            acc, jerk, harmonic_number));
        signal_by_snr.emplace(snr, signal_id);
    }
};

struct Metrics {
    std::size_t representatives = 0;
    std::size_t memberships = 0;      // includes representatives
    std::size_t unique_events = 0;    // distinct candidate identities found
    std::size_t duplicate_memberships = 0;
    std::size_t mixed_groups = 0;     // groups containing >1 truth signal
    std::size_t representative_sources = 0;
};

void record_members(const Candidate& candidate,
                    const std::map<float, int>& labels,
                    std::map<float, int>& membership_counts,
                    std::set<int>& group_sources) {
    const auto label = labels.find(candidate.snr);
    if (label == labels.end()) {
        std::cerr << "[ERROR] Unknown synthetic candidate ID\n";
        std::exit(2);
    }
    ++membership_counts[candidate.snr];
    group_sources.insert(label->second);
    for (const auto& associated : candidate.assoc) {
        record_members(associated, labels, membership_counts, group_sources);
    }
}

Metrics measure(const std::vector<Candidate>& output,
                const std::map<float, int>& labels) {
    Metrics m;
    m.representatives = output.size();
    std::map<float, int> counts;
    std::set<int> representative_sources;
    for (const auto& representative : output) {
        representative_sources.insert(labels.at(representative.snr));
        std::set<int> group_sources;
        record_members(representative, labels, counts, group_sources);
        if (group_sources.size() > 1) ++m.mixed_groups;
    }
    m.representative_sources = representative_sources.size();
    m.unique_events = counts.size();
    for (const auto& pair : counts) {
        m.memberships += static_cast<std::size_t>(pair.second);
        if (pair.second > 1) {
            m.duplicate_memberships += static_cast<std::size_t>(pair.second - 1);
        }
    }
    return m;
}

void report(const std::string& scenario, const std::string& stage,
            std::size_t input_count, const Metrics& m) {
    std::cout << "[POPULATION] "
              << std::left << std::setw(26) << scenario
              << " stage=" << std::setw(17) << stage
              << " input=" << std::setw(4) << input_count
              << " reps=" << std::setw(4) << m.representatives
              << " assoc=" << std::setw(4)
              << (m.memberships - m.representatives)
              << " unique_events=" << std::setw(4) << m.unique_events
              << " repeated=" << std::setw(3) << m.duplicate_memberships
              << " mixed=" << m.mixed_groups
              << " rep_sources=" << m.representative_sources << '\n';
}

std::vector<Candidate> run_dm(std::vector<Candidate> cands) {
    DMDistiller distiller(FREQ_TOL, true);
    return distiller.distill(cands);
}
std::vector<Candidate> run_poly(std::vector<Candidate> cands) {
    // Relative parameter tolerances chosen for comparison, not calibrated.
    Template_Bank_Polynomial_Distiller distiller(FREQ_TOL, 0.01f, 0.02f, true);
    return distiller.distill(cands);
}
std::vector<Candidate> run_doppler(std::vector<Candidate> cands) {
    Template_Bank_Polynomial_DopplerDistiller distiller(T_OBS, FREQ_TOL, true);
    return distiller.distill(cands);
}

} // namespace

int main() {
    TestSuite t;

    // SCENARIO 1: 40 DMs, one acceleration/jerk template, three related
    // harmonic peaks per DM. Mirrors the ordering of the polynomial path:
    // per-template HarmonicDistiller(keep_related=false), per-DM polynomial
    // Doppler distillation, then cross-DM and final harmonic distillation.
    {
        Population p;
        std::vector<Candidate> after_harmonic;
        std::vector<Candidate> after_polynomial;
        for (int dm_idx = 0; dm_idx < 40; ++dm_idx) {
            std::vector<Candidate> trial;
            const float f = 100.0f + 0.002f *
                           static_cast<float>(dm_idx % 5 - 2);
            for (int harmonic = 1; harmonic <= 3; ++harmonic) {
                p.add(1, f * harmonic, 50.0f + 0.25f * dm_idx,
                      dm_idx, 20.0f, 0.002f);
                trial.push_back(p.candidates.back());
            }
            HarmonicDistiller harmonics(FREQ_TOL, 16, false);
            auto locally_grouped = harmonics.distill(trial);
            after_harmonic.insert(after_harmonic.end(),
                                  locally_grouped.begin(), locally_grouped.end());
            auto per_dm = run_doppler(locally_grouped);
            after_polynomial.insert(after_polynomial.end(),
                                    per_dm.begin(), per_dm.end());
        }

        auto across_dm = run_dm(after_polynomial);
        HarmonicDistiller final_harmonic(FREQ_TOL, 16, true, false);
        auto final = final_harmonic.distill(across_dm);
        report("one-template / 40 DMs", "per-template harm",
               p.candidates.size(), measure(after_harmonic, p.signal_by_snr));
        report("one-template / 40 DMs", "per-DM poly",
               after_harmonic.size(), measure(after_polynomial, p.signal_by_snr));
        report("one-template / 40 DMs", "cross-DM",
               after_polynomial.size(), measure(across_dm, p.signal_by_snr));
        report("one-template / 40 DMs", "final harmonic",
               across_dm.size(), measure(final, p.signal_by_snr));

        t.expect(p.candidates.size() == 120,
                 "Fixture generates 40 DMs x 3 harmonics");
        t.expect(after_harmonic.size() == 40,
                 "Per-template harmonic stage produces one representative per DM");
        t.expect(after_polynomial.size() == 40,
                 "One template gives no further per-DM polynomial reduction here");
        t.expect(final.size() == 1,
                 "Close cross-DM detections of one signal reduce to one representative");
        t.expect(measure(final, p.signal_by_snr).mixed_groups == 0,
                 "Single-source pipeline-like fixture has no false merges");
    }

    // SCENARIO 2: frequency estimates span >4 default tolerance windows
    // across DMs. All input events are assigned the same source label. The
    // synthetic scatter is a controlled stress test, not a claim about
    // realistic distributions of measured Fourier errors.
    {
        Population p;
        for (int i = 0; i < 40; ++i) {
            const float drift = -0.022f + 0.044f * (static_cast<float>(i) / 39.0f);
            p.add(1, 100.0f + drift, 50.0f + 0.1f * i,
                  i, 20.0f, 0.002f);
        }
        auto grouped = run_dm(p.candidates);
        const auto m = measure(grouped, p.signal_by_snr);
        report("one-source / freq scatter", "cross-DM",
               p.candidates.size(), m);
        t.expect(grouped.size() > 1,
                 "CHARACTERIZATION: one source with wide frequency scatter survives in multiple groups");
        t.expect(m.mixed_groups == 0, "One-source scatter cannot falsely merge distinct labels");
    }

    // SCENARIO 3: two distinct signals with resolvable spin frequencies
    // separated by 0.005 Hz, which is within the 0.01-Hz default window at
    // 100 Hz. The 1800-s example observation has 1/T=0.000556 Hz.
    {
        Population p;
        for (int i = 0; i < 20; ++i) {
            const float offset = 0.00005f * (i % 3 - 1);
            p.add(1, 100.000f + offset, 50.0f + 0.1f * i,
                  i, 20.0f, 0.002f);
            p.add(2, 100.005f + offset, 50.0f + 0.1f * i,
                  i, 20.0f, 0.002f);
        }
        auto grouped = run_dm(p.candidates);
        auto m = measure(grouped, p.signal_by_snr);
        report("two-close-source DMs", "cross-DM",
               p.candidates.size(), m);
        t.expect(m.mixed_groups > 0,
                 "CHARACTERIZATION: DM-only frequency matching can merge two distinct labels");
        t.expect(m.representative_sources < 2,
                 "CHARACTERIZATION: at least one source loses its independent representative");
    }

    // SCENARIO 4: one astrophysical signal searched at neighbouring
    // acceleration/jerk templates near zero, within a single DM.
    {
        Population p;
        for (int i = 0; i < 11; ++i) {
            const float delta = static_cast<float>(i - 5);
            p.add(1, 100.0f + 0.0001f * i, 50.0f, 0,
                  0.001f * delta, 0.000001f * delta);
        }
        auto poly = run_poly(p.candidates);
        auto doppler = run_doppler(p.candidates);
        report("one-source / near-zero", "user polynomial",
               p.candidates.size(), measure(poly, p.signal_by_snr));
        report("one-source / near-zero", "current Doppler",
               p.candidates.size(), measure(doppler, p.signal_by_snr));
        t.expect(poly.size() > 1,
                 "CHARACTERIZATION: relative acceleration/jerk tolerances leave several neighbouring templates");
        t.expect(doppler.size() == 1,
                 "Current Doppler criterion consolidates this near-zero fixture");
    }

    // SCENARIO 5: independent sources recovered at different trial motion
    // parameters but identical nominal frequency. This is an adversarial
    // false-merge test, not a frequency-resolution simulation.
    {
        Population p;
        p.add(1, 100.0f, 50.0f, 0, 0.0f,   0.0f);
        p.add(2, 100.0f, 50.0f, 0, 100.0f, 0.001f);
        auto poly = run_poly(p.candidates);
        auto doppler = run_doppler(p.candidates);
        const auto mp = measure(poly, p.signal_by_snr);
        const auto md = measure(doppler, p.signal_by_snr);
        report("two-source / same spin", "user polynomial",
               p.candidates.size(), mp);
        report("two-source / same spin", "current Doppler",
               p.candidates.size(), md);
        t.expect(mp.representative_sources == 2 && mp.mixed_groups == 0,
                 "Parameter-aware polynomial rule separates this two-source fixture");
        t.expect(md.mixed_groups == 1,
                 "CHARACTERIZATION: Doppler frequency-envelope rule merges this fixture");
    }

    // SCENARIO 6: the cross-DM frequency tolerance has no Tobs argument.
    // Compare one-bin shifts for two hypothetical observation durations.
    {
        for (const double seconds : {30.0, 3600.0}) {
            Population p;
            p.add(1, 100.0f, 50.0f, 0, 20.0f, 0.002f);
            p.add(1, static_cast<float>(100.0 + 1.0 / seconds),
                  50.1f, 1, 20.0f, 0.002f);
            auto grouped = run_dm(p.candidates);
            report(seconds < 100.0 ? "one-bin / Tobs=30s" : "one-bin / Tobs=3600s",
                   "cross-DM", p.candidates.size(),
                   measure(grouped, p.signal_by_snr));
            t.expect(grouped.size() == (seconds < 100.0 ? 2u : 1u),
                     seconds < 100.0 ?
                     "CHARACTERIZATION: 30-s one-bin shift exceeds relative frequency window" :
                     "CHARACTERIZATION: 3600-s one-bin shift fits relative frequency window");
        }
    }

    // SCENARIO 7: two well-separated pulsars should remain distinct.
    {
        Population p;
        for (int dm_idx = 0; dm_idx < 20; ++dm_idx) {
            p.add(1, 100.0f, 50.0f + 0.1f * dm_idx,
                  dm_idx, 20.0f, 0.002f);
            p.add(2, 103.0f, 50.0f + 0.1f * dm_idx,
                  dm_idx, 20.0f, 0.002f);
        }
        auto grouped = run_dm(p.candidates);
        auto m = measure(grouped, p.signal_by_snr);
        report("two-well-separated", "cross-DM",
               p.candidates.size(), m);
        t.expect(grouped.size() == 2,
                 "Widely separated frequencies retain two independent representatives");
        t.expect(m.mixed_groups == 0 && m.representative_sources == 2,
                 "Widely separated sources do not falsely merge");
    }

    return t.finish();
}
