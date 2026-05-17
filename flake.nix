{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      inputs.nixFork.url = "github:lomenzel/nix";

  outputs =
    { self, nixpkgs, ... }@inputs:
    {
      devShells = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              inputs.nixFork.packages.${system}.nix
              pkgs.nodejs
              pkgs.nixd
              pkgs.lldb
              (pkgs.writeShellScriptBin "clangd" ''
                #!/bin/sh
                exec "${pkgs.clang-tools}/bin/clangd" --query-driver="$(which g++)" $@
              '')
              (pkgs.writeShellScriptBin "qmlls" ''
                #!/bin/sh
                exec "${pkgs.kdePackages.qtdeclarative}/bin/qmlls" \
                      --no-cmake-calls \
                      -I ${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml \
                      -I ${pkgs.kdePackages.kirigami.unwrapped}/lib/qt-6/qml \
                       $@
              '')
            ];
            nativeBuildInputs = [ ];
            CMAKE_EXPORT_COMPILE_COMMANDS = true;
            LANG = "C.UTF-8";
            shellHook = ''
              # Qt/KDE runtime paths so locally-built (unwrapped) binaries find QML modules & plugins.
              # NIXPKGS_QML_SEARCH_PATHS is populated by wrapQtAppsHook from all Qt/KDE buildInputs.
              export QML2_IMPORT_PATH="$NIXPKGS_QML_SEARCH_PATHS''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

              # Generate .clangd config with Qt base include paths and query-driver.
              # CMake's compile_commands.json only has per-module dirs (e.g. include/QtWidgets)
              # but not the parent dirs needed to resolve transitive includes like
              # <QtWidgets/qapplication.h>. Nix's gcc-wrapper injects these via
              # NIX_CFLAGS_COMPILE, but clangd doesn't see them.
              cat > .clangd <<EOF
              CompileFlags:
                CompilationDatabase: build/
                Add:
                  - -isystem
                  - ${pkgs.kdePackages.qtbase}/include
                  - -isystem
                  - ${pkgs.kdePackages.qtdeclarative}/include
              EOF
            '';
          };
        }
      );
    };
}
