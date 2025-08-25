# =========================
# PulseJet (PeaSoup) image
# =========================
# CUDA toolchain for nvcc and cuFFT
FROM nvidia/cuda:12.6.0-cudnn-devel-ubuntu22.04

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

# Small Python baseline (only numpy is needed by some tools)
RUN pip3 install --no-cache-dir numpy

# ---- Build-time env expected by your Makefile(.inc) ----
# Adjust GPU_ARCH_FLAG to match the SMs you care about
ENV CUDA_DIR=/usr/local/cuda \
    DEDISP_DIR=/usr/local \
    THRUST_DIR=/usr/local/cuda/include \
    INSTALL_DIR=/usr/local \
    UCFLAGS="" \
    GPU_ARCH_FLAG="-gencode arch=compute_80,code=sm_80 \
                   -gencode arch=compute_86,code=sm_86 \
                   -gencode arch=compute_89,code=sm_89"

WORKDIR /software

# ---- Build & install dedisp (to /usr/local) ----
RUN git clone https://github.com/vishnubk/dedisp.git && \
    cd dedisp && \
    make clean || true && \
    make -B -j 8 && \
    make install && \
    ldconfig /usr/local/lib

# ---- Build & install your fork (to /usr/local/bin) ----
# Clone your repo into a folder named 'peasoup' to match old path expectations
RUN git clone https://github.com/Rouhin1997/PULSEJET_beta.git peasoup && \
    cd peasoup && \
    # clean + force rebuild so no stale objects sneak in
    make clean || true && \
    make -B -j 8 \
      DEDISP_DIR="${DEDISP_DIR}" \
      CUDA_DIR="${CUDA_DIR}" \
      THRUST_DIR="${THRUST_DIR}" \
      INSTALL_DIR="${INSTALL_DIR}" \
      GPU_ARCH_FLAG="${GPU_ARCH_FLAG}" \
      UCFLAGS="${UCFLAGS}" V=1 && \
    # ensure target dir exists, then install
    mkdir -p "${INSTALL_DIR}/bin" && \
    make install INSTALL_DIR="${INSTALL_DIR}" && \
    ldconfig /usr/local/lib

# ---- Sanity check: verify the binary we just installed includes your -P flag ----
# (Doesn't require a GPU; fails the build fast if the option isn't present.)
RUN which peasoup && \
    ls -lh $(which peasoup) && \
    strings $(which peasoup) | grep -q "polynomial_template_bank_file" && \
    /usr/local/bin/peasoup --help | grep -A1 "polynomial_template_bank_file"

# Default workdir for runtime
WORKDIR /data

# Helpful default entrypoint (comment out if you prefer a plain shell)
# ENTRYPOINT ["/usr/local/bin/peasoup"]
