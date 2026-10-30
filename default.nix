{
  lib,
  pkgs,
  self,
  ...
}:
let
  # 1. Cross-compiled Veilid Bridge
  veilidBridge = pkgs.callPackage ./pkgs/veilid-bridge { };

  # 2. Runtime: Builds with the cross-compiler automatically when in pkgsCross
  kirigamiRuntime = pkgs.stdenv.mkDerivation {
    pname = "gestalt-kirigami-runtime";
    version = "0.1.0";
    src = ./runtime;

    patchPhase = ''
      mkdir -p include
      cp ${pkgs.writeText "wechselbalg.hpp" (pkgs.lib.cppRuntime or lib.cppRuntime)} include/wechselbalg.hpp
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
      appLib = (lib.mkCppLibrary {
        value = ir;
        namespace = "GestaltApp";
      }).mkDerivation pkgs;
    in
    pkgs.stdenv.mkDerivation {
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
        $CXX -O2 -std=c++20 \
          ${kirigamiRuntime}/share/gestalt/main.cpp \
          -I${kirigamiRuntime}/include/gestalt \
          -Wl,--start-group "$appArchive" -Wl,--end-group \
          -L${kirigamiRuntime}/lib -lgestalt_kirigami_runtime \
          -L${veilidBridge}/lib -lgestalt_veilid_bridge \
          -Wl,-rpath,${kirigamiRuntime}/lib \
          -o $out/bin/${pname}
      '';
    };
}