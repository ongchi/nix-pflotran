{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        stdenv = pkgs.stdenv;

        parmetis = pkgs.parmetis.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            sed -i 's/cmake_minimum_required(VERSION [0-9][^)]*)/cmake_minimum_required(VERSION 3.5)/' CMakeLists.txt
          '';
        });

        mkPetsc = { withParmetis ? false }:
          (pkgs.petsc.override ({
            withFullDeps = true;
            inherit withParmetis;
          } // pkgs.lib.optionalAttrs withParmetis {
            inherit parmetis;
          })).overrideAttrs (_old: {
            version = "3.24.3";
            src = pkgs.fetchzip {
              url = "https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-3.24.3.tar.gz";
              hash = "sha256-acrNcCTcjC4iLZD0lYvRhidnRTWsXs57XIQmZWKYIMg=";
            };
          });

        mkPflotran = { withParmetis ? false }:
          let petsc = mkPetsc { inherit withParmetis; };
          in import ./pkgs/pflotran { inherit system stdenv pkgs petsc withParmetis; };

        pflotran = mkPflotran { withParmetis = false; };
      in
      {
        packages = {
          default = pflotran;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pflotran.petsc
          ];
          shellHook = ''
            export PETSC_DIR=${pflotran.petsc}
            export PETSC_ARCH=${system}
          '';
          # export LDSHARED="$CC -bundle -undefined dynamic_lookup"
          # export PFLOTRAN_DIR=${pflotran}
          # export MPIEXEC=${mpi}/bin/mpiexec
        };
      }
    );
}
