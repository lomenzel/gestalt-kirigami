{
  description = "Gestalt Kirigami Target with Native Wechselbalg C++ Integration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    wechselbalg.url = "github:lomenzel/wechselbalg";
  };

  outputs =
    {
      self,
      nixpkgs,
      wechselbalg,
      ...
    }:
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
                wechselbalg.overlays.default
              ];
            };
          }

        );
    in
    {
      overlays.default = final: prev: {
        gestaltPlatform = (prev.gestaltPlatform or { }) // {
          targets = (prev.gestaltPlatform.targets or { }) // {
            kirigami = import ./. {
              inherit (final) lib;
              pkgs = final;
              inherit self;
            };
          };
        };
      };

      checks = eachSystem (
        { pkgs, ... }:
        pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          link-toolchain = import ./tests/link-toolchain.nix { inherit pkgs; };
        }
        // pkgs.lib.optionalAttrs (pkgs.stdenv.buildPlatform.system == "x86_64-linux") {
          link-toolchain-aarch64 = import ./tests/link-toolchain.nix {
            pkgs = pkgs.pkgsCross.aarch64-multiplatform;
          };
        }
      );
    };
}
