#pragma once
// Independent, CPU/GPU-compatible timing model for polynomial searches.
//
// t is the emitted, uniformly sampled reference time. With zero line-of-sight
// velocity at the segment midpoint and positive acceleration away from the
// observer, the observed arrival time is
//
// t_arr = t + [0.5*a*(t-t_ref)^2 + (j/6)*(t-t_ref)^3] / c.
//
// Thus a corrected output sample at emission time t reads the observation at
// t_arr. Constant propagation delay and systemic line-of-sight velocity are
// absorbed into the spin phase/frequency; a and j are midpoint values.
//
// This differs from the historical PULSEJET acceleration term x*(x-N/2),
// which has an unintended nonzero first derivative at the midpoint.
#include <cstddef>

#if defined(__CUDACC__)
#define PULSEJET_POLY_HD __host__ __device__
#else
#define PULSEJET_POLY_HD
#endif

namespace pulsejet {
namespace polynomial {
constexpr double speed_of_light = 299792458.0;

PULSEJET_POLY_HD inline double arrival_time(
    double emission_time, double reference_time,
    double acceleration, double jerk) {
  const double tau = emission_time - reference_time;
  return emission_time +
         tau * tau * (0.5 * acceleration + (jerk / 6.0) * tau)
         / speed_of_light;
}

PULSEJET_POLY_HD inline double arrival_time_derivative(
    double emission_time, double reference_time,
    double acceleration, double jerk) {
  const double tau = emission_time - reference_time;
  return 1.0 + (acceleration * tau + 0.5 * jerk * tau * tau) /
                        speed_of_light;
}

// Unrounded input index. The GPU explicitly rounds to nearest-even after
// computing this in double precision, then zero-pads out-of-bounds reads.
PULSEJET_POLY_HD inline double input_sample_index(
    double output_index, double size, double tsamp,
    double acceleration, double jerk) {
  const double dx = output_index - 0.5 * size;
  const double tau = dx * tsamp;
  return output_index +
         tau * tau * (0.5 * acceleration + (jerk / 6.0) * tau)
         / (speed_of_light * tsamp);
}
} // namespace polynomial
} // namespace pulsejet
#undef PULSEJET_POLY_HD
