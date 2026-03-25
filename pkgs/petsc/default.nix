{ stdenv, pkgs, system, gfortran, mpi, hdf5, python3, withParmetis ? false }:

stdenv.mkDerivation (finalAttrs:
let
  hdf5_dev = pkgs.symlinkJoin {
    name = "hdf5";
    paths = [ hdf5 hdf5.dev ];
  };
  # mpi_dev = pkgs.symlinkJoin {
  #   name = "mpi";
  #   paths = [ mpi mpi.dev ];
  # };
  mpi_dev = mpi;

  blas = pkgs.blas.override { inherit stdenv; };
  lapack = pkgs.lapack.override { inherit stdenv; };

  external_srcs = {
    f2cblaslapack = pkgs.fetchurl {
      url = "https://web.cels.anl.gov/projects/petsc/download/externalpackages/f2cblaslapack-3.8.0.q2.tar.gz";
      sha256 = "sha256-EvqNUAHjE67uoi6yBUiD9Z4+PGVvERKfMauwLdv4rWA=";
    };

    metis = pkgs.fetchurl {
      url = "https://bitbucket.org/petsc/pkg-metis/get/v5.1.0-p11.tar.gz";
      sha256 = "sha256-A2A8oZFmk2TIpB6bK5lSJuFg/irKJjPm/NKnYC74QR8=";
    };

    parmetis = pkgs.fetchurl {
      url = "https://bitbucket.org/petsc/pkg-parmetis/get/v4.0.3-p9.tar.gz";
      sha256 = "sha256-YScX6FmSyYTwmw9WcL5CG7uQpMBBRatbmjNYuSdl2JE=";
    };

    hypre = pkgs.fetchurl {
      url = "https://github.com/hypre-space/hypre/archive/v2.29.0.tar.gz";
      sha256 = "sha256-mLchFUB6DiTbqscOzK4No0Zfj5mTGLLJJBYxEz9C1RE=";
    };

    viennacl = pkgs.fetchurl {
      url = "https://github.com/viennacl/viennacl-dev/archive/dc552a8.tar.gz";
      sha256 = "sha256-5zbdhYuR2O3HQNZHHgOwamgvErPxNvs6sI0iAVGOf1c=";
    };
  };
in
rec {
  pname = "petsc";
  version = "3.21.5";

  src = pkgs.fetchurl {
    url = "https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-${version}.tar.gz";
    hash = "sha256-TrHsBMGomIvVJPcfjX2YDcGFPVvoeRwPGfPAnu9x/dI=";
  };

  nativeBuildInputs = [ gfortran pkgs.cmake ];

  buildInputs = [ blas lapack python3 ];

  propagatedBuildInputs = [ mpi hdf5 ];

  dontUseCmakeConfigure = true;

  preConfigure = ''
    patchShebangs ./lib/petsc/bin
  '';

  configureFlags = [
    "--with-mpi=1"
    "--with-mpi-dir=${mpi_dev}"
    "--with-blas=1"
    "--with-lapack=1"
    "--with-hdf5=1"
    "--with-hdf5-dir=${hdf5_dev}"
    "--download-f2cblaslapack=${external_srcs.f2cblaslapack}"
    "--download-metis=${external_srcs.metis}"
  ] ++ pkgs.lib.optionals withParmetis [
    "--download-parmetis=${external_srcs.parmetis}"
  ] ++ [
    "--download-hypre=${external_srcs.hypre}"
    "--download-viennacl=${external_srcs.viennacl}"
    "CXXFLAGS=-Wall -Wwrite-strings -Wno-strict-aliasing -Wno-unknown-pragmas -fstack-protector -fno-stack-check -Wno-deprecated -fvisibility=hidden"
    "--with-debugging=0"
    "--with-strict-petscerrorcode"
    "--with-petsc-arch=${system}"
    "--with-shared-libraries=0"
  ];

  # postPatch = ''
  #   substituteInPlace config/BuildSystem/config/base.py \
  #     --replace "return not (returnCode or len(output))" \
  #     "return True"
  # '';

  doCheck = false;

  mpiSupport = true;

  enableParallelBuilding = true;

  passthru = {
    hdf5 = hdf5_dev;
    mpi = mpi_dev;
    inherit system gfortran python3 external_srcs withParmetis;
  };
}
)
