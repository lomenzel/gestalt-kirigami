{
  lib,
  stdenv,
  rustPlatform,
  protobuf,
  openssl,
  pkg-config,
}:
rustPlatform.buildRustPackage {
  pname = "gestalt-veilid-bridge";
  version = "0.1.0";
  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [
    pkg-config
    protobuf # Compiles protos on the build machine
  ];

  buildInputs = [
    openssl # Target architecture openssl
  ];

  # Disables check when cross-compiling to prevent running target binaries on the build host
  doCheck = stdenv.buildPlatform == stdenv.hostPlatform;

  installPhase = ''
    mkdir -p $out/lib $out/include
    cp target/*/release/libgestalt_veilid_bridge.a $out/lib/ || cp target/release/libgestalt_veilid_bridge.a $out/lib/
    cat << 'EOF' > $out/include/gestalt_veilid.h
    #pragma once
    #include <stdint.h>
    #include <stdbool.h>

    #ifdef __cplusplus
    extern "C" {
    #endif

    typedef void (*VeilidEventCallback)(const char *json);
    typedef void (*VeilidResponseCallback)(uint64_t request_id, const char *json);

    bool gestalt_veilid_init(const char *config_json, VeilidEventCallback cb);
    void gestalt_veilid_run_effect(const char *effect_json, VeilidResponseCallback cb, uint64_t request_id);

    #ifdef __cplusplus
    }
    #endif
    EOF
  '';
}