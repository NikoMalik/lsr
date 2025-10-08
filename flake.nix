{
  inputs = {
    utils.url = "github:numtide/flake-utils/main";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem(system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgsMusl = import nixpkgs {
          inherit system;
          config = {
            stdenv = nixpkgs.legacyPackages.${system}.pkgsMusl.stdenv;
          };
        };
        # Pre-fetch Git dependencies
        ourio = pkgs.fetchFromGitHub {
          owner = "NikoMalik";
          repo = "ourio";
          rev = "6f7582f0d50f4604624599c563bbfa425346fd73";
          hash = "sha256-04bvcb96x0zi6w79wqxpqvlgk66zhkifgs1j1dnp2vw6jswpvwcx";
        };
        zeit = pkgs.fetchFromGitHub {
          owner = "rockorager";
          repo = "zeit";
          rev = "ade14edb2025f5e4a57b683f81c915f70a904e88";
          hash = "sha256-18zckqq0x5l7bz3sh4ybsgr5j2chnq3wp4r38lci79gnv4ba0yga";
        };
        zzdoc = pkgs.fetchFromGitHub {
          owner = "rockorager";
          repo = "zzdoc";
          rev = "a54223bdc13a80839ccf9f473edf3a171e777946";
          hash = "sha256-1bkjbvxg51hccs5xhkk1zg5gvnnii0pzq6rzix4g443fxwfrj864";
        };
      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ zig zls ];
        };
        packages.default = pkgsMusl.stdenv.mkDerivation {
          pname = "lsr";
          version = "1.0.0";
          doCheck = false;
          src = ./.;
          nativeBuildInputs = with pkgs; [ zig ];
          buildInputs = [ ourio zeit zzdoc ];
          postPatch = ''
            substituteInPlace build.zig.zon \
              --replace-fail 'git+https://github.com/NikoMalik/ourio#6f7582f0d50f4604624599c563bbfa425346fd73' "file://${ourio}" \
              --replace-fail 'git+https://github.com/rockorager/zeit#ade14edb2025f5e4a57b683f81c915f70a904e88' "file://${zeit}" \
              --replace-fail 'git+https://github.com/rockorager/zzdoc#a54223bdc13a80839ccf9f473edf3a171e777946' "file://${zzdoc}"
          '';
          buildPhase = ''
            export ZIG_GLOBAL_CACHE_DIR=$TMPDIR/zig-cache
            mkdir -p $ZIG_GLOBAL_CACHE_DIR
            zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl  --summary all
          '';
          installPhase = ''
            install -Ds -m755 zig-out/bin/lsr $out/bin/lsr
          '';
        };
        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/lsr";
        };
      });
}
