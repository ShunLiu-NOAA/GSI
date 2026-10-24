# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NOAA-EMC GSI (Gridpoint Statistical Interpolation) and EnKF data assimilation systems. Fortran 90 (some `.F90` preprocessed, a little C), MPI-parallel, built with CMake against NCEP libraries (BUFR, CRTM, IP, SP, W3EMC, NCIO, NCDIAG, WRF_IO, ...) supplied through Lmod modules on NOAA HPC machines. See `INSTALL.md` for dependency versions and all CMake options.

`fix/` is a git submodule (NOAA-EMC/GSI-fix) holding static fix files (CRTM coefficients, satinfo/convinfo, background-error stats). Run `git submodule update --init` if it's empty.

## Building

Standard build on a supported HPC machine (Hera, Ursa, Orion, Hercules, GaeaC6, WCOSS2/Acorn, Nimbus, NOAA cloud):

```bash
./ush/build.sh            # detects machine, loads modulefiles/gsi_<machine>.<compiler>.lua, configures, builds, installs
```

Things `ush/build.sh` does by default that you should know about:
- It **deletes and recreates `build/`** unless `BUILD_CLEAN=NO`.
- It builds `GSI_MODE=Regional` and `ENKF_MODE=GFS`. These are the modes the regression suite expects.
- It enables regression tests with `CONTROLPATH=$DIR_ROOT/../develop/install/bin`, which means it expects a sibling clone named `develop` that is already built and installed. Those control executables are the baseline the tests compare against.
- It installs to `install/` (`install/bin/gsi.x`, `install/bin/enkf.x`).

Env overrides: `BUILD_TYPE` (Release|Debug), `COMPILER` (default intel), `GSI_MODE`, `ENKF_MODE`, `REGRESSION_TESTS=NO`, `BUILD_JOBS`, `BUILD_VERBOSE`, `CMAKE_OPTS`, `BUILD_DIR`, `INSTALL_PREFIX`.

Incremental rebuild after editing source (does not wipe the build dir): `cd build && make -j8 && make install`.

Manual configure (this is what CI does, on Ubuntu with spack deps; see `.github/workflows/`):
```bash
mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=../install -DGSI_MODE=Regional -DENKF_MODE=GFS -DBUILD_REG_TESTING=OFF ..
make -j8 && make install
```

### Adding source files
Sources are listed explicitly. New files must go into `src/gsi/gsi_files.cmake` or `src/enkf/enkf_files.cmake`, in the correct list:
- GSI: `GSI_SRC_srcs` is the common code. The `GSI_MODE` choice picks one of two parallel sets: `GSI_SRC_gfs_stub` + `gsi_fixture_GFS.F90` for GFS, or `GSI_SRC_regional_cplr` + `gsi_fixture_REGIONAL.F90` for Regional. Each `class_*.f90` interface (WRF I/O, regional ensemble perturbations) has a `stub_*.f90` (GFS) and a `cplr_*.f90` (Regional) implementation, so an interface change has to be made in all three files.
- EnKF: `EnKF_SRC_srcs` is the common code. Model-specific `gridinfo_*`, `gridio_*`, `smooth_*` and `observer_*` files are selected by `ENKF_MODE` (`GFS`, `WRF`, `NMMB`, `FV3REG`) through the `EnKF_SRC_<MODE>` lists.

Optional libraries: `src/mgbf` (multigrid beta filter, `BUILD_MGBF` default ON) and `src/GSD` (GSD cloud analysis, `BUILD_GSDCLOUD` default OFF; when ON it defines `RR_CLOUDANALYSIS`).

## Regression tests

There are no fast unit tests. `unit-tests/` (pFUnit) is not wired into the build; its `add_subdirectory` is commented out. Code changes are validated with the regression suite, which runs this build ("updat") against the control build ("contrl") on real cases and checks the results. It only works on supported HPC machines, because it submits batch jobs and reads case data from `casesdir`.

```bash
cd build
ctest                        # all tests: global_4denvar, rtma, rrfs_3denvar_rdasens, hafs_4denvar_glbens, hafs_3denvar_hybens, global_enkf (or rrfs_enkf_conv when ENKF_MODE=FV3REG)
ctest -R rtma                # a single test
ctest -R rtma --output-on-failure
```

How it works:
- `regression/CMakeLists.txt` writes `build/regression/regression_var.out`, which records the paths to the update and control executables. Each ctest entry runs `regression_driver.sh <test> <build/regression>`.
- `regression_driver.sh` sources `regression_var.sh`, which holds machine detection, queue/account, `ptmp`, `noscrub` and `casesdir`. It then sources `regression_param.sh`, which sets per-test core counts and the batch submit command. After that it submits 4 jobs through `ush/sub_<machine>`: `loproc_updat`, `hiproc_updat`, `loproc_contrl`, `hiproc_contrl`. `RSTART`/`REND` limit which of the 4 run.
- Each test script, `regression/<test>.sh`, stages data and gets its namelist from `regression_namelists.sh` (or `regression_namelists_db.sh` for debug). When you add a namelist option that a test needs, update these files.
- `regression_test.sh` / `regression_test_enkf.sh` compare the runs. They check that the analysis output is bitwise reproducible (`cmp`) between updat and contrl and between the low- and high-processor-count runs. They also check runtime against `maxtime` and compare memory and penalty values. A change that is not meant to alter results should pass bitwise.

To run on a new machine or account, edit the machine case in `regression/regression_var.sh` and add matching `modulefiles/gsi_<machine>.<compiler>.lua` and `ush/sub_<machine>`.

## Code architecture

**GSI (`src/gsi`, ~650 files, flat directory).** The entry point is `gsimain.f90`. It calls `gsimod.F90`, which declares and reads every run-time namelist (`SETUP`, `GRIDOPTS`, `BKGERR`, `ANBKGERR`, `JCOPTS`, `STRONGOPTS`, `OBSQC`, `OBS_INPUT`, `SINGLEOB_TEST`, `SUPEROB_RADAR`, `LAG_DATA`, `HYBRID_ENSEMBLE`, `RAPIDREFRESH_CLDSURF`, `CHEM`, `NST`, ...), and then hands control to `glbsoi.f90`, the outer-loop driver. The flow is: read guess and set up observers (`observer_*`, `read_obs.F90` dispatching to the `read_<instrument>.f90` readers) → set up background error and balance (`berror`, `anberror`, `balmod`, `prewgt*`), plus the hybrid ensemble when `l_hyb_ens` is set (`hybrid_ensemble_*`, `get_*_ensperts`) → per outer loop, compute innovations (`setuprhsall.f90` → `setup<obtype>.f90`), then minimize (`pcgsoi.f90` and related solvers) → write the analysis (`write_all`).

Adding or changing an observation type usually touches all of these together:
- `read_<type>.f90`, plus registering it in `read_obs.F90`
- `setup<type>.f90`, where innovations, QC and the diag file are produced
- `int<type>.f90` and `stp<type>.f90`, the adjoint/TL observation operator and its line-search step
- `gsi_<type>Oper.F90` and `m_<type>Node.F90`, the obOper class and the obs-node linked-list storage, registered in `gsi_obOperTypeManager.F90`
- `obsmod.F90`, which holds obs-type flags and counts
- the info tables in `fix/` (convinfo/satinfo/...)

Model-specific I/O is split across many files, for example `read_guess`, `gsi_rfv3io_mod` (FV3-LAM regional), `general_read_gfsatm`, `netcdfgfs_io`, and the WRF class/cplr/stub files. Control variables and state variables come from the `anavinfo` text file at run time (`control_vectors`, `state_vectors`, `gsi_metguess_mod`, `gsi_chemguess_mod`), not from compile-time constants.

**EnKF (`src/enkf`).** The entry point is `enkf_main.f90`. Namelist parameters live in `params.f90`. Observation priors are read from GSI diag files (`readconvobs`, `readsatobs`, `readozobs`, `mpi_readobs`). The update is `enkf.f90` (serial EnSRF) or `letkf.f90` (LETKF), followed by `inflation.f90`. All model I/O goes through the `gridio_<model>` / `gridinfo_<model>` interface, so adding a model means adding a new file set and an `ENKF_MODE`. The EnKF links against the GSI library (`enkf/CMakeLists.txt`), so GSI module changes can break the EnKF build.

## Conventions

From `.github/pull_request_template.md`:
- Each PR covers one topic and has an associated GitHub issue.
- No hardcoded personal-directory paths. Note that `regression_var.sh` and `build.sh` contain machine paths that people often edit locally; keep those edits out of commits.
- No temporary or backup files.
- Remove commented-out code rather than leaving it disabled.

Fortran style follows the surrounding file. Most routines start with a documentation prologue (`subprogram`, `prgmmr`, `abstract`, `program history log`, `input argument list`). When you modify a routine, add a dated entry to its history log the same way existing entries do. Real kinds come from the `kinds` module (`r_kind`, `i_kind`, and so on). Do not use bare `real`/`integer` kinds.
