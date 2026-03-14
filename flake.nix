{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
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

        petsc = (pkgs.petsc.override {
          withFullDeps = true;
        }).overrideAttrs (old: rec {
          version = "3.24.0";
          src = pkgs.fetchzip {
            url = "https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-3.24.0.tar.gz";
            hash = "sha256-5jqYTo5sfwLNByOlpry0zpI+q3u7ErwJJ97h7w5bvNQ=";
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
