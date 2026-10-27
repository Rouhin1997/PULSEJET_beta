#pragma once
// Pure C++17 frequency-to-bin conversion for the PeakFinder GPU front end.
//
// Peasoup searches both the un-summed Fourier spectrum (nh=0) and
// harmonic-summed spectra with nh=1,2,... . The harmonic sum at level nh
// represents fundamental frequencies f = bin * bin_width / 2^nh.
//
// Convention: start is INCLUSIVE; stop is EXCLUSIVE. Frequency limits
// min_freq_hz and max_freq_hz are INCLUSIVE, so use ceil for the first
// acceptable bin and floor(max)+1 for the last acceptable bin.
//
// All bounds are clamped BEFORE conversion to an int. Empty intersections
// with a harmonic spectrum are valid: the caller must not invoke Thrust
// with inverted or empty iterator ranges.
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <limits>
#include <stdexcept>

namespace pulsejet {
namespace peakfinder {

struct BinRange {
  int begin = 0;
  int end = 0;  // one past last allowed index
  bool empty() const { return begin >= end; }
  int count() const { return end - begin; }
};

// Copying more candidates than the host scratch buffers can hold used
// to overwrite PeakFinder's fixed-size arrays on a high-occupancy/RFI trial.
inline void validate_host_peak_count(int found, std::size_t capacity) {
  if (found < 0 || static_cast<std::size_t>(found) > capacity) {
    throw std::runtime_error(
        "PeakFinder detected more peaks than its host scratch buffers can hold");
  }
}

inline double fundamental_frequency_for_bin(
    int bin, double bin_width_hz, unsigned int harmonic_level) {
  if (bin < 0 || !std::isfinite(bin_width_hz) || bin_width_hz <= 0.0
      || harmonic_level > 30) {
    throw std::invalid_argument("Invalid Fourier bin, bin width or harmonic level");
  }
  return static_cast<double>(bin) * bin_width_hz
      / std::ldexp(1.0, static_cast<int>(harmonic_level));
}

inline BinRange frequency_bin_range(
    double min_freq_hz, double max_freq_hz,
    double bin_width_hz, std::size_t spectrum_bins,
    unsigned int harmonic_level) {
  if (!std::isfinite(min_freq_hz) || !std::isfinite(max_freq_hz)
      || min_freq_hz < 0.0 || max_freq_hz <= min_freq_hz) {
    throw std::invalid_argument(
        "PeakFinder requires 0 <= finite min_freq < finite max_freq");
  }
  if (!std::isfinite(bin_width_hz) || bin_width_hz <= 0.0
      || spectrum_bins == 0
      || spectrum_bins > static_cast<std::size_t>(std::numeric_limits<int>::max())
      || harmonic_level > 30) {
    throw std::invalid_argument(
        "PeakFinder requires a positive bin width, bounded spectrum and valid harmonic level");
  }

  const double harmonic_multiplier =
      std::ldexp(1.0, static_cast<int>(harmonic_level));
  const double first = (min_freq_hz / bin_width_hz) * harmonic_multiplier;
  const double last = (max_freq_hz / bin_width_hz) * harmonic_multiplier;

  // Avoid overflowing int even if a user requests frequencies far outside
  // the spectrum. (+infinity from arithmetic overflow also clamps safely.)
  auto clamp_index = [spectrum_bins](double index) -> int {
    if (index <= 0.0) return 0;
    if (index >= static_cast<double>(spectrum_bins))
      return static_cast<int>(spectrum_bins);
    return static_cast<int>(index);
  };

  const int begin = clamp_index(std::ceil(first));
  const int end = clamp_index(std::floor(last) + 1.0);
  return {begin, end};
}

}  // namespace peakfinder
}  // namespace pulsejet
