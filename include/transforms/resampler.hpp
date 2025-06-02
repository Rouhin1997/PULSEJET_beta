#pragma once
#include <data_types/timeseries.hpp>
#include <kernels/kernels.h>
#include <kernels/defaults.h>
#include <utils/exceptions.hpp>

class TimeDomainResampler {
private:
  unsigned int max_threads;
  unsigned int max_blocks;
  
public:
  TimeDomainResampler(unsigned int max_threads=MAX_THREADS, unsigned int max_blocks=MAX_BLOCKS)
    :max_threads(max_threads),max_blocks(max_blocks)    
  {
  }
  
  //Force float until the kernel gets templated
  void resample(DeviceTimeSeries<float>& input, DeviceTimeSeries<float>& output, 
		unsigned int size, float acc)
  {
    device_resample(input.get_data(), output.get_data(), size,
		    acc, input.get_tsamp(),max_threads,  max_blocks);
  }

  void resampleII(DeviceTimeSeries<float>& input, DeviceTimeSeries<float>& output,
                unsigned int size, float acc)
  {
    device_resampleII(input.get_data(), output.get_data(), size,
                    acc, input.get_tsamp(),max_threads,  max_blocks);
  }

  void circular_orbit_resampler(DeviceTimeSeries<float>& input, DeviceTimeSeries<float>& output, unsigned int size, double n, double a1, double phi, double tsamp, double inverse_tsamp)
  {
    device_circular_orbit_resampler(input.get_data(), output.get_data(), n, a1, phi, tsamp, inverse_tsamp, size, max_threads, max_blocks);
  }

  void ell8_resampler(DeviceTimeSeries<float>& input, DeviceTimeSeries<float>& output, double n, double a1, double phi, double omega, double ecc, double tsamp, double inverse_tsamp, unsigned int size)
  {
   device_ell8_resampler(input.get_data(), output.get_data(), n, a1, phi, omega, ecc, tsamp, inverse_tsamp, size, max_threads, max_blocks);
}


void bt_model_resampler(DeviceTimeSeries<float>& input, DeviceTimeSeries<float>& output, 
   double n, double a1, double phi, double omega, double ecc, double tsamp, double inverse_tsamp, unsigned int size)

   {
    
   device_bt_model_resampler(input.get_data(), output.get_data(), n, a1, phi, omega, ecc, tsamp, inverse_tsamp, size, max_threads, max_blocks);

   }



};


