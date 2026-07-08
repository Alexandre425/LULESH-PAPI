# Build targets: make mpi, make openmp, make serial, make all (builds all three)
# Default: make (builds all three binaries)

SHELL = /bin/sh
.SUFFIXES: .cc .o

LULESH_EXEC_MPI = lulesh2.0
LULESH_EXEC_OPENMP = lulesh2.0.openmp
LULESH_EXEC_SERIAL = lulesh2.0.serial

# Compilers — mpicxx wraps the right MPI flags automatically
MPICXX = mpicxx
SERCXX = g++

SOURCES2.0 = \
	lulesh.cc \
	lulesh-comm.cc \
	lulesh-viz.cc \
	lulesh-util.cc \
	lulesh-init.cc

# Separate object files so both builds coexist
MPI_OBJECTS = $(SOURCES2.0:.cc=_mpi.o)
SERIAL_OBJECTS = $(SOURCES2.0:.cc=_serial.o)
OPENMP_OBJECTS = $(SOURCES2.0:.cc=_openmp.o)
# MPI + OpenMP build flags
MPI_CXXFLAGS = -DUSE_MPI=1 -g -O3 -fopenmp -I. -Wall
MPI_LDFLAGS = -g -O3 -fopenmp -lpapi

# Serial (no MPI) build flags
SERIAL_CXXFLAGS = -DUSE_MPI=0 -g -O3 -I. -Wall
SERIAL_LDFLAGS = -g -O3 -lpapi

# Pattern rules

# OpenMP-only (no MPI) build flags
OPENMP_CXXFLAGS = -DUSE_MPI=0 -g -O3 -fopenmp -I. -Wall
OPENMP_LDFLAGS = -g -O3 -fopenmp -lpapi
%_mpi.o: %.cc lulesh.h
	@echo "Building MPI $<"
	$(MPICXX) -c $(MPI_CXXFLAGS) -o $@ $<

%_serial.o: %.cc lulesh.h
	@echo "Building serial $<"
	$(SERCXX) -c $(SERIAL_CXXFLAGS) -o $@ $<

%_openmp.o: %.cc lulesh.h
	@echo "Building OpenMP $<"
	$(SERCXX) -c $(OPENMP_CXXFLAGS) -o $@ $<

all: mpi openmp serial

.PHONY: all mpi openmp serial clean tar

mpi: $(LULESH_EXEC_MPI)
openmp: $(LULESH_EXEC_OPENMP)
serial: $(LULESH_EXEC_SERIAL)

$(LULESH_EXEC_MPI): $(MPI_OBJECTS)
	@echo "Linking MPI"
	$(MPICXX) $(MPI_OBJECTS) $(MPI_LDFLAGS) -lm -o $@

$(LULESH_EXEC_OPENMP): $(OPENMP_OBJECTS)
	@echo "Linking OpenMP"
	$(SERCXX) $(OPENMP_OBJECTS) $(OPENMP_LDFLAGS) -lm -o $@

$(LULESH_EXEC_SERIAL): $(SERIAL_OBJECTS)
	@echo "Linking serial"
	$(SERCXX) $(SERIAL_OBJECTS) $(SERIAL_LDFLAGS) -lm -o $@

clean:
	/bin/rm -f *_mpi.o *_serial.o *_openmp.o *~ $(LULESH_EXEC_MPI) $(LULESH_EXEC_SERIAL) $(LULESH_EXEC_OPENMP)
	/bin/rm -rf *.dSYM

tar: clean
	cd .. && tar cvf lulesh-2.0.tar LULESH-2.0 && mv lulesh-2.0.tar LULESH-2.0
