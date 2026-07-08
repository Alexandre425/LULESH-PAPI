# LULESH 2.0 — Agent Context

## Overview

LULESH (Livermore Unstructured Lagrangian Explicit Shock Hydrodynamics) is a proxy
application that models the Sedov blast wave problem on a hexahedral mesh. This
fork adds PAPI High-Level profiling instrumentation for hardware-counter
measurement of the major computational kernels.

## File layout

| File | Role |
|---|---|
| `lulesh.cc` | Time-stepping loop and all computational kernels (force, kinematics, Q, EOS, volume, time constraints) |
| `lulesh-comm.cc` | MPI communication routines (pack/unpack ghosts, edge/face/corner exchanges) |
| `lulesh-init.cc` | Mesh generation, domain decomposition, initial conditions |
| `lulesh-viz.cc` | SILO/VisIt output |
| `lulesh-util.cc` | Command-line parsing, verification, FOM output |
| `lulesh.h` | `Domain` class — all mesh data (nodes, elements, regions) |
| `lulesh_tuple.h` | Tuple-based Domain alternative (unused by default) |

## Build

Two build systems; both now require `libpapi`:

```sh
# Makefile  (serial + OpenMP)
make CXX=g++ CXXFLAGS="-g -O3 -fopenmp -I. -Wall -DUSE_MPI=0" \
         LDFLAGS="-g -O3 -fopenmp -lpapi"

# Makefile  (MPI + OpenMP)
make CXX=mpicxx CXXFLAGS="-g -O3 -fopenmp -I. -Wall -DUSE_MPI=1" \
         LDFLAGS="-g -O3 -fopenmp -lpapi"

# CMake
```sh
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release \
      -DMPI_CXX_COMPILER=`which mpicxx` ..
make
```

The default Makefile target builds the MPI+OpenMP binary via `mpig++`; on systems
where only `mpicxx` is available, override `CXX=mpicxx`.

## PAPI HL instrumentation (fork addition)

Six region-of-interest markers were added to `lulesh.cc` using the PAPI
High-Level API (`PAPI_hl_region_begin`/`end`).  Most are placed **inside**
`#pragma omp parallel` blocks so that every thread records its own hardware
counter deltas (instructions, cycles, cache misses, FLOPs, etc.).

### Per-thread regions (accurate hardware counters)

| Region name | Function instrumented | Work covered |
|---|---|---|
| `CalcKinematics` | `CalcKinematicsForElems` | Element velocity gradient, volume, char. length |
| `CalcMonotonicQGradients` | `CalcMonotonicQGradientsForElems` | Velocity gradients for artificial viscosity |
| `CalcMonotonicQRegion` | `CalcMonotonicQRegionForElems` | Per-region monotonic Q (artificial viscosity) |
| `EvalEOS_setup` | `EvalEOSForElems` rep loop | Data compress/check before EOS evaluation |
| `UpdateVolumes` | `UpdateVolumesForElems` | Relative volume update |

### Serial wrapper (master-thread wall-clock timing only)

| Region name | Function instrumented | Note |
|---|---|---|
| `LagrangeNodal` | `LagrangeNodal` (in `LagrangeLeapFrog`) | MPI communication is intertwined with parallel work; hardware counters reflect the master thread only |

### Build dependencies

- `libpapi` (development headers + shared library)
- `pkg-config` or standard library path for `-lpapi` link

## Time-stepping structure

The main loop in `main()` calls `LagrangeLeapFrog()` each cycle, which
orchestrates:

1. **LagrangeNodal** — force computation (stress integration, hourglass),
   acceleration, velocity, position updates, MPI boundary exchanges
2. **LagrangeElements** — kinematics, artificial viscosity (Q), EOS evaluation,
   volume update
3. **CalcTimeConstraints** — Courant and hydro timestep constraints

Each of these phases is further decomposed into element-wise and node-wise
parallel loops.

## Key conventions

- `Index_t` = `Int4_t` (32-bit) — used for array subscripts and loop indices
- `Real_t` = `double` (64-bit) — floating point representation
- OpenMP parallelism via `#pragma omp parallel for` inside each kernel function
- MPI is guarded by `#if USE_MPI` / `#endif` blocks throughout
- Regions (11 by default) group elements for non-unit-stride memory access and
  load imbalance
