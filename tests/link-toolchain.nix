{ pkgs }:
let
  # Inspect the real application's stdenv without building Qt or translating IR.
  target = import ../. {
    inherit pkgs;
    self = { };
    lib = pkgs.lib // {
      mkCppLibrary = _: {
        mkDerivation = _: pkgs.emptyDirectory;
      };
    };
  };
  app = target.buildApplication { meta.name = "link-toolchain-check"; };
  inherit (app) stdenv;
  inherit (pkgs) lib;
  expectLld =
    stdenv.hostPlatform.isLinux
    && (
      stdenv.hostPlatform.isx86
      || stdenv.hostPlatform.isAarch64
      || stdenv.hostPlatform.isAarch32
      || stdenv.hostPlatform.isRiscV64
    )
    && pkgs.stdenv.cc.isGNU
    && pkgs.stdenv.cc.bintools.isGNU
    && !pkgs.stdenv.cc.bintools.nativeTools;
  canExecute = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  answer = pkgs.runCommandCC "link-toolchain-answer" { } ''
    mkdir -p "$out/lib"
    $CXX -x c++ - -shared -fPIC -o "$out/lib/libanswer.so" <<'CPP'
    extern "C" int answer() { return 42; }
    CPP
  '';
in
assert stdenv.cc.cc.drvPath == pkgs.stdenv.cc.cc.drvPath;
assert stdenv.cc.libc.drvPath == pkgs.stdenv.cc.libc.drvPath;
assert stdenv.cc.targetPrefix == pkgs.stdenv.cc.targetPrefix;
assert stdenv.hostPlatform == pkgs.stdenv.hostPlatform;
assert stdenv.cc.bintools.bintools.drvPath == pkgs.stdenv.cc.bintools.bintools.drvPath;
assert !expectLld -> stdenv.cc.drvPath == pkgs.stdenv.cc.drvPath;
stdenv.mkDerivation {
  name = "gestalt-link-toolchain-${stdenv.hostPlatform.config}";
  dontUnpack = true;
  buildInputs = [ answer ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    # No explicit RPATH: the Nix wrapper must discover the target library.
    $CXX -x c++ - -L${answer}/lib -lanswer -o "$out/bin/check" <<'CPP'
    extern "C" int answer();
    int main() { return answer() == 42 ? 0 : 1; }
    CPP
    $LD --version > linker-version.txt
    ${lib.optionalString expectLld ''
      grep -q LLD linker-version.txt
    ''}
    runHook postInstall
  '';
  # mkDerivation disables installCheckPhase for cross builds. These metadata
  # checks use build-platform tools and must run for cross outputs as well.
  postFixup = ''
    ${stdenv.cc.bintools.targetPrefix}readelf -h "$out/bin/check" > elf-header.txt
    ${stdenv.cc.bintools.targetPrefix}readelf -d "$out/bin/check" > dynamic.txt
    ${stdenv.cc.bintools.targetPrefix}readelf -l "$out/bin/check" > program-headers.txt
    grep -F '${answer}/lib' dynamic.txt
    grep -F "$(cat ${stdenv.cc.bintools}/nix-support/dynamic-linker)" program-headers.txt
    ${lib.optionalString canExecute ''
      env -u LD_LIBRARY_PATH "$out/bin/check"
    ''}
    cp linker-version.txt elf-header.txt dynamic.txt program-headers.txt "$out/"
  '';
}
