#pragma once
// Polynomial-only resampler wrapper. Original Peasoup TimeDomainResampler
// and all Keplerian, circular and acceleration-only paths are unchanged.
#include <cstddef>
#include <kernels/kernels.h>
#include <kernels/defaults.h>

namespace pulsejet {
class PolynomialTimeDomainResampler {
  unsigned int max_threads_;
  unsigned int max_blocks_;
public:
  PolynomialTimeDomainResampler(unsigned int max_threads = MAX_THREADS,
                                unsigned int max_blocks = MAX_BLOCKS)
      : max_threads_(max_threads), max_blocks_(max_blocks) {}

  void resample(float* input, float* output, std::size_t size,
                double acceleration, double jerk, double tsamp) const {
    device_resample_acc_jerk(input, output, size, acceleration, jerk,
                            tsamp, max_threads_, max_blocks_);
  }
};
} // namespace pulsejet
