{ pkgs, zigMusl }:
pkgs.runCommand "lsr-cache" {
  nativeBuildInputs = [ zigMusl ];
} ''
  export ZIG_LOCAL_CACHE_DIR=$out
  export ZIG_GLOBAL_CACHE_DIR=$out
  zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl --summary none
''
