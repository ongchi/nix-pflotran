{ stdenv, pkgs, gfortran, python3 }:


# # Remove warning print of code expiration date
# # and disable addmesh_add test as it is the only one failing
# patchedSrc = pkgs.runCommand "patched-src" { } ''
#   cp --dereference --no-preserve all --recursive ${inputs.lagrit-src} $out
#   substituteInPlace $out/src/writinit.f \
#       --replace "ishow_warn .eq. 1"  "ishow_warn .eq. 0"
#   substituteInPlace $out/test/runtests.py \
#       --replace "in test_dirs:"  "in filter(lambda test_dir: 'addmesh_add' not in test_dir, test_dirs):"
# '';

stdenv.mkDerivation rec {
  pname = "lagrit";
  version = "3.3.2";

  src = pkgs.fetchgit {
    url = "https://github.com/lanl/LaGriT.git";
    rev = "v${version}";
    sha256 = "sha256-lNHB7Y3WVpyMCx6qY94fHIV5LOKmBXoZsb8J1cubNyM=";
  };

  prePatch = ''
    substituteInPlace lg_util/src/Makefile --replace \
    'FFLAGS := -fcray-pointer -fdefault-integer-8' \
    'FFLAGS := -fallow-argument-mismatch -fcray-pointer -fdefault-integer-8'
  '';

  # TODO: To include Exodus, use -DLAGRIT_BUILD_EXODUS=ON
  # Exodus is from https://github.com/sandialabs/seacas but it is not packaged with nix
  nativeBuildInputs = [ gfortran pkgs.cmake ];

  buildInputs = [ python3 ];

  dontUseCmakeConfigure = true;

  makeFlags = [
    "WITH_EXODUS=0"
    "release"
  ];

  # TODO: Move to installCheckPhase
  # passthru = {
  #   src = patchedSrc;
  #   tests = pkgs.runCommand "lagrit-tests" { } ''
  #     mkdir $out
  #     ${lndir}/bin/lndir -silent ${patchedSrc}/test $out
  #     pushd $out
  #     ${python3}/bin/python3 runtests.py --executable ${self}/bin/lagrit --levels 1
  #     popd
  #   '';
  # };

  doInstallCheck = true;
  installCheckPhase = ''
    tmp_dir=$(mktemp -d)
    cp --dereference --no-preserve all --recursive ${src} $tmp_dir/src
    pushd $tmp_dir/src/test
    ${python3}/bin/python3 runtests.py --executable $out/bin/lagrit --levels 1
    popd
  '';
}
