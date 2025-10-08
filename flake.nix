{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        zigMusl = pkgs.zig.overrideAttrs (old: {
          buildInputs = [ pkgs.musl ];
          configurePhase = ''
            export ZIG_LOCAL_CACHE_DIR=$TMPDIR/zig-cache
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-global-cache
            export CC="${pkgs.musl.dev}/bin/musl-gcc"
            export CFLAGS="-static"
          '';
        });
        cache = import ./nix/cache.nix { inherit pkgs zigMusl; };
      in {
        packages.default = pkgs.runCommand "lsr" {
          nativeBuildInputs = [ zigMusl ];
        } ''
          export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
          ln -sf ${cache} $ZIG_GLOBAL_CACHE_DIR/p
          zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl --summary all
          mkdir -p $out/bin
          install -m755 zig-out/bin/lsr $out/bin/lsr
        '';
      });
}
