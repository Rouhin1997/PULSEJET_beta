#include <data_types/timeseries.hpp>
#include <data_types/fourierseries.hpp>
#include <data_types/header.hpp>
#include <data_types/candidates.hpp>
#include <data_types/filterbank.hpp>
#include <transforms/dedisperser.hpp>
#include <transforms/resampler.hpp>
#include <transforms/folder.hpp>
#include <transforms/ffter.hpp>
#include <transforms/dereddener.hpp>
#include <transforms/spectrumformer.hpp>
#include <transforms/birdiezapper.hpp>
#include <transforms/peakfinder.hpp>
#include <transforms/distiller.hpp>
#include <transforms/harmonicfolder.hpp>
#include <transforms/scorer.hpp>
#include <transforms/template_bank_reader.hpp>
#include <utils/exceptions.hpp>
#include <utils/utils.hpp>
#include <utils/stats.hpp>
#include <utils/stopwatch.hpp>
#include <utils/progress_bar.hpp>
#include <utils/cmdline.hpp>
#include <utils/output_stats.hpp>
#include <string>
#include <iostream>
#include <fstream>
#include <stdio.h>
#include <unistd.h>
#include "cuda.h"
#include "cufft.h"
#include "pthread.h"
#include <cmath>
#include <filesystem>
#include <map>
#include <optional>


typedef float DedispOutputType;

class DMDispenser {
private:
  DispersionTrials<DedispOutputType>& trials;
  pthread_mutex_t mutex;
  int dm_idx;
  int count;
  ProgressBar* progress;
  bool use_progress_bar;

public:
  DMDispenser(DispersionTrials<DedispOutputType>& trials)
    :trials(trials),dm_idx(0),use_progress_bar(false){
    count = trials.get_count();
    pthread_mutex_init(&mutex, NULL);
  }

  void enable_progress_bar(){
    progress = new ProgressBar();
    use_progress_bar = true;
  }

  int get_dm_trial_idx(void){
    pthread_mutex_lock(&mutex);
    int retval;
    if (dm_idx==0)
      if (use_progress_bar){
	printf("Releasing DMs to workers...\n");
	progress->start();
      }
    if (dm_idx >= trials.get_count()){
      retval =  -1;
      if (use_progress_bar)
	progress->stop();
    } else {
      if (use_progress_bar)
	progress->set_progress((float)dm_idx/count);
      retval = dm_idx;
      dm_idx++;
    }
    pthread_mutex_unlock(&mutex);
    return retval;
  }

  virtual ~DMDispenser(){
    if (use_progress_bar)
      delete progress;
    pthread_mutex_destroy(&mutex);
  }
};

class Worker {
private:
  DispersionTrials<DedispOutputType>& trials;
  DMDispenser& manager;
  CmdLineOptions& args;
  AccelerationPlan& acc_plan;
  unsigned int size;
  int device;
  std::map<std::string,Stopwatch> timers;
  std::optional<Keplerian_TemplateBank_Reader>& keplerian_tb;

  void preprocess_time_series(DedispersedTimeSeries<DedispOutputType>& tim,
    ReusableDeviceTimeSeries<float, DedispOutputType>& d_tim) {
        if (args.verbose) {
            std::cout << "Copying time series to device (DM=" << tim.get_dm() << ")\n";
            std::cout << "Transferring " << tim.get_nsamps() << " samples\n";
        }
        d_tim.copy_from_host(tim);
        if (args.verbose) std::cout << "Copy from host complete\n";
        if (args.verbose) std::cout << "Removing baseline\n";
        d_tim.remove_baseline(std::min(tim.get_nsamps(), d_tim.get_nsamps()));
        if (args.verbose) std::cout << "Baseline removed\n";
        if (size > tim.get_nsamps()) {
            if (args.verbose) std::cout << "Padding with zeros\n";
            d_tim.fill(tim.get_nsamps(), d_tim.get_nsamps(), 0);
        }
        if (args.verbose) std::cout << "Preprocessing done\n";
    }
  // 2) FFT -> rednoise + zap + stats

  void remove_rednoise_and_zap(ReusableDeviceTimeSeries<float, DedispOutputType>& d_tim,
    CuFFTerR2C& r2cfft,
    CuFFTerC2R& c2rfft,
    DeviceFourierSeries<cufftComplex>& d_fseries,
    DevicePowerSpectrum<float>& d_pspec,
    Dereddener& rednoise,
    Zapper* bzap,
    SpectrumFormer& former,
    float& mean, float& rms, float& std) {

    if (args.verbose) std::cout << "Executing forward FFT\n";
    r2cfft.execute(d_tim.get_data(), d_fseries.get_data());
    if (args.verbose) std::cout << "Forming power spectrum\n";
    former.form(d_fseries, d_pspec);
    if (args.verbose) std::cout << "Calculating running median\n";
    rednoise.calculate_median(d_pspec);
    if (args.verbose) std::cout << "Dereddening Fourier series\n";
    rednoise.deredden(d_fseries);
    if (bzap) {
        if (args.verbose) std::cout << "Zapping birdies\n";
        bzap->zap(d_fseries);
    }
    if (args.verbose) std::cout << "Forming interpolated spectrum\n";
    former.form_interpolated(d_fseries, d_pspec);
    if (args.verbose) std::cout << "Computing stats\n";
    //stats::stats<float>(d_pspec.get_data(), d_pspec.get_nbins(), &mean, nullptr, &std);
    //Check later if d_pspec.get_nbins() = size/2+1 (should be true)
    stats::stats<float>(d_pspec.get_data(), size/2+1, &mean, &rms, &std);
    if (args.verbose) std::cout << "Inverse FFT\n";
    c2rfft.execute(d_fseries.get_data(), d_tim.get_data());
    if (args.verbose) std::cout << "Rednoise removal and zapping complete\n";

    }

void run_search_and_find_candidates(DeviceTimeSeries<float>& d_tim_resampled,
    CuFFTerR2C& r2cfft,
    CuFFTerC2R& c2rfft,
    DeviceFourierSeries<cufftComplex>& d_fseries,
    DevicePowerSpectrum<float>& d_pspec,
    SpectrumFormer& former,
    HarmonicSums<float>& sums,
    HarmonicFolder& harm_folder,
    PeakFinder& cand_finder,
    HarmonicDistiller& harm_finder,
    SpectrumCandidates& trial_cands,
    CandidateCollection& output_cands,
    float mean, float std, unsigned int size) {

    if (args.verbose) std::cout << "Executing forward FFT\n";
    r2cfft.execute(d_tim_resampled.get_data(), d_fseries.get_data());
    if (args.verbose) std::cout << "Forming interpolated power spectrum\n";
    former.form_interpolated(d_fseries, d_pspec);
    if (args.verbose) std::cout << "Normalising power spectrum\n";
    stats::normalise(d_pspec.get_data(), mean * size, std * size, size / 2 + 1);
    if (args.verbose) std::cout << "Harmonic summing\n";
    harm_folder.fold(d_pspec);
    if (args.verbose) std::cout << "Finding peaks\n";
    cand_finder.find_candidates(d_pspec, trial_cands);
    cand_finder.find_candidates(sums, trial_cands);
    if (args.verbose) std::cout << "Distilling harmonics\n";
    output_cands.append(harm_finder.distill(trial_cands.cands));
}

public:
  CandidateCollection dm_trial_cands;

  Worker(DispersionTrials<DedispOutputType>& trials, DMDispenser& manager,
	 AccelerationPlan& acc_plan, CmdLineOptions& args, unsigned int size, int device,
         std::optional<Keplerian_TemplateBank_Reader>& keplerian_tb)
    :trials(trials)
    ,manager(manager)
    ,acc_plan(acc_plan)
    ,args(args)
    ,size(size)
    ,device(device)
    ,keplerian_tb(keplerian_tb)
  {}

  void start(void)
  {
    
    cudaSetDevice(device);
    Stopwatch pass_timer;
    pass_timer.start();

    CuFFTerR2C r2cfft(size);
    CuFFTerC2R c2rfft(size);
    float tobs = size*trials.get_tsamp();
    float bin_width = 1.0/tobs;
    DeviceFourierSeries<cufftComplex> d_fseries(size/2+1,bin_width);
    DedispersedTimeSeries<DedispOutputType> tim;
    ReusableDeviceTimeSeries<float, DedispOutputType> d_tim(size);
    DeviceTimeSeries<float> d_tim_resampled(size);
    DevicePowerSpectrum<float> d_pspec(d_fseries);
    Dereddener rednoise(size/2+1);
    SpectrumFormer former;
    PeakFinder cand_finder(args.min_snr,args.min_freq,args.max_freq,size);
    HarmonicSums<float> sums(d_pspec,args.nharmonics);
    HarmonicFolder harm_folder(sums);
    HarmonicDistiller harm_finder(args.freq_tol,args.max_harm,false);
    float mean,std,rms;
    int idx;

    // Set up zapper if requested
    Zapper* bzap = nullptr; 
    if (!args.zapfilename.empty()) {            
        if (args.verbose) 
          std::cout << "Using zapfile: " << args.zapfilename << "\n";
        bzap = new Zapper(args.zapfilename);      // create it only then
      }
    // if (args.zapfilename!=""){
    //   if (args.verbose)
	//       std::cout << "Using zapfile: " << args.zapfilename << std::endl;
    //   bzap = new Zapper(args.zapfilename);
    // }

    TimeDomainResampler resampler;
    std::vector<float> acc_list;
    AccelerationDistiller acc_still(tobs,args.freq_tol,true);



	PUSH_NVTX_RANGE("DM-Loop",0)
    while (true) {
        idx = manager.get_dm_trial_idx();
        trials.get_idx(idx, tim, size);
        if (idx == -1) break;
        //Start processing
        preprocess_time_series(tim, d_tim);
        remove_rednoise_and_zap(d_tim, r2cfft, c2rfft, d_fseries, d_pspec, rednoise, bzap, former, mean, rms, std);
        
        // Acceleration search only

        if (args.verbose) std::cout << "Generating acceleration list" << std::endl;
        acc_plan.generate_accel_list(tim.get_dm(), args.cdm, acc_list);

        if (args.verbose) std::cout << "Searching "<< acc_list.size()<< " acceleration trials for DM "<< tim.get_dm() << std::endl;

        CandidateCollection accel_search_cands;
        PUSH_NVTX_RANGE("Acceleration-Loop",1)

        for (int jj=0;jj<acc_list.size();jj++){
            if (args.verbose) std::cout << "Resampling to "<< acc_list[jj] << " m/s/s" << std::endl;
            resampler.resampleII(d_tim,d_tim_resampled,size,acc_list[jj]);
            SearchParams accel_search;
            accel_search.acc = acc_list[jj];
  	        SpectrumCandidates trial_cands(tim.get_dm(),idx,accel_search);
            run_search_and_find_candidates(d_tim_resampled, r2cfft, c2rfft, d_fseries, d_pspec, former, sums, harm_folder, cand_finder,
                harm_finder, trial_cands, accel_search_cands, mean, std, size);    
        }
	    POP_NVTX_RANGE
        if (args.verbose) std::cout << "Distilling accelerations" << std::endl;
        dm_trial_cands.append(acc_still.distill(accel_search_cands.cands));
    }
	POP_NVTX_RANGE

    if (args.zapfilename!="")
      delete bzap;

    if (args.verbose)
      std::cout << "DM processing took " << pass_timer.getTime() << " seconds"<< std::endl;
  }

};

void* launch_worker_thread(void* ptr){
  reinterpret_cast<Worker*>(ptr)->start();
  return NULL;
}


bool getFileContent(std::string fileName, std::vector<float> & vecOfDMs)
{
    // Open the File
    std::ifstream in(fileName.c_str());
    // Check if object is valid
    if(!in)
    {
        std::cerr << "Cannot open the File : "<<fileName<<std::endl;
        return false;
    }
    std::string str;
    float fl;
    // Read the next line from File untill it reaches the end.
    while (std::getline(in, str))
    {
        // Line contains string of length > 0 then save it in vector
        if(str.size() > 0)
            fl = std::atof(str.c_str());
            //fl = std::stof(str); //c++11
            vecOfDMs.push_back(fl);
    }
    //Close The File
    in.close();
    return true;
}






int main(int argc, char **argv)
{
  std::map<std::string,Stopwatch> timers;
  timers["reading"]      = Stopwatch();
  timers["dedispersion"] = Stopwatch();
  timers["searching"]    = Stopwatch();
  timers["folding"]      = Stopwatch();
  timers["total"]        = Stopwatch();
  timers["total"].start();

  CmdLineOptions args;
  if (!read_cmdline_options(args,argc,argv))
    ErrorChecker::throw_error("Failed to parse command line arguments.");

  int nthreads = std::min(Utils::gpu_count(),args.max_num_threads);
  nthreads = std::max(1,nthreads);

  /* Could do a check on the GPU memory usage here */

  if (args.verbose)
    std::cout << "Using file: " << args.infilename << std::endl;
  std::string filename(args.infilename);
  std::filesystem::path filpath = filename;

  if(args.timeseries_dump_dir == "" && args.no_search){
    std::cout << "-nosearch is only useful if you are only dumping timeseries. Otherwise it does nothing." << std::endl;
  }

  //Stopwatch timer;
  if (args.progress_bar)
    printf("Reading header from %s\n",args.infilename.c_str());


  if (args.nsamples > 0 && args.size > 0 && args.nsamples > args.size) ErrorChecker::throw_error("nsamples cannot be > fft size.");
  if (args.size > 0 && args.nsamples == 0){
     args.nsamples =  args.size;
    }  

  timers["reading"].start();
  SigprocFilterbank filobj(filename, args.start_sample, args.nsamples);
  SigprocHeader header = filobj.get_header();
  timers["reading"].stop();

  if (args.progress_bar){
    printf("Complete (execution time %.2f s)\n",timers["reading"].getTime());
  }
  unsigned int size;
  if (args.size == 0){
    size =  Utils::prev_power_of_two(filobj.get_effective_nsamps()); // By this time  fft size = effective nsamps in the default case. 
  }
    else {
    size = args.size;
  }
  //Set for pepoch calculation later
  filobj.size = size;


  if (args.verbose)
    std::cout << "Effective nsamples " << filobj.get_effective_nsamps() << " points" << std::endl;
    std::cout << "Setting transform length to " << size << " points" << std::endl;


  DMDistiller dm_still(args.freq_tol,true);
  HarmonicDistiller harm_still(args.freq_tol,args.max_harm,true,false);
  CandidateCollection dm_cands;



  AccelerationPlan acc_plan(
    args.acc_start, // m/s^2
    args.acc_end,   // m/s^2
    args.acc_tol,   // dimensionless
    args.acc_pulse_width * 1e-6, // cmd line arg is microseconds but needs to be passed as seconds
    size, // Number of samples in FFT. Set based on segment samples and power of 2.
    filobj.get_tsamp(), // seconds
    filobj.get_cfreq() * 1e6, // from header in MHz needs converted to Hz
    filobj.get_foff() * 1e6 // from header in MHz needs converted to Hz
    );
 
  std::optional<Keplerian_TemplateBank_Reader> keplerian_tb;

  if (args.keplerian_tb_file != "none") {
    if (args.verbose)
        std::cout << "Using template bank file: " << args.keplerian_tb_file << std::endl;

    keplerian_tb.emplace(args.keplerian_tb_file);

    // Print first 5 values of n
    const auto& n_vals = keplerian_tb->get_n();
    std::cout << "First 5 values of n: ";
    for (size_t i = 0; i < std::min(n_vals.size(), size_t(5)); ++i)
        std::cout << n_vals[i] << " ";
    std::cout << std::endl;
}
  


  if (args.verbose)
    std::cout << "Generating DM list" << std::endl;
  std::vector<float> full_dm_list;

  if (args.dm_file=="none") {
    Dedisperser dedisperser(filobj, nthreads);
    dedisperser.generate_dm_list(args.dm_start, args.dm_end, args.dm_pulse_width, args.dm_tol);
    full_dm_list = dedisperser.get_dm_list();
  }
  else {
      bool result = getFileContent(args.dm_file, full_dm_list);
  }

  float nbytes = args.host_ram_limit_gb * 1e9;
  std::size_t ndm_trial_gulp = std::size_t(nbytes / (filobj.get_effective_nsamps() * sizeof(float)));
  if (ndm_trial_gulp == 0)
  {
    throw std::runtime_error("Insufficient RAM specified to allow for dedispersion");
  }
  else if (ndm_trial_gulp > full_dm_list.size())
  {
    ndm_trial_gulp = full_dm_list.size();
  }
  for(std::size_t idx=0; idx < full_dm_list.size(); idx += ndm_trial_gulp){
    std::size_t start = idx;
    std::size_t end   = (idx + ndm_trial_gulp) > full_dm_list.size() ? full_dm_list.size(): (idx + ndm_trial_gulp) ;
    if(args.verbose) std::cout << "Gulp start: " << start << " end: " << end << std::endl;
    std::vector<float> dm_list_chunk(full_dm_list.begin() + start,  full_dm_list.begin() + end);
    Dedisperser dedisperser(filobj, nthreads);
    if (args.killfilename!=""){
      if (args.verbose)
        std::cout << "Using killfile: " << args.killfilename << std::endl;
      dedisperser.set_killmask(args.killfilename);
    }

    dedisperser.set_dm_list(dm_list_chunk);

    if (args.verbose){
    std::cout << dm_list_chunk.size() << " DM trials" << std::endl;
    for (std::size_t ii = 0; ii < dm_list_chunk.size(); ii++)
    {
      std::cout << dm_list_chunk[ii] << std::endl;
    }
    std::cout << "Executing dedispersion" << std::endl;
    }

    if (args.progress_bar) std::cout <<"Starting dedispersion: " << start << " to " << end << "..." << std::endl;

    timers["dedispersion"].start();
    PUSH_NVTX_RANGE("Dedisperse",3)
    DispersionTrials<DedispOutputType> trials(filobj.get_tsamp());
    std::cout <<"dedispersing...." <<std::endl;

    std::size_t gulp_size;
    if (args.dedisp_gulp == -1){
      gulp_size = filobj.get_effective_nsamps();
    } else {
      gulp_size = args.dedisp_gulp;
    }
    if(args.verbose){
      std::cout<< "Starting to dedisperse filterbank from Sample:" << filobj.get_start_sample() 
            << " to " << filobj.get_end_sample() << " samples, with gulp size of " << gulp_size << " samples" << std::endl;
    }
    dedisperser.dedisperse(trials, filobj.get_start_sample(), filobj.get_end_sample(), gulp_size);
    POP_NVTX_RANGE
    //trials.set_nsamps(size);
    timers["dedispersion"].stop();
    if (args.progress_bar)
      printf("Complete (execution time %.2f s)\n",timers["dedispersion"].getTime());

    std::cout <<"Starting searching..."  << std::endl;

    //Multithreading commands
    timers["searching"].start();
    
    std::vector<Worker*> workers(nthreads);
    std::vector<pthread_t> threads(nthreads);

    DMDispenser dispenser(trials);
    if (args.progress_bar)
      dispenser.enable_progress_bar();

    if (args.timeseries_dump_dir != ""){
      std::cout << "Dumping time series to " << args.timeseries_dump_dir << std::endl;
      std::cout << "filename without ext: " << filpath.stem().string() << std::endl;
      std::filesystem::create_directories(args.timeseries_dump_dir);
      for (int ii=0;ii<dm_list_chunk.size();ii++){
        trials.write_timeseries_to_file(args.timeseries_dump_dir, filpath.stem().string(), ii, header);
      }
      if(args.no_search){
        std::cout << "No search requested, exiting" << std::endl;
        return 0;
      }
    }

   
    
    for (int ii=0;ii<nthreads;ii++){
      workers[ii] = (new Worker(trials,dispenser,acc_plan,args,size,ii,keplerian_tb));
      pthread_create(&threads[ii], NULL, launch_worker_thread, (void*) workers[ii]);
    }

    if(args.verbose)
      std::cout << "Joining worker threads" << std::endl;

    for (int ii=0; ii<nthreads; ii++){
      pthread_join(threads[ii],NULL);
      dm_cands.append(workers[ii]->dm_trial_cands.cands);
      delete workers[ii];
    }
    timers["searching"].stop();

    if (args.progress_bar)
      printf("Complete (execution time %.2f s)\n",timers["searching"].getTime());


  }

  if (args.verbose)
    std::cout << "Distilling DMs" << std::endl;
  
  dm_cands.cands = dm_still.distill(dm_cands.cands);
  dm_cands.cands = harm_still.distill(dm_cands.cands);

  CandidateScorer cand_scorer(filobj.get_tsamp(),filobj.get_cfreq(), filobj.get_foff(),
			      fabs(filobj.get_foff())*filobj.get_nchans());
  cand_scorer.score_all(dm_cands.cands);

  if (args.verbose)
    std::cout << "Setting up time series folder" << std::endl;

  if (args.verbose)
    std::cout << "Writing output files" << std::endl;

  int new_size = std::min(args.limit,(int) dm_cands.cands.size());
  dm_cands.cands.resize(new_size);

  CandidateFileWriter cand_files(args.outdir);
  cand_files.write_binary(dm_cands.cands,"candidates.peasoup");

  OutputFileWriter stats;
  stats.add_misc_info();
  stats.add_header(filename);
  stats.add_search_parameters(args);
  stats.add_segment_parameters(filobj);
  stats.add_dm_list(full_dm_list);

  std::vector<float> acc_list;
  acc_plan.generate_accel_list(args.cdm, args.cdm, acc_list);
  stats.add_acc_list(acc_list, args.cdm);

  std::vector<int> device_idxs;
  for (int device_idx=0;device_idx<nthreads;device_idx++)
    device_idxs.push_back(device_idx);
  stats.add_gpu_info(device_idxs);
  stats.add_candidates(dm_cands.cands,cand_files.byte_mapping);
  timers["total"].stop();
  stats.add_timing_info(timers);

  std::stringstream xml_filepath;
  xml_filepath << args.outdir << "/" << "overview.xml";
  stats.to_file(xml_filepath.str());

  std::cerr << "all done" << std::endl;

  return 0;
}
