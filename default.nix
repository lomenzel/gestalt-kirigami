{
  lib,
  pkgs,
  self,
  ...
}:
let
  # 1. Cross-compiled Veilid Bridge
  veilidBridge = pkgs.callPackage ./pkgs/veilid-bridge { };

  # Only final applications use LLD; runtime and generated objects keep their
  # original toolchain and cache identities.
  linkStdenv =
    let
      inherit (pkgs.stdenv) hostPlatform;
      originalBintools = pkgs.stdenv.cc.bintools;
      useLld =
        hostPlatform.isLinux
        && (
          hostPlatform.isx86 || hostPlatform.isAarch64 || hostPlatform.isAarch32 || hostPlatform.isRiscV64
        )
        && pkgs.stdenv.cc.isGNU
        && originalBintools.isGNU
        && !originalBintools.nativeTools;
      bintools = originalBintools.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          # Keep Nix's ld-wrapper for RPATHs, hardening, and cross flags.
          # LLD runs on the build platform but links for the original target.
          substituteInPlace "$out/bin/${originalBintools.targetPrefix}ld" \
            --replace-fail \
              "${lib.getBin originalBintools.bintools}/bin/${originalBintools.targetPrefix}ld" \
              "${pkgs.buildPackages.llvmPackages.lld}/bin/ld.lld"
        '';
      });
    in
    if useLld then
      pkgs.overrideCC pkgs.stdenv (pkgs.stdenv.cc.override { inherit bintools; })
    else
      pkgs.stdenv;

  # 2. Runtime: Builds with the cross-compiler automatically when in pkgsCross
  kirigamiRuntime = pkgs.stdenv.mkDerivation {
    pname = "gestalt-kirigami-runtime";
    version = "0.1.0";
    src = ./runtime;

    patchPhase = ''
      mkdir -p include
      cp ${
        pkgs.writeText "wechselbalg.hpp" (pkgs.lib.cppRuntime or lib.cppRuntime)
      } include/wechselbalg.hpp
    '';

    nativeBuildInputs = [
      pkgs.cmake
      pkgs.ninja
      pkgs.kdePackages.extra-cmake-modules
      pkgs.qt6.wrapQtAppsHook
    ];

    buildInputs = [
      veilidBridge
      pkgs.qt6.qtbase
      pkgs.qt6.qtdeclarative
      pkgs.kdePackages.kirigami
      pkgs.wasmtime.dev
    ];
  };

  # The entry point is independent of the application IR. Compile it once per
  # runtime/target rather than reparsing the runtime headers on every UI edit.
  appMain =
    pkgs.runCommandCC "gestalt-kirigami-main.o"
      {
        buildInputs = [
          kirigamiRuntime
          pkgs.wasmtime.dev
        ];
      }
      ''
        $CXX -O2 -std=c++20 -c \
          ${kirigamiRuntime}/share/gestalt/main.cpp \
          -I${kirigamiRuntime}/include/gestalt \
          -o "$out"
      '';
in
{
  input = self;
  name = "kirigami";

  buildApplication =
    ir:
    let
      meta = ir.meta or (throw "kirigami target: ir.meta is required");
      pname = meta.name or (throw "kirigami target: ir.meta.name is required");
      version = meta.version or "0.1.0";

      # Wechselbalg builds the app IR with target toolchain
      appLib =
        (lib.mkCppLibrary {
          value = ir;
          namespace = "GestaltApp";
        }).mkDerivation
          pkgs;
    in
    linkStdenv.mkDerivation {
      inherit pname version;
      dontUnpack = true;

      nativeBuildInputs = [
        pkgs.qt6.wrapQtAppsHook
      ];

      buildInputs = [
        kirigamiRuntime
        appLib
        veilidBridge
        pkgs.qt6.qtbase
        pkgs.qt6.qtdeclarative
        pkgs.kdePackages.kirigami
        pkgs.wasmtime
      ];

      installPhase = ''
        mkdir -p $out/bin

        appArchive=$(find ${appLib}/lib -maxdepth 1 -name "*.a" | head -n 1)

        # $CXX is the target cross-compiler (e.g., armv7l-unknown-linux-gnueabihf-g++)
        $CXX ${appMain} \
          -Wl,--start-group "$appArchive" -Wl,--end-group \
          -L${kirigamiRuntime}/lib -lgestalt_kirigami_runtime \
          -L${veilidBridge}/lib -lgestalt_veilid_bridge \
          -Wl,-rpath,${kirigamiRuntime}/lib \
          -o $out/bin/${pname}
      '';
    };
}
