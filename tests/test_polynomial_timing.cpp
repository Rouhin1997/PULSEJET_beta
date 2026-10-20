// Phase A: independent physical timing and synthetic periodic-signal recovery.
// No CUDA, dedispersion, PSRFITS, or filterbank files are required.
#include "test_support.hpp"
#include <transforms/polynomial_timing.hpp>

#include <algorithm>
#include <cmath>
#include <complex>
#include <cstddef>
#include <iostream>
#include <vector>

using namespace pulsejet_test;
namespace poly = pulsejet::polynomial;
namespace {
constexpr double pi = 3.14159265358979323846;
constexpr std::size_t N = 16384;
constexpr double dt = 0.02;
constexpr double spin_hz = 9.0;
constexpr double mid = 0.5 * static_cast<double>(N) * dt;
constexpr double c = 299792458.0;

// Physically independent injector: invert the arrival-time equation for
// emission time, then evaluate the intrinsic monochromatic signal there.
// This does not call PULSEJET's source-index function.
double emission_at_arrival(double arrival, double acc, double jerk) {
    double emission = arrival;
    for (int iter = 0; iter < 9; ++iter) {
        const double tau = emission - mid;
        const double delay = (acc * tau * tau / 2.0 +
                              jerk * tau * tau * tau / 6.0) / c;
        const double derivative =
            1.0 + (acc * tau + jerk * tau * tau / 2.0) / c;
        emission -= (emission + delay - arrival) / derivative;
    }
    return emission;
}

std::vector<double> injected_stream(double acc, double jerk) {
    std::vector<double> data(N);
    for (std::size_t i = 0; i < N; ++i) {
        const double arrival = static_cast<double>(i) * dt;
        data[i] = std::sin(2.0 * pi * spin_hz *
                           emission_at_arrival(arrival, acc, jerk));
    }
    return data;
}

// Historical polynomial kernel formula, copied only for baseline comparison.
double historical_index(double x, double a, double j) {
    const double dx = x - 0.5 * static_cast<double>(N);
    return x + (a * dt / (2.0 * c)) * x * dx +
           (j * dt * dt / (6.0 * c)) * dx * dx * dx;
}

enum class SampleMode { raw, corrected_linear, corrected_nearest, historical };

double coherence(const std::vector<double>& observed,
                 double a, double j, SampleMode mode) {
    std::complex<double> phasor(0.0, 0.0);
    std::size_t valid = 0;
    for (std::size_t i = 0; i < N; ++i) {
        const double x = static_cast<double>(i);
        double where = x;
        if (mode == SampleMode::historical) {
            where = historical_index(x, a, j);
        } else if (mode != SampleMode::raw) {
            where = poly::input_sample_index(x, static_cast<double>(N), dt,
                                             a, j);
        }
        if (where < 0.0 || where >= static_cast<double>(N - 1)) continue;
        double val = 0.0;
        if (mode == SampleMode::corrected_nearest || mode == SampleMode::historical) {
            const auto read_index = static_cast<std::size_t>(std::nearbyint(where));
            if (read_index >= N) continue;
            val = observed[read_index];
        } else {
            const auto left = static_cast<std::size_t>(where);
            const double frac = where - static_cast<double>(left);
            val = observed[left] * (1.0 - frac) +
                  observed[left + 1] * frac;
        }
        const double phase = 2.0 * pi * spin_hz * x * dt;
        phasor += val * std::complex<double>(std::cos(phase), -std::sin(phase));
        ++valid;
    }
    return valid ? 2.0 * std::abs(phasor) / static_cast<double>(valid) : 0.0;
}
}

int main() {
    TestSuite t;
    const double length = static_cast<double>(N);
    {
        for (const double x : {0.0, length / 4.0, length / 2.0,
                               3.0 * length / 4.0, length - 1.0}) {
            t.expect(std::abs(poly::input_sample_index(x, length, dt, 0.0, 0.0) - x) < 1e-10,
                     "Zero acceleration and jerk give identity mapping");
        }
        t.expect(std::abs(poly::input_sample_index(length / 2.0, length, dt,
                      2500.0, 40.0) - length / 2.0) < 1e-10,
                 "Reference epoch is the observation midpoint");
        const double x = length * 0.75;
        const double tau = (x - length / 2.0) * dt;
        const double expected = x + (0.5 * 2500.0 * tau * tau +
                            (40.0 / 6.0) * tau * tau * tau) / (c * dt);
        t.expect(std::abs(poly::input_sample_index(x, length, dt, 2500.0, 40.0)
                          - expected) < 1e-9,
                 "Sample-index formula matches independent time-delay formula");
        t.expect(std::abs(poly::arrival_time(mid, mid, 2500.0, 40.0) - mid) < 1e-10,
                 "Midpoint arrival and emission times coincide");
        t.expect(std::abs(poly::arrival_time_derivative(mid, mid, 2500.0, 40.0) - 1.0) < 1e-12,
                 "Midpoint reference velocity is zero");
        const double eps=1e-3;
        const double x_time=mid + 33.0;
        const double numeric=(poly::arrival_time(x_time+eps,mid,2500.0,40.0)
                            -poly::arrival_time(x_time-eps,mid,2500.0,40.0))
                           /(2.0*eps);
        t.expect(std::abs(numeric - poly::arrival_time_derivative(x_time,mid,2500.0,40.0)) < 1e-9,
                 "Analytical arrival-time derivative matches finite difference");
    }
    {
        // The original Peasoup acceleration-II map differs from our
        // midpoint-anchored acceleration-only map by a constant delay;
        // its frequency drift therefore agrees with the chosen convention.
        const double a = 2500.0;
        const double i1 = 0.25 * length, i2 = 0.75 * length;
        const auto legacy = [&](double x) {
            return x + (a * dt / (2.0*c)) * x * (x-length);
        };
        const double first = poly::input_sample_index(i1, length, dt, a, 0) - legacy(i1);
        const double second = poly::input_sample_index(i2, length, dt, a, 0) - legacy(i2);
        t.expect(std::abs(first - second) < 1e-9,
                 "Zero-jerk polynomial acceleration agrees with legacy Peasoup drift up to a constant");
        const double old_correction = historical_index(i2,a,0.0)-i2;
        const double new_correction = poly::input_sample_index(i2,length,dt,a,0.0)-i2;
        t.expect(std::abs(old_correction - new_correction) > 1.0,
                 "CHARACTERIZATION: historical polynomial acceleration formula differs materially");
    }
    {
        // Correct an independently injected sinusoid by sampling the
        // simulated observed time series at arrival_time(t_em).
        for (const auto& params : std::vector<std::pair<double,double>>{
                {2500.0,0.0}, {0.0,40.0}, {2500.0,40.0},
                {-2500.0,-40.0}, {1000.0,-50.0}}) {
            const double a=params.first, j=params.second;
            const auto stream=injected_stream(a,j);
            const double original=coherence(stream,a,j,SampleMode::raw);
            const double linear=coherence(stream,a,j,SampleMode::corrected_linear);
            const double nearest=coherence(stream,a,j,SampleMode::corrected_nearest);
            std::cout << "[TIMING] a=" << a << " j=" << j
                      << " raw=" << original << " corrected_linear=" << linear
                      << " corrected_nearest=" << nearest << '\n';
            t.expect(linear > 0.88, "Physical reference correction recovers injected Fourier coherence");
            t.expect(nearest > 0.72, "Nearest-neighbour approximation retains substantial coherence");
            t.expect(linear > original + 0.1, "Correct correction improves over uncorrected data");
        }
        const auto stream=injected_stream(2500.0,40.0);
        const auto correct=coherence(stream,2500.0,40.0,SampleMode::corrected_nearest);
        const auto old=coherence(stream,2500.0,40.0,SampleMode::historical);
        std::cout << "[TIMING] historical combined a+j coherence=" << old
                  << " corrected_nearest=" << correct << '\n';
        t.expect(correct > old + 0.5,
                 "Historical acceleration index does not recover the defined midpoint physical model");
    }
    {
        const auto stream=injected_stream(0,0);
        t.expect(coherence(stream,0,0,SampleMode::corrected_nearest) > 0.98,
                 "Zero-motion signal is preserved");
        const double positive=poly::input_sample_index(length*0.75,length,dt,2500.0,0);
        const double negative=poly::input_sample_index(length*0.75,length,dt,-2500.0,0);
        t.expect(positive > length*0.75 && negative < length*0.75,
                 "Acceleration sign reverses quadratic mapping direction");
        t.expect(poly::input_sample_index(length,length,dt,2500.0,40.0) > length,
                 "Out-of-range end samples need explicit zero padding");
    }
    return t.finish();
}
