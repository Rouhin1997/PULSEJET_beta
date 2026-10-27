// CPU-only regression for PeakFinder frequency limits and harmonics.
// Protects the original M62 200..350 Hz crash and silent x2 lower-bound.
#include "test_support.hpp"
#include <transforms/peakfinder_bounds.hpp>

#include <algorithm>
#include <cmath>
#include <limits>
#include <stdexcept>
#include <string>

using namespace pulsejet_test;
namespace pf = pulsejet::peakfinder;

namespace {
bool close_to(double a, double b, double tol=1e-9) {
  return std::abs(a-b) <= tol;
}
bool rejected(double low, double high, double width, std::size_t count,
              unsigned int nh) {
  try {
    (void)pf::frequency_bin_range(low,high,width,count,nh);
    return false;
  } catch (const std::invalid_argument&) {
    return true;
  }
}
}

int main() {
  TestSuite t;

  // Numerical parameters from the actual 505.29-second M62 I15 FFT.
  const std::size_t N=8388608;
  const std::size_t bins=N/2+1;
  const double duration=505.2902701172523;
  const double df=1.0/duration;

  for (unsigned nh=0; nh<5; ++nh) {
    const auto bounds=pf::frequency_bin_range(200.0,350.0,df,bins,nh);
    t.expect(!bounds.empty(), "Original [200,350] Hz interval must be nonempty, nh="+std::to_string(nh));
    t.expect(bounds.begin >= 0 && bounds.end <= static_cast<int>(bins),
             "M62 limits clamped within actual Fourier spectrum, nh="+std::to_string(nh));
    const double lo=pf::fundamental_frequency_for_bin(bounds.begin,df,nh);
    const double hi=pf::fundamental_frequency_for_bin(bounds.end-1,df,nh);
    t.expect(lo >= 200.0-1e-9 && lo < 200.0+df,
             "Lower edge is 200Hz not 400Hz, nh="+std::to_string(nh));
    t.expect(hi <= 350.0+1e-9 && hi > 350.0-df,
             "Upper edge maps to requested 350Hz, nh="+std::to_string(nh));
    t.expect(bounds.count() > 0, "PeakFinder device range is forward-only");
  }

  // An exactly integral frequency bin at either bound should be included.
  for (unsigned nh : {0u,1u,2u,3u,4u}) {
    const auto b=pf::frequency_bin_range(20,28,1.0,1025,nh);
    const int factor=1<<nh;
    t.expect(b.begin==20*factor && b.end==28*factor+1,
             "Integral inclusive limits for harmonic level "+std::to_string(nh));
    t.expect(close_to(pf::fundamental_frequency_for_bin(b.begin,1,nh),20.0),
             "Harmonic reported frequency uses original bin width divided by 2^nh");
  }
  {
    const auto b=pf::frequency_bin_range(0,1.0,1.0,65,0);
    t.expect(b.begin==0 && b.end==2, "Zero lower bound allows DC and 1Hz bin");
  }
  {
    // Max entirely above Nyquist is a valid clamped search; the
    // minimum itself beyond Nyquist yields an empty range, not CUDA crash.
    const auto b=pf::frequency_bin_range(20,100000,1,65,0);
    t.expect(b.begin==20 && b.end==65, "Requested upper bound clamps to spectrum end");
    const auto no_bins=pf::frequency_bin_range(1000,2000,1,65,0);
    t.expect(no_bins.empty() && no_bins.begin==65 && no_bins.end==65,
             "Out-of-spectrum frequency band yields empty range");
  }
  {
    const auto b=pf::frequency_bin_range(20.1,20.8,1,65,0);
    t.expect(b.empty() && b.begin==21 && b.end==21,
             "Narrow interval between Fourier bins yields empty range");
  }
  {
    const auto b=pf::frequency_bin_range(7.75,20.25,0.5,65,0);
    t.expect(b.begin==16 && b.end==41,
             "Nonintegral lower/upper bounds select correct bins");
  }
  {
    const auto b=pf::frequency_bin_range(1e300,1e301,df,bins,0);
    t.expect(b.empty() && b.begin==static_cast<int>(bins),
             "Overflowing requested index clamps before int conversion");
  }
  for (unsigned nh : {0u,1u,2u,3u,4u}) {
    const auto b=pf::frequency_bin_range(187,395,df,bins,nh);
    t.expect(!b.empty(), "Historical working M62 workaround band remains valid");
    const double first=pf::fundamental_frequency_for_bin(b.begin,df,nh);
    t.expect(first>=187.0 && first<187+df,
             "Corrected frequency band starts near 187 rather than 374");
  }
  t.expect(rejected(350,200,df,bins,0), "Reversed frequency bounds rejected");
  t.expect(rejected(200,200,df,bins,0), "Degenerate frequency bounds rejected");
  t.expect(rejected(-1,350,df,bins,0), "Negative frequency rejected");
  t.expect(rejected(0,std::numeric_limits<double>::infinity(),df,bins,0),
           "Infinite frequency rejected");
  t.expect(rejected(0,300,0,bins,0), "Zero bin width rejected");
  t.expect(rejected(0,300,df,0,0), "Zero spectrum size rejected");
  t.expect(rejected(0,300,df,bins,31), "Excessive harmonic level rejected");
  return t.finish();
}
