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
            substituteInPlace Makefile \
              --replace 'CONFIG_FLAGS = -DCMAKE_VERBOSE_MAKEFILE=1' \
              'CONFIG_FLAGS = -DCMAKE_VERBOSE_MAKEFILE=1 -DCMAKE_POLICY_VERSION_MINIMUM=3.5'
          '';
        });

        petsc = (pkgs.petsc.override {
          withFullDeps = true;
          inherit parmetis;
        }).overrideAttrs (_old: {
          version = "3.24.3";
          src = pkgs.fetchzip {
            url = "https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-3.24.3.tar.gz";
            hash = "sha256-acrNcCTcjC4iLZD0lYvRhidnRTWsXs57XIQmZWKYIMg=";
          };
        });

        pflotran = import ./pkgs/pflotran { inherit system stdenv pkgs petsc; };
      in
      {
        packages = {
          default = pflotran;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            petsc
          ];
          shellHook = ''
            export PETSC_DIR=${petsc}
            export PETSC_ARCH=${system}
          '';
          # export LDSHARED="$CC -bundle -undefined dynamic_lookup"
          # export PFLOTRAN_DIR=${pflotran}
          # export MPIEXEC=${mpi}/bin/mpiexec
        };
      }
    );
}
