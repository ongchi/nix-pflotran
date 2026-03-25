{ stdenv, pkgs, system, petsc, withParmetis ? false }:

stdenv.mkDerivation (finalAttrs: {
  pname = "pflotran";
  version = "7.0-unstable-2026-03-14";

  src = pkgs.fetchgit {
    url = "https://bitbucket.org/pflotran/pflotran.git";
    rev = "564b6875eac1ab9da3217bc801bb9972ab5dfee0";
    sha256 = "sha256-uE5TVF4J1cZmItKd4ZAbAuvO2F8i1sDaKTSk6RB0Fo8=";
  };

  prePatch =
    let
      ldflags = "-lhdf5_hl -lhdf5_hl_fortran";
    in
    ''
      substituteInPlace src/pflotran/makefile \
        --replace '# the petsc configured in $PETSC_DIR/$PETSC_ARCH' \
        'LIBS =  ${ldflags}'
      substituteInPlace regression_tests/Makefile \
        --replace 'PFLOTRAN = ../src/pflotran/pflotran' \
        'PFLOTRAN = $(out)/bin/pflotran'
      substituteInPlace regression_tests/Makefile \
        --replace '	TEST_OPTIONS += --mpiexec $(MPIEXEC)' \
        '	TEST_OPTIONS += --mpiexec ${petsc.petscPackages.mpi}/bin/mpiexec'
    '';

  # patches = [ ./ec_dataset.patch ];

  propagatedBuildInputs = [ petsc ];

  enableParallelBuilding = true;

  configureFlags = [
    "--with-petsc-dir=${petsc}"
    "--with-petsc-arch=${system}"
    "--prefix=$(out)"
  ];

  makeFlags = [
    "FC_DEFINE_FLAG=-D"
    "have_hdf5=1"
    "HDF5_INCLUDE=${petsc.petscPackages.hdf5.dev}/include"
    "HDF5_LIB=${petsc.petscPackages.hdf5}/lib"
  ];

  preConfigure = ''
    patchShebangs configure
  '';

  # TODO: Test log printing should probably be done better
  passthru = {
    inherit withParmetis;
    # h5py = petsc.python3.pkgs.h5py.override { inherit (petsc) hdf5; };
    tests = {
      main =
        let
          pythonWithH5py = petsc.python3.withPackages (_: [ finalAttrs.passthru.h5py ]);
          # TODO: Should clean the environment variables set inside the script. Not sure what is necessary.
          # TODO: Some tests fail because petsc is not compiled with hypre which is not packaged in nixpkgs
        in
        pkgs.runCommand "pflotran-main-test" { } ''
          tmpdir=$(mktemp -d -u)
          cp -r -L ${finalAttrs.src} $tmpdir
          chmod -R 777 $tmpdir
          cd $tmpdir/regression_tests

          export PATH=$PATH:${pkgs.openssh}/bin
          # Fix to make mpich run in a sandbox
          export OMP_NUM_THREADS=1
          export HYDRA_IFACE=lo
          export OMPI_MCA_rmaps_base_oversubscribe=1
          export OMPI_MCA_btl="vader,self"

          ${pythonWithH5py}/bin/python regression_tests.py -e ${finalAttrs.finalPackage}/bin/pflotran \
              --suites standard standard_parallel \
              --mpiexec ${petsc.mpi}/bin/mpiexec \
              --recursive-search ./default ./general \
              --backtrace --debug ||
          echo "Test logs:" && \
          echo "" && \
          ${pkgs.busybox}/bin/find . -name '*.testlog' -exec ${pkgs.busybox}/bin/cat {} \; && \
          exit 1
          cp -L $tmpdir $out
        '';
    };
  };

  doCheck = false;
  # checkPhase = let
  #   pythonWithH5py = python3.withPackages (p: with p; [ h5py ]);
  #   defaultConfigs = ''
  #     $(sed -n '/STANDARD_CFG =/,/ifneq ($(strip $(HYPRE_LIB)),)/{//!p;}' Makefile)
  #   '';
  # in ''
  #   runHook preCheck
  #   cd /build/source/regression_tests

  #   export PATH=$PATH:${pkgs.openssh}/bin
  #   # Fix to make mpich run in a sandbox
  #   export OMP_NUM_THREADS=1
  #   export HYDRA_IFACE=lo
  #   export OMPI_MCA_rmaps_base_oversubscribe=1

  #   ${pythonWithH5py}/bin/python regression_tests.py -e /build/source/src/pflotran/pflotran \
  #       --suites standard standard_parallel \
  #       --mpiexec ${mpi}/bin/mpiexec \
  #       --config-files ${defaultConfigs} \
  #       --backtrace --debug ||
  #   echo "Test logs:" && \
  #   echo "" && \
  #   ${pkgs.busybox}/bin/find . -name '*.testlog' -exec ${pkgs.busybox}/bin/cat {} \; && \
  #   exit 1
  #   runHook postCheck
  # '';

  mpiSupport = true;

  installPhase = ''
    mkdir -p $out/bin
    cp src/pflotran/pflotran $out/bin
    mkdir -p $out/share
    cp -R regression_tests $out/share/regression_tests
  '';
})
