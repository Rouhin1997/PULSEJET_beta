#pragma once
#include <iostream>
#include "data_types/candidates.hpp"
#include "data_types/fourierseries.hpp"
#include "transforms/peakfinder_bounds.hpp"
#include "kernels/kernels.h"
#include <thrust/device_vector.h>
#include "utils/utils.hpp"
#include <cmath>
#include <algorithm>

class PeakFinder {
private:
  float threshold; //Sigma threshold
  float min_freq;
  float max_freq;
  int min_gap; //The minimum gap between adjacent peaks such that the are considered unique
  unsigned int max_cands; //This value is hardcoded (could cause segfault)
  std::vector<int> idxs;
  std::vector<float> snrs;
  std::vector<int> peakidxs;
  std::vector<float> peaksnrs;
  std::vector<float> peakfreqs;
  thrust::device_vector<int> d_idxs;
  thrust::device_vector<float> d_snrs;
  cached_allocator allocator;
  
  int identify_unique_peaks(unsigned int count)
  {
    int ii;
    float cpeak;
    int cpeakidx;
    int lastidx= -1 * min_gap;
    int npeaks=0;
    ii=0;

    while (ii<count){
      cpeak=snrs[ii];
      cpeakidx=idxs[ii];
      lastidx=idxs[ii];
      ii++;

      while (ii<count && (idxs[ii]-lastidx) < min_gap){
        if (snrs[ii]>cpeak)
	  {                                                                                
	    cpeak=snrs[ii];
	    cpeakidx=idxs[ii];
	    lastidx=idxs[ii];
	  }
        ii++;
      }
      peakidxs[npeaks]=cpeakidx;
      peaksnrs[npeaks]=cpeak;
      npeaks++;
    }
    return npeaks;
  }

public:
  PeakFinder(float threshold, float min_freq, float max_freq, unsigned int size, int min_gap=30)
    :threshold(threshold), min_freq(min_freq), 
     max_freq(max_freq),min_gap(min_gap),max_cands(100000)
  {
    idxs.resize(max_cands);
    snrs.resize(max_cands);
    peakidxs.resize(max_cands);
    peaksnrs.resize(max_cands);
    peakfreqs.resize(max_cands);
    d_idxs.resize(size);
    d_snrs.resize(size);
  }

  void find_candidates(HarmonicSums<float>& sums, SpectrumCandidates& cands){
    for (int ii=0;ii<sums.size();ii++)
      find_candidates(*sums[ii],cands);
  }
  
  void find_candidates(DevicePowerSpectrum<float>& pspec, SpectrumCandidates& cands){
    // Convert both limits to the SAME harmonic-scaled Fourier-bin units.
    // The previous start_idx formula multiplied the lower limit by ~2,
    // potentially creating start_idx > max_bin (invalid Thrust range).
    // frequency_bin_range() gives [begin,end) and safely clamps to the
    // spectrum size, including when the requested range has no bins.
    const unsigned int nh = pspec.get_nh();
    const auto range = pulsejet::peakfinder::frequency_bin_range(
        static_cast<double>(min_freq), static_cast<double>(max_freq),
        pspec.get_bin_width(), pspec.get_nbins(), nh);
    if (range.empty()) return;

    const int count = device_find_peaks(
        range.end, range.begin, pspec.get_data(),
        threshold, &idxs[0], &snrs[0],
        d_idxs, d_snrs, allocator);
    const int npeaks = identify_unique_peaks(count);
    for (int ii=0;ii<npeaks;ii++){
      peakfreqs[ii] = static_cast<float>(
          pulsejet::peakfinder::fundamental_frequency_for_bin(
              peakidxs[ii], pspec.get_bin_width(), nh));
    }
    cands.append(&peaksnrs[0],&peakfreqs[0],nh,npeaks);
  }
};
