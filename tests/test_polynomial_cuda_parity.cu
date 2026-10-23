// Stage B2: run the *compiled production* PULSEJET polynomial CUDA
// resampler against an independently derived long-double CPU reference.
//
// Deliberately do not include polynomial_timing.hpp or copy the device kernel.
// Link against /software/peasoup/obj/kernels.o in the pinned PULSEJET SIF.
// This tests a real GPU launch, nearest-even sampling and boundary padding.
#include <cuda_runtime.h>
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

void device_resample_acc_jerk(float*, float*, size_t,
                              double, double, double,
                              unsigned int, unsigned int);

namespace {
constexpr long double c_light = 299792458.0L;
constexpr std::size_t length = 32768;
constexpr double tsamp = 0.016;

void checked(cudaError_t result, const char* operation) {
    if (result != cudaSuccess)
        throw std::runtime_error(std::string(operation) + ": " +
                                 cudaGetErrorString(result));
}

struct Scenario {
    const char* name;
    double acceleration;
    double jerk;
};

struct CpuRead {
    float value;
    long double source;
    bool was_below;
    bool was_above;
    bool was_rounded_out;
};

CpuRead cpu_read(const std::vector<float>& input,
                 std::size_t i, double acceleration, double jerk) {
    // Independent arrival-time delay, evaluated in extended precision.
    const long double midpoint = static_cast<long double>(input.size()) / 2.0L;
    const long double tau = (static_cast<long double>(i) - midpoint) *
                             static_cast<long double>(tsamp);
    const long double arrival_delay =
        (0.5L * static_cast<long double>(acceleration) * tau * tau +
         (static_cast<long double>(jerk) / 6.0L) * tau * tau * tau) /
        c_light;
    const long double source =
        static_cast<long double>(i) + arrival_delay / static_cast<long double>(tsamp);
    if (source < 0.0L)
        return {0.0f, source, true, false, false};
    if (!(source < static_cast<long double>(input.size())))
        return {0.0f, source, false, true, false};

    // FE_TONEAREST (the default CPU rounding mode) is nearest, ties-to-even.
    // The production device uses __double2ull_rn with the same tie rule.
    const long double rounded = std::nearbyint(source);
    if (!(rounded >= 0.0L && rounded < static_cast<long double>(input.size())))
        return {0.0f, source, false, false, true};
    return {input[static_cast<std::size_t>(rounded)], source,
            false, false, false};
}

bool check_case(const Scenario& test, const std::vector<float>& input,
                float* d_in, float* d_out) {
    const std::size_t bytes = input.size() * sizeof(float);
    checked(cudaMemset(d_out, 0xCD, bytes), "cudaMemset output");
    device_resample_acc_jerk(d_in, d_out, input.size(), test.acceleration,
                             test.jerk, tsamp, 256u, 4096u);
    checked(cudaGetLastError(), "polynomial kernel launch");
    checked(cudaDeviceSynchronize(), "polynomial kernel synchronization");
    std::vector<float> actual(input.size(), -1.0f);
    checked(cudaMemcpy(actual.data(), d_out, bytes, cudaMemcpyDeviceToHost),
            "cudaMemcpy device to host");

    std::size_t mismatches = 0, below = 0, above = 0, rounded_out = 0;
    std::size_t ambiguous_rounding = 0;
    for (std::size_t i = 0; i < input.size(); ++i) {
        const CpuRead expected =
            cpu_read(input, i, test.acceleration, test.jerk);
        below += expected.was_below;
        above += expected.was_above;
        rounded_out += expected.was_rounded_out;
        // Extremely near a half-integer, host 80-bit and GPU double can
        // disagree at the final bit. Surface these cases; never ignore them.
        const long double near_half =
            std::fabs((expected.source - std::floor(expected.source)) - 0.5L);
        if (near_half < 1e-10L)
            ++ambiguous_rounding;
        if (actual[i] != expected.value) {
            if (mismatches < 8)
                std::cerr << std::setprecision(19)
                          << "  mismatch " << test.name << " at output " << i
                          << ": source=" << expected.source
                          << " CPU=" << expected.value
                          << " GPU=" << actual[i] << "\n";
            ++mismatches;
        }
    }
    std::cout << (mismatches == 0 ? "PASS " : "FAIL ") << test.name
              << " a=" << test.acceleration << " m/s^2"
              << " j=" << test.jerk << " m/s^3"
              << " samples=" << input.size()
              << " mismatch=" << mismatches
              << " below=" << below
              << " above=" << above
              << " rounded-out=" << rounded_out
              << " near-half=" << ambiguous_rounding << "\n";
    return mismatches == 0;
}
} // namespace

int main() {
    try {
        int count = 0;
        checked(cudaGetDeviceCount(&count), "cudaGetDeviceCount");
        if (count < 1)
            throw std::runtime_error("No CUDA GPU visible in container");
        checked(cudaSetDevice(0), "cudaSetDevice");
        cudaDeviceProp device{};
        checked(cudaGetDeviceProperties(&device, 0), "cudaGetDeviceProperties");
        std::cout << "PULSEJET production CUDA kernel parity test\n"
                  << "GPU: " << device.name << " (" << device.major
                  << "." << device.minor << "), detected=" << count << "\n"
                  << "CPU: independent long-double arrival-time calculation\n"
                  << "N=" << length << " tsamp=" << tsamp << " s\n";

        std::vector<float> input(length);
        // All positive, unique exactly representable floats so that zero
        // padding and single-sample indexing differences are observable.
        for (std::size_t i = 0; i < length; ++i)
            input[i] = static_cast<float>(i + 1);

        float* d_in = nullptr;
        float* d_out = nullptr;
        checked(cudaMalloc(reinterpret_cast<void**>(&d_in),
                           input.size() * sizeof(float)), "cudaMalloc input");
        checked(cudaMalloc(reinterpret_cast<void**>(&d_out),
                           input.size() * sizeof(float)), "cudaMalloc output");
        checked(cudaMemcpy(d_in, input.data(), input.size() * sizeof(float),
                           cudaMemcpyHostToDevice), "cudaMemcpy host to device");

        const std::vector<Scenario> cases = {
            {"zero_motion",       0.0,     0.0},
            {"positive_acc",   2500.0,     0.0},
            {"negative_acc",  -2500.0,     0.0},
            {"positive_jerk",     0.0,    70.0},
            {"negative_jerk",     0.0,   -70.0},
            {"mixed_pp",       2300.0,    40.0},
            {"mixed_nn",      -2300.0,   -40.0},
            {"mixed_pn",       2300.0,   -40.0},
            {"mixed_np",      -2300.0,    40.0},
            {"negative_pad", -18000.0,     0.0},
            {"positive_pad",  18000.0,     0.0},
            {"strong_jerk_p",     0.0,  1800.0},
            {"strong_jerk_n",     0.0, -1800.0},
        };
        unsigned fails = 0;
        std::size_t passes = 0;
        for (const auto& scenario : cases) {
            const bool ok = check_case(scenario, input, d_in, d_out);
            fails += !ok;
            passes += ok;
        }
        checked(cudaFree(d_out), "cudaFree output");
        checked(cudaFree(d_in), "cudaFree input");

        std::cout << "RESULT: " << passes << "/" << cases.size()
                  << " passed\n";
        return fails ? 1 : 0;
    } catch (const std::exception& exc) {
        std::cerr << "FATAL: " << exc.what() << "\n";
        return 2;
    }
}
