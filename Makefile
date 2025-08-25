###############################################################################
# PeaSoup / PulseJet - Makefile
# - Builds bin/peasoup (+ optional bin/ffaster if ffa_pipeline.cu exists)
# - Honors env vars set by Dockerfile (CUDA_DIR, DEDISP_DIR, THRUST_DIR, INSTALL_DIR)
# - Uses C++17, clean/force rebuild friendly, robust install
###############################################################################

# ----- Directories (override via env or make VAR=value) ----------------------
BIN_DIR      ?= ./bin
OBJ_DIR      ?= ./obj
SRC_DIR      ?= ./src
INCLUDE_DIR  ?= ./include

# ----- Toolchain -------------------------------------------------------------
CUDA_DIR     ?= /usr/local/cuda
DEDISP_DIR   ?= /usr/local
THRUST_DIR   ?= $(CUDA_DIR)/include
INSTALL_DIR  ?= /usr/local

NVCC         ?= $(CUDA_DIR)/bin/nvcc
CXX          ?= g++

# ----- Flags -----------------------------------------------------------------
# GPU archs: can be overridden from outside; defaults are safe for Ampere+.
GPU_ARCH_FLAG ?= -gencode arch=compute_80,code=sm_80 \
                 -gencode arch=compute_86,code=sm_86 \
                 -gencode arch=compute_89,code=sm_89

# User CFLAGS hook (e.g., UCFLAGS="-DNDEBUG")
UCFLAGS      ?=

# Host compiler flags used by nvcc and g++
CPP_STD      := -std=c++17
WARNINGS     := -Wall -Wextra -Wno-unknown-pragmas
DEBUG        ?=
OPTIMISE     ?= -O3

CXXFLAGS     := $(CPP_STD) $(WARNINGS) $(OPTIMISE) $(DEBUG) $(UCFLAGS) -fPIC
NVCC_CXX     := -Xcompiler "$(OPTIMISE) $(DEBUG) $(WARNINGS) -fPIC" $(CPP_STD)

# nvcc flags
NVCCFLAGS    := $(UCFLAGS) $(OPTIMISE) $(DEBUG) $(GPU_ARCH_FLAG) -lineinfo --machine 64 $(CPP_STD)

# Include paths
INCLUDE      := -I$(INCLUDE_DIR) \
                -I$(THRUST_DIR) \
                -I$(DEDISP_DIR)/include \
                -I$(CUDA_DIR)/include/nvtx3 \
                -I./tclap \
                -I/usr/include

# Libraries
LIBS         := -L$(CUDA_DIR)/lib64 -lcudart -lcufft -lnvToolsExt \
                -L$(DEDISP_DIR)/lib -ldedisp \
                -lpthread -lm

# ----- Sources ----------------------------------------------------------------
# Core objects
CU_SRCS      := $(SRC_DIR)/kernels.cu
CPP_SRCS     := $(SRC_DIR)/utils.cpp

# Binaries
PEASOUP_MAIN := $(SRC_DIR)/pipeline_multi.cu
FFASTER_MAIN := $(SRC_DIR)/ffa_pipeline.cu

# Derived object names
CU_OBJS      := $(patsubst $(SRC_DIR)/%.cu,$(OBJ_DIR)/%.o,$(CU_SRCS))
CPP_OBJS     := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(CPP_SRCS))

PEASOUP_BIN  := $(BIN_DIR)/peasoup
FFASTER_BIN  := $(BIN_DIR)/ffaster

# ----- Phony targets ----------------------------------------------------------
.PHONY: all peasoup ffaster clean distclean install print-vars

all: directories peasoup ffaster

peasoup: $(PEASOUP_BIN)
ffaster: $(FFASTER_BIN)

directories:
	@mkdir -p $(BIN_DIR)
	@mkdir -p $(OBJ_DIR)

# ----- Build rules ------------------------------------------------------------

# CUDA .cu -> .o
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cu | directories
	$(NVCC) -c $(NVCCFLAGS) $(INCLUDE) $< -o $@

# C++ .cpp -> .o
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp | directories
	$(CXX) $(CXXFLAGS) $(INCLUDE) -c $< -o $@

# Link peasoup (nvcc handles device libs)
$(PEASOUP_BIN): $(PEASOUP_MAIN) $(CU_OBJS) $(CPP_OBJS) | directories
	$(NVCC) $(NVCCFLAGS) $(INCLUDE) $^ -o $@ $(LIBS)

# Link ffaster only if the source exists
$(FFASTER_BIN): $(FFASTER_MAIN) $(CU_OBJS) | directories
	@if [ -f "$(FFASTER_MAIN)" ]; then \
	  echo "Linking $@"; \
	  $(NVCC) $(NVCCFLAGS) $(INCLUDE) $^ -o $@ $(LIBS); \
	else \
	  echo "Skipping $@ (no $(FFASTER_MAIN))"; \
	  rm -f $@; \
	fi

# ----- Install ---------------------------------------------------------------

install: all
	@mkdir -p $(INSTALL_DIR)/bin
	install -m 0755 $(PEASOUP_BIN) $(INSTALL_DIR)/bin/peasoup
	@if [ -f "$(FFASTER_BIN)" ]; then \
	  install -m 0755 $(FFASTER_BIN) $(INSTALL_DIR)/bin/ffaster; \
	else \
	  true; \
	fi
	@echo "Installed to $(INSTALL_DIR)/bin"

# ----- Utilities --------------------------------------------------------------

clean:
	@rm -f $(OBJ_DIR)/*.o

distclean: clean
	@rm -f $(PEASOUP_BIN) $(FFASTER_BIN)

print-vars:
	@echo "CUDA_DIR     = $(CUDA_DIR)"
	@echo "DEDISP_DIR   = $(DEDISP_DIR)"
	@echo "THRUST_DIR   = $(THRUST_DIR)"
	@echo "INSTALL_DIR  = $(INSTALL_DIR)"
	@echo "GPU_ARCH_FLAG= $(GPU_ARCH_FLAG)"
	@echo "UCFLAGS      = $(UCFLAGS)"
	@echo "NVCC         = $(NVCC)"
	@echo "CXX          = $(CXX)"
