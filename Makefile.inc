# ============================================================================
# Makefile.inc  --  Common definitions for PeaSoup / PulseJet build
# ============================================================================

# Install prefix (where `make install` puts binaries)
INSTALL_DIR ?= /usr/local

# CUDA setup
CUDA_DIR    ?= /usr/local/cuda

# Thrust headers
THRUST_DIR  ?= /usr/local/cuda/include

# Dedisp setup
DEDISP_DIR  ?= /usr/local

# Toolchain
GCC         ?= gcc
GXX         ?= g++
AR          ?= ar
NVCC        ?= $(CUDA_DIR)/bin/nvcc
SHELL       := /bin/bash

# User flags (hook for extra defines etc.)
UCFLAGS     ?= -DUSE_NVTX

# --------------------------------------------------------------------
# GPU architectures (fatbinary) + PTX fallback
# --------------------------------------------------------------------
GPU_ARCH_FLAG = \
  -gencode arch=compute_60,code=sm_60 \
  -gencode arch=compute_61,code=sm_61 \
  -gencode arch=compute_70,code=sm_70 \
  -gencode arch=compute_75,code=sm_75 \
  -gencode arch=compute_80,code=sm_80 \
  -gencode arch=compute_86,code=sm_86 \
  -gencode arch=compute_89,code=sm_89 \
  -gencode arch=compute_80,code=compute_80
