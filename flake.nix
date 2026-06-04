{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixFork.url = "github:lomenzel/nix";
    core.url = "git+https://rad-node.menzel.lol/rad:zC4kuEr7XGt6qAcTt5JtJ7pCxZE8";
  };

  outputs =
    {
      self,
      nixpkgs,
      core,
      ...
    }@inputs:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                self.overlays.default
                core.overlays.default
              ];
            };
          }
        );
    in
    {
      overlays.default = final: prev: {
        gestaltPlatform = (prev.gestaltPlatform or { }) // {
          targets = (prev.gestaltPlatform.targets or { }) // {
            kirigami = final.gestaltPlatform.makeTarget (import ./. { inherit self; });
          };
        };
      };
      packages = eachSystem (
        { pkgs, system }:
        {
          default = pkgs.gestaltPlatform.buildApplication {
            src = "${
              pkgs.fetchgit {
                url = "https://rad-node.menzel.lol/rad:zWwaJKS7H5FDQPQH8rk7Qhw4W2KD";
                rev = "1dd97579262f566504c8899ad60cadf3316198a9";
                hash = "sha256-ekuvsivDoC6seZK+64o+PTAiJIV13VHhpiR6qwE8tTE=";
              }
            }/src";
            target = pkgs.gestaltPlatform.targets.kirigami;
          };
        }
      );
      devShells = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
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
