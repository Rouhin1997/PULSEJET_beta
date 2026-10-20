# =========================
# PulseJet (PeaSoup) image
# =========================
# CUDA toolchain for nvcc and cuFFT
# Match HPC NVIDIA driver 545.23.08 (CUDA 12.3) and A40 (sm_86).
# The resampler does not use cuDNN; the CUDA devel image includes nvcc and cuFFT.
FROM nvidia/cuda:12.3.2-devel-ubuntu22.04

SHELL ["/bin/bash", "-lc"]
ENV DEBIAN_FRONTEND=noninteractive

# ---- System deps ----
RUN apt update -y && \
    apt install -y \
      git make gcc g++ \
      ca-certificates wget unzip bzip2 \
      vim emacs parallel \
      zlib1g-dev uuid-runtime \
      python3 python3-pip python-is-python3 \
      libtclap-dev \
    && apt clean && rm -rf /var/lib/apt/lists/*

# Small Python baseline (install numpy from Ubuntu repos for reliability in CI)
RUN apt-get update -y && \
    apt-get install -y python3-numpy && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---- Build-time env expected by your Makefile(.inc) ----
# NOTE: DO NOT set/override GPU_ARCH_FLAG here; let Makefile.inc decide
ENV CUDA_DIR=/usr/local/cuda \
    DEDISP_DIR=/usr/local \
    THRUST_DIR=/usr/local/cuda/include \
    INSTALL_DIR=/usr/local \
    UCFLAGS=""

# A40 is Ampere compute capability 8.6; build native SASS instead of relying
# on PTX JIT and compiling several unrelated GPU architectures.
ARG TARGET_GPU_ARCH=86

WORKDIR /software

# ---- Build & install dedisp (to /usr/local) ----
RUN git clone https://github.com/vishnubk/dedisp.git && \
    cd dedisp && \
    make clean || true && \
    make -B -j 8 && \
    make install && \
    ldconfig /usr/local/lib

# ---- Build & install your fork (to /usr/local/bin) ----
# Keep the source directory named 'peasoup' for legacy path expectations.
# Use the exact GitHub Actions checkout (dev branch/commit), not master.
# This is critical when building an image from dev/polynomial-search.
COPY . /software/peasoup
RUN cd /software/peasoup && \
    # clean + force rebuild so no stale objects sneak in
    make clean || true && \
    make -B -j 8 \
      DEDISP_DIR="${DEDISP_DIR}" \
      CUDA_DIR="${CUDA_DIR}" \
      THRUST_DIR="${THRUST_DIR}" \
      INSTALL_DIR="${INSTALL_DIR}" \
      UCFLAGS="${UCFLAGS}" \
      GPU_ARCH_FLAG="-gencode arch=compute_${TARGET_GPU_ARCH},code=sm_${TARGET_GPU_ARCH}" \
      V=1 && \
    # ensure target dir exists, then install
    mkdir -p "${INSTALL_DIR}/bin" && \
    make install INSTALL_DIR="${INSTALL_DIR}" && \
    ldconfig /usr/local/lib

# ---- Sanity check: verify the binary we just installed includes your -P flag ----
# (Doesn't require a GPU; fails the build fast if the option isn't present.)
RUN which peasoup && \
    ls -lh $(which peasoup) && \
    strings $(which peasoup) | grep -q "polynomial_template_bank_file" && \
    /usr/local/bin/peasoup --help | grep -A1 "polynomial_template_bank_file" && \
    /usr/local/bin/peasoup --help | grep -q "candidate_diagnostics"

# ---- PulsarX folding and scientific analysis ----
# Source revisions pinned for reproducible candidate validation. PRESTO/DSPSR
# are optional independent checks, not prerequisites for first folding tests.
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      autoconf automake libtool pkg-config cmake gfortran \
      libboost-dev libboost-system-dev libboost-program-options-dev \
      libboost-log-dev libboost-thread-dev \
      libcfitsio-dev libblas-dev liblapack-dev libeigen3-dev \
      libpng-dev libfftw3-dev libx11-dev pgplot5 liberfa-dev \
      python3-scipy python3-astropy python3-matplotlib python3-pandas \
      python3-yaml \
    && rm -rf /var/lib/apt/lists/*

ENV PULSARX_HOME=/opt/pulsarx \
    YMW16_DIR=/opt/pulsarx/src/XLibs/src/ymw16 \
    OMP_NUM_THREADS=1
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:$LD_LIBRARY_PATH

RUN mkdir -p /opt/pulsarx/src && \
    git clone https://github.com/ypmen/PlotX.git /opt/pulsarx/src/PlotX && \
    cd /opt/pulsarx/src/PlotX && git checkout 4380dbbec91d5bed8a209da88ca4a22f9b1fddb3 && \
    ./bootstrap && \
    ./configure --prefix=/usr/local CXXFLAGS="-std=c++11 -O3" && \
    make -j4 && make install && ldconfig

RUN git clone https://github.com/ypmen/XLibs.git /opt/pulsarx/src/XLibs && \
    cd /opt/pulsarx/src/XLibs && git checkout 7ce9473304f5feea8f91400253a11b0cbc9b0738 && \
    ./bootstrap && \
    ./configure --prefix=/usr/local CXXFLAGS="-std=c++11 -O3" \
      CPPFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib" && \
    make -j4 && make install && ldconfig

RUN git clone https://github.com/ypmen/PulsarX.git /opt/pulsarx/src/PulsarX && \
    cd /opt/pulsarx/src/PulsarX && git checkout e7e91a852176cb425d15220c3d250e8d262e08f4 && \
    ./bootstrap && \
    ./configure --prefix=/usr/local CXXFLAGS="-std=c++11 -O3" \
      CPPFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib" && \
    make -j4 && make install && ldconfig && \
    install -D -m 0644 include/template/meerkat_fold.template \
      /usr/local/share/pulsarx/meerkat_fold.template

RUN install -m 0755 /software/peasoup/tools/pulsejet_xml_to_pulsarx.py \
      /usr/local/bin/pulsejet_xml_to_pulsarx

RUN python3 -c "import numpy, scipy, astropy, matplotlib, pandas; print('Scientific Python ready')" && \
    which psrfold_fil && which psrfold_fil2 && which psrheader && \
    which pulsar_injector && \
    psrfold_fil --help | grep -q "f2search" && \
    psrfold_fil2 --help | grep -q "candfile" && \
    python3 /usr/local/bin/pulsejet_xml_to_pulsarx --help >/dev/null

# Default workdir for runtime
WORKDIR /data

# Helpful default entrypoint (comment out if you prefer a plain shell)
# ENTRYPOINT ["/usr/local/bin/peasoup"]
