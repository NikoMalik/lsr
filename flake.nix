{
  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
  };
  outputs =
    { zig2nix, ... }:
    let
      flake-utils = zig2nix.inputs.flake-utils;
    in
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        zig-env = zig2nix.outputs.zig-env.${system} {
          zig = zig2nix.outputs.packages.${system}.zig-0_15_2; # Zig version
        };
        zig-apps = zig2nix.outputs.apps.${system};
        pkgs = zig-env.pkgs;
      in
      rec {
        # NOTE: You must first generate build.zig.zon2json-lock using nix run .#zon2lock
        #       It is recommended to commit the build.zig.zon2json-lock to your repo.
        packages.default = zig-env.package rec {
          src = zig-env.pkgs.lib.cleanSource ./.;

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [ ];

          zigPreferMusl = false;

          zigBuildFlags = [ "-Doptimize=ReleaseFast" ];

          # Binaries available to the binary during runtime (PATH)
          zigWrapperBins = with pkgs; [ ];
          # Libraries available to the binary during runtime (LD_LIBRARY_PATH)
          zigWrapperLibs = buildInputs;
          # Additional arguments to makeWrapper.
          zigWrapperArgs = with pkgs; [ ];

          zigBuildZonLock = ./build.zig.zon2json-lock;
        };

        # nix develop
        devShells.default = zig-env.mkShell {
          nativeBuildInputs = with pkgs; [ zls ];
        };

        # nix run .#test
        apps.test = zig-env.app [ ] ''
          tmpdir="$(mktemp -d)"
          trap 'rm -rf "$tmpdir"' EXIT
          zig build
          echo "testing zig"
          zig build test -- "$@"
        '';

        # nix run .#zon2lock
        apps.zon2lock = zig-apps.zon2json-lock;

        # NOTE: No docs yet
        # nix run .#docs
        apps.docs = zig-env.app [ ] "zig build docs -- \"$@\"";
      }
    ));
}
