# Build targets: make mpi, make openmp, make serial, make all (builds all three)
# Default: make (builds all three binaries)

SHELL = /bin/sh
.SUFFIXES: .cc .o
.DEFAULT_GOAL := all

LULESH_EXEC_MPI = lulesh2.0
LULESH_EXEC_OPENMP = lulesh2.0.openmp
LULESH_EXEC_SERIAL = lulesh2.0.serial
LULESH_EXEC_PAPI_MPI = lulesh2.0.papi
LULESH_EXEC_PAPI_OPENMP = lulesh2.0.papi.openmp
LULESH_EXEC_PAPI_SERIAL = lulesh2.0.papi.serial

# Compilers — mpicxx wraps the right MPI flags automatically.
MPICXX = mpicxx
SERCXX = g++
CC = gcc

CARM_DYNAMORIO_DIR = ../../carm_roofline/native/dynamorio
CARM_MARKER_OBJECT = carm_region_timing.o

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
PAPI_MPI_OBJECTS = $(SOURCES2.0:.cc=_papi_mpi.o)
PAPI_SERIAL_OBJECTS = $(SOURCES2.0:.cc=_papi_serial.o)
PAPI_OPENMP_OBJECTS = $(SOURCES2.0:.cc=_papi_openmp.o)
# MPI + OpenMP build flags
MPI_CXXFLAGS = -DUSE_MPI=1 -g -O3 -fopenmp -I. -I$(CARM_DYNAMORIO_DIR) -Wall
MPI_LDFLAGS = -g -O3 -fopenmp -pthread -rdynamic

# Serial (no MPI) build flags
SERIAL_CXXFLAGS = -DUSE_MPI=0 -g -O3 -I. -I$(CARM_DYNAMORIO_DIR) -Wall
SERIAL_LDFLAGS = -g -O3 -pthread -rdynamic

# OpenMP-only (no MPI) build flags
OPENMP_CXXFLAGS = -DUSE_MPI=0 -g -O3 -fopenmp -I. -I$(CARM_DYNAMORIO_DIR) -Wall
OPENMP_LDFLAGS = -g -O3 -fopenmp -pthread -rdynamic
PAPI_MPI_CXXFLAGS = $(MPI_CXXFLAGS) -DCARM_ENABLE_PAPI=1
PAPI_SERIAL_CXXFLAGS = $(SERIAL_CXXFLAGS) -DCARM_ENABLE_PAPI=1
PAPI_OPENMP_CXXFLAGS = $(OPENMP_CXXFLAGS) -DCARM_ENABLE_PAPI=1
PAPI_LDFLAGS = -lpapi

$(CARM_MARKER_OBJECT): $(CARM_DYNAMORIO_DIR)/carm_region_timing.c $(CARM_DYNAMORIO_DIR)/carm_region.h
	$(CC) -std=c11 -pthread -I$(CARM_DYNAMORIO_DIR) -c -o $@ $<
%_mpi.o: %.cc lulesh.h $(CARM_DYNAMORIO_DIR)/carm_region.h
	@echo "Building MPI $<"
	$(MPICXX) -c $(MPI_CXXFLAGS) -o $@ $<

%_serial.o: %.cc lulesh.h $(CARM_DYNAMORIO_DIR)/carm_region.h
	@echo "Building serial $<"
	$(SERCXX) -c $(SERIAL_CXXFLAGS) -o $@ $<

%_openmp.o: %.cc lulesh.h $(CARM_DYNAMORIO_DIR)/carm_region.h
	@echo "Building OpenMP $<"
	$(SERCXX) -c $(OPENMP_CXXFLAGS) -o $@ $<

%_papi_mpi.o: %.cc lulesh.h $(CARM_DYNAMORIO_DIR)/carm_region.h
	@echo "Building MPI + PAPI $<"
	$(MPICXX) -c $(PAPI_MPI_CXXFLAGS) -o $@ $<

%_papi_serial.o: %.cc lulesh.h $(CARM_DYNAMORIO_DIR)/carm_region.h
	@echo "Building serial + PAPI $<"
	$(SERCXX) -c $(PAPI_SERIAL_CXXFLAGS) -o $@ $<

%_papi_openmp.o: %.cc lulesh.h $(CARM_DYNAMORIO_DIR)/carm_region.h
	@echo "Building OpenMP + PAPI $<"
	$(SERCXX) -c $(PAPI_OPENMP_CXXFLAGS) -o $@ $<

all: mpi openmp serial

.PHONY: all mpi openmp serial papi papi-mpi papi-openmp papi-serial clean tar

mpi: $(LULESH_EXEC_MPI)
openmp: $(LULESH_EXEC_OPENMP)
serial: $(LULESH_EXEC_SERIAL)
papi: papi-mpi papi-openmp papi-serial
papi-mpi: $(LULESH_EXEC_PAPI_MPI)
papi-openmp: $(LULESH_EXEC_PAPI_OPENMP)
papi-serial: $(LULESH_EXEC_PAPI_SERIAL)

$(LULESH_EXEC_MPI): $(MPI_OBJECTS) $(CARM_MARKER_OBJECT)
	@echo "Linking MPI"
	$(MPICXX) $(MPI_OBJECTS) $(CARM_MARKER_OBJECT) $(MPI_LDFLAGS) -lm -o $@

$(LULESH_EXEC_PAPI_MPI): $(PAPI_MPI_OBJECTS) $(CARM_MARKER_OBJECT)
	@echo "Linking MPI + PAPI"
	$(MPICXX) $(PAPI_MPI_OBJECTS) $(CARM_MARKER_OBJECT) $(MPI_LDFLAGS) $(PAPI_LDFLAGS) -lm -o $@

$(LULESH_EXEC_PAPI_OPENMP): $(PAPI_OPENMP_OBJECTS) $(CARM_MARKER_OBJECT)
	@echo "Linking OpenMP + PAPI"
	$(SERCXX) $(PAPI_OPENMP_OBJECTS) $(CARM_MARKER_OBJECT) $(OPENMP_LDFLAGS) $(PAPI_LDFLAGS) -lm -o $@

$(LULESH_EXEC_PAPI_SERIAL): $(PAPI_SERIAL_OBJECTS) $(CARM_MARKER_OBJECT)
	@echo "Linking serial + PAPI"
	$(SERCXX) $(PAPI_SERIAL_OBJECTS) $(CARM_MARKER_OBJECT) $(SERIAL_LDFLAGS) $(PAPI_LDFLAGS) -lm -o $@
$(LULESH_EXEC_OPENMP): $(OPENMP_OBJECTS) $(CARM_MARKER_OBJECT)
	@echo "Linking OpenMP"
	$(SERCXX) $(OPENMP_OBJECTS) $(CARM_MARKER_OBJECT) $(OPENMP_LDFLAGS) -lm -o $@

$(LULESH_EXEC_SERIAL): $(SERIAL_OBJECTS) $(CARM_MARKER_OBJECT)
	@echo "Linking serial"
	$(SERCXX) $(SERIAL_OBJECTS) $(CARM_MARKER_OBJECT) $(SERIAL_LDFLAGS) -lm -o $@


clean:
	/bin/rm -f *_mpi.o *_serial.o *_openmp.o $(CARM_MARKER_OBJECT) *~ $(LULESH_EXEC_MPI) $(LULESH_EXEC_SERIAL) $(LULESH_EXEC_OPENMP) $(LULESH_EXEC_PAPI_MPI) $(LULESH_EXEC_PAPI_OPENMP) $(LULESH_EXEC_PAPI_SERIAL)
	/bin/rm -rf *.dSYM

tar: clean
	cd .. && tar cvf lulesh-2.0.tar LULESH-2.0 && mv lulesh-2.0.tar LULESH-2.0
