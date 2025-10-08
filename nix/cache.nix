{ pkgs, zigMusl }:
pkgs.runCommand "lsr-cache" {
  nativeBuildInputs = [ zigMusl ];
} ''
  export ZIG_LOCAL_CACHE_DIR=$(mktemp -d)
  export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
  zig build --fetch --summary none -Dtarget=x86_64-linux-musl
  mv $ZIG_GLOBAL_CACHE_DIR/p $out
''
