###############################################################################
# PeaSoup / PulseJet - Makefile (cleaned)
# - Builds bin/peasoup only
# - Robust install, no ffaster target
###############################################################################

include Makefile.inc

# Output directories
BIN_DIR     = ./bin
OBJ_DIR     = ./obj

# Paths
SRC_DIR     = ./src
INCLUDE_DIR = ./include

# Compiler flags
OPTIMISE = -O3
DEBUG    =

# Includes and libraries
INCLUDE  = -I$(INCLUDE_DIR) -I$(THRUST_DIR) -I${DEDISP_DIR}/include -I${CUDA_DIR}/include/nvtx3 -I./tclap
LIBS     = -L$(CUDA_DIR)/lib64 -lcudart -L${DEDISP_DIR}/lib -ldedisp -lcufft -lpthread -lnvToolsExt

# Compiler flags (Uses dynamically set GPU_ARCH_FLAG from Makefile.inc)
NVCCFLAGS     = ${UCFLAGS} ${OPTIMISE} ${GPU_ARCH_FLAG} -lineinfo --machine 64
CFLAGS        = ${UCFLAGS} -fPIC ${OPTIMISE} ${DEBUG}

OBJECTS   = ${OBJ_DIR}/kernels.o
EXE_FILES = ${BIN_DIR}/peasoup

all: directories ${OBJECTS} ${EXE_FILES}

# ----- Object build rules -----

${OBJ_DIR}/kernels.o: ${SRC_DIR}/kernels.cu | directories
	${NVCC} -c ${NVCCFLAGS} ${INCLUDE} $< -o $@

# ----- Executables -----

${BIN_DIR}/peasoup: ${SRC_DIR}/pipeline_multi.cu ${SRC_DIR}/utils.cpp ${OBJECTS} | directories
	${NVCC} ${NVCCFLAGS} ${INCLUDE} ${LIBS} $^ -o $@

# ----- Utilities -----

directories:
	@mkdir -p ${BIN_DIR}
	@mkdir -p ${OBJ_DIR}

clean:
	@rm -f ${OBJ_DIR}/*.o

distclean: clean
	@rm -f ${BIN_DIR}/peasoup

install: all
	@mkdir -p ${INSTALL_DIR}/bin
	install -m 0755 $(BIN_DIR)/peasoup $(INSTALL_DIR)/bin/peasoup
	@echo "Installed to $(INSTALL_DIR)/bin"

print-vars:
	@echo "CUDA_DIR     = $(CUDA_DIR)"
	@echo "DEDISP_DIR   = $(DEDISP_DIR)"
	@echo "THRUST_DIR   = $(THRUST_DIR)"
	@echo "INSTALL_DIR  = $(INSTALL_DIR)"
	@echo "GPU_ARCH_FLAG= $(GPU_ARCH_FLAG)"
	@echo "UCFLAGS      = $(UCFLAGS)"
	@echo "NVCC         = $(NVCC)"
	@echo "CXX          = $(CXX)"
