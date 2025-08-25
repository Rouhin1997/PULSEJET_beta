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
# CUDA version detection → GPU architecture flags
# --------------------------------------------------------------------
# Extract CUDA version string like "12.6"
CUDA_VERSION ?= $(shell $(NVCC) --version | awk -F'release ' '/release/{split($$2,a,","); print a[1]; exit}')

GPU_ARCH_FLAG =

ifeq ($(CUDA_VERSION),)
    $(warning "CUDA version not detected, using conservative default compute capabilities")
    GPU_ARCH_FLAG = \
        -gencode arch=compute_60,code=sm_60 \
        -gencode arch=compute_61,code=sm_61 \
        -gencode arch=compute_75,code=sm_75 \
        -gencode arch=compute_80,code=sm_80
else
    CUDA_MAJOR := $(shell echo $(CUDA_VERSION) | cut -d'.' -f1)
    CUDA_MINOR := $(shell echo $(CUDA_VERSION) | cut -d'.' -f2)

    # CUDA 10+
    ifneq ($(shell expr $(CUDA_MAJOR) \>= 10), 0)
        GPU_ARCH_FLAG += -gencode arch=compute_60,code=sm_60 \
                         -gencode arch=compute_61,code=sm_61 \
                         -gencode arch=compute_70,code=sm_70
    endif
    # CUDA 11+
    ifneq ($(shell expr $(CUDA_MAJOR) \>= 11), 0)
        GPU_ARCH_FLAG += -gencode arch=compute_75,code=sm_75
    endif
    # CUDA >= 11.2
    ifneq ($(shell expr $(CUDA_MAJOR) \>= 11 \& $(CUDA_MINOR) \>= 2), 0)
        GPU_ARCH_FLAG += -gencode arch=compute_80,code=sm_80
    endif
    # CUDA >= 11.8
    ifneq ($(shell expr $(CUDA_MAJOR) \>= 11 \& $(CUDA_MINOR) \>= 8), 0)
        GPU_ARCH_FLAG += -gencode arch=compute_86,code=sm_86
    endif
    # CUDA 12+
    ifneq ($(shell expr $(CUDA_MAJOR) \>= 12), 0)
        GPU_ARCH_FLAG += -gencode arch=compute_89,code=sm_89
    endif
    # CUDA >= 12.2
    ifneq ($(shell expr $(CUDA_MAJOR) \>= 12 \& $(CUDA_MINOR) \>= 2), 0)
        GPU_ARCH_FLAG += -gencode arch=compute_90,code=sm_90
    endif
endif
