#pragma once
#include "stdio.h"
#include "data_types/candidates.hpp"
#include <vector>
#include <cmath>
#include <algorithm>

#define SPEED_OF_LIGHT 299792458.0

struct snr_less_than {
  bool operator()(const Candidate& x, const Candidate& y){
    return (x.snr>y.snr);
  }
};

class BaseDistiller {
protected:
  std::vector<bool> unique;
  int size;
  bool keep_related;
  virtual void condition(std::vector<Candidate>& cands, int idx){}
  BaseDistiller(bool keep_related)
    :keep_related(keep_related){}

public:      
  std::vector<Candidate> distill(std::vector<Candidate>& cands)
  {
    size = cands.size();
    unique.resize(size);
    std::fill(unique.begin(),unique.end(),true);
    std::sort(cands.begin(),cands.end(),snr_less_than()); //Sort by snr !IMPORTANT       
    int ii;
    int idx;
    int start=0;
    int count=0;
    while (true) {
      idx = -1; //Sentinel value                                                    
      for(ii=start;ii<size;ii++){
        if (unique[ii]){
          start = ii+1;
          idx = ii;
          break;
        }
      }
      if (idx==-1)
        break;
      else{
	count++;
	condition(cands,idx);
      }
    }
    std::vector<Candidate> new_cands;
    new_cands.reserve(count);
    for (ii=0;ii<size;ii++){
      if (unique[ii])
        new_cands.push_back(cands[ii]);
    }
    return new_cands;
  }
};


class HarmonicDistiller: public BaseDistiller {
private:
  float tolerance;
  float max_harm;
  bool fractional_harms;

  void condition(std::vector<Candidate>& cands, int idx)
  {
    int ii,jj,kk;
    double ratio,freq;
    int nh;
    double upper_tol = 1+tolerance;
    double lower_tol = 1-tolerance;
    double fundi_freq = cands[idx].freq;
    float max_denominator;
    for (ii=idx+1;ii<size;ii++){
      freq = cands[ii].freq;
      nh = cands[ii].nh;
      
      /*
      if (cands[ii].nh > cands[idx].nh){
        continue;
	}
      */

      if (fractional_harms)
	max_denominator = pow(2.0,nh);
      else
	max_denominator = 1;
      for (jj=1;jj<=this->max_harm;jj++){
        for (kk=1;kk<=max_denominator;kk++){
          ratio = kk*freq/(jj*fundi_freq);
          if (ratio>(lower_tol)&&ratio<(upper_tol)){
	    if (keep_related)
	      cands[idx].append(cands[ii]);
            unique[ii]=false;
          }
	}
      }
    }
  }
  
public:
  HarmonicDistiller(float tol, float max_harm, bool keep_related, bool fractional_harms=true)
    :BaseDistiller(keep_related),tolerance(tol),max_harm(max_harm),fractional_harms(fractional_harms){}
};


//Remove other candidates with lower S/N and equal or lower harmonic number
//Use a user defined period tolerance, but calculate the delta f for the 
//delta acc between fundamental and test signal.

class AccelerationDistiller: public BaseDistiller {
private:
  float tobs;
  double tobs_over_c;
  float tolerance;
  
  float correct_for_acceleration(double freq, double delta_acc){
    return freq+delta_acc*freq*tobs_over_c;
  }

  void condition(std::vector<Candidate>& cands,int idx)
  {
    int ii;
    double fundi_freq = cands[idx].freq;
    double fundi_acc = cands[idx].acc;
    double acc_freq;
    double delta_acc;
    double edge = fundi_freq*tolerance;
    for (ii=idx+1;ii<size;ii++){
      /*
      if (cands[ii].nh > cands[idx].nh){
	continue;
	}*/

      delta_acc = fundi_acc-cands[ii].acc;
      acc_freq = correct_for_acceleration(fundi_freq,delta_acc);

      if (acc_freq>fundi_freq){
	if (cands[ii].freq>fundi_freq-edge && cands[ii].freq<acc_freq+edge){
	  if (keep_related)
	    cands[idx].append(cands[ii]);
	  unique[ii]=false;
	}
      } else {
	if (cands[ii].freq<fundi_freq+edge && cands[ii].freq>acc_freq-edge){
	  if (keep_related)
	    cands[idx].append(cands[ii]);
	  unique[ii]=false;
	}
      }
    }
  }
  
public:
  AccelerationDistiller(float tobs, float tolerance, bool keep_related)
    :BaseDistiller(keep_related),tobs(tobs),tolerance(tolerance){
    tobs_over_c = tobs/SPEED_OF_LIGHT;
  }
};
//NOTE: +ve acceleration is away from observer



class Template_Bank_Circular_Distiller: public BaseDistiller {
private:
  float tolerance;
  
  float min_doppler_freq_template_bank(double freq, double n, double a1){
    return freq*(1-(n*a1));
  }

  float max_doppler_freq_template_bank(double freq, double n, double a1){
    return freq*(1+(n*a1));
  }

  void condition(std::vector<Candidate>& cands,int idx)
  {
    int ii;
    double min_doppler_fundi_freq, max_doppler_fundi_freq;
    double fundi_freq = cands[idx].freq;
    double fundi_n = cands[idx].n;
    double fundi_a1 = cands[idx].a1;
    double fundi_phi = cands[idx].phi;
    double edge = fundi_freq*tolerance;
    for (ii=idx+1;ii<size;ii++){
     
      min_doppler_fundi_freq = min_doppler_freq_template_bank(fundi_freq, fundi_n, fundi_a1);
      max_doppler_fundi_freq = max_doppler_freq_template_bank(fundi_freq, fundi_n, fundi_a1);
 
      if (cands[ii].freq>min_doppler_fundi_freq-edge && cands[ii].freq<max_doppler_fundi_freq+edge){
          if (keep_related)
            cands[idx].append(cands[ii]);
          unique[ii]=false;
        }       

    }
  }
  
public:
  Template_Bank_Circular_Distiller(float tolerance, bool keep_related)
    :BaseDistiller(keep_related),tolerance(tolerance){}
};

class DMDistiller: public BaseDistiller {
private:
  float tolerance;
  double ratio;

  void condition(std::vector<Candidate>& cands,int idx)
  {
    int ii;
    double fundi_freq = cands[idx].freq;
    double upper_tol = 1+tolerance;
    double lower_tol = 1-tolerance;
    for (ii=idx+1;ii<size;ii++){
      /*
      if (cands[ii].nh > cands[idx].nh){
        continue;
	}*/
      
      ratio = cands[ii].freq/fundi_freq;
      if (ratio>(lower_tol)&&ratio<(upper_tol)){
	if (keep_related)
	  cands[idx].append(cands[ii]);
	unique[ii]=false;
      }
    }
  }
  
public:
  DMDistiller(float tolerance, bool keep_related)
    :BaseDistiller(keep_related),tolerance(tolerance){}
};

class Template_Bank_Polynomial_Distiller: public BaseDistiller {
private:
  float freq_tolerance;
  float acc_tolerance;
  float jerk_tolerance;

  void condition(std::vector<Candidate>& cands, int idx) override
  {
    double fundi_freq = cands[idx].freq;
    double fundi_acc = cands[idx].acc;
    double fundi_jerk = cands[idx].jerk;
    double edge_freq = std::abs(fundi_freq) * freq_tolerance + 1e-8;
    double edge_acc = std::abs(fundi_acc) * acc_tolerance + 1e-8;
    double edge_jerk = std::abs(fundi_jerk) * jerk_tolerance + 1e-8;

    for (int ii = idx + 1; ii < size; ii++) {
      if (std::abs(cands[ii].freq - fundi_freq) < edge_freq &&
          std::abs(cands[ii].acc - fundi_acc) < edge_acc &&
          std::abs(cands[ii].jerk - fundi_jerk) < edge_jerk) {
        if (keep_related)
          cands[idx].append(cands[ii]);
        unique[ii] = false;
      }
    }
  }

public:
  Template_Bank_Polynomial_Distiller(float freq_tol, float acc_tol, float jerk_tol, bool keep_related = true)
    : BaseDistiller(keep_related),
      freq_tolerance(freq_tol),
      acc_tolerance(acc_tol),
      jerk_tolerance(jerk_tol)
  {}
};

