{
  lib,
  pkgs,
  defaultCapabilities,
  standardPageView,
  ...
}:
{
  gestaltPlatform.targets.kirigami = {
    buildApplication =
      ir:
      let
        appLib =
          (lib.mkCppLibrary {
            value = ir;
            namespace = "app";
          }).mkDerivation
            pkgs;
      in
      pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = ir.meta.name;
        version = ir.meta.version;
        src = ./.;
        nativeBuildInputs = with pkgs; [
          kdePackages.wrapQtAppsHook
          kdePackages.extra-cmake-modules
        ];
        buildInputs = [
          appLib
        ]
        ++ (
          with pkgs;
          with kdePackages;
          [
            qtdeclarative
            cmake
            kirigami
            ninja
            kcoreaddons
          ]
        );
        APP_TITLE = ir.meta.title;
        APP_NAME = ir.meta.name;
        APP_LIB_PATH = "${appLib}";
        passthru =
          let
            sizes = {
              desktop = "1280x720";
              tablet = "768x1024";
              mobile = "360x720";
            };
            modes = [
              "light"
              "dark"
            ];
            qtStyles = [
              "Material"
              "Fusion"
              "FluentWinUI3"
              "Universal"
            ];

            makeScreenshot =
              sizeName: geom: modeName: styleName:
              pkgs.runCommand "${ir.meta.name}-screenshot-${sizeName}-${modeName}-${styleName}"
                {
                  nativeBuildInputs = [
                    pkgs.xvfb-run
                    pkgs.imagemagick
                  ];
                }
                ''
                  mkdir -p $out
                  export HOME=$TMPDIR

                  export QT_QPA_PLATFORM=xcb
                  export QT_QUICK_BACKEND=software

                  export QT_QPA_PLATFORMTHEME=kde

                  export QT_PLUGIN_PATH="${pkgs.kdePackages.plasma-integration}/${pkgs.qt6.qtbase.qtPluginPrefix}:''${QT_PLUGIN_PATH:-}"

                  mkdir -p "$HOME/.config"
                  export QT_QUICK_CONTROLS_STYLE="${styleName}"

                  if [ "${modeName}" = "dark" ]; then
                    cp "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors" "$HOME/.config/kdeglobals"
                    
                    export QT_QUICK_CONTROLS_MATERIAL_THEME=Dark
                    export QT_QUICK_CONTROLS_UNIVERSAL_THEME=Dark
                  else
                    cp "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeLight.colors" "$HOME/.config/kdeglobals"
                    export QT_QUICK_CONTROLS_MATERIAL_THEME=Light
                    export QT_QUICK_CONTROLS_UNIVERSAL_THEME=Light
                  fi

                  xvfb-run --server-args="-screen 0 ${geom}x24" sh -c '
                    "${finalAttrs.finalPackage}/bin/${ir.meta.name}" -qwindowgeometry ${geom} &
                    APP_PID=$!
                    
                    sleep 3
                    import -window root "$out/screenshot.png"
                    
                    kill "$APP_PID"
                  '
                '';
            screenshots = lib.mapAttrs (
              sizeName: geom:
              lib.genAttrs modes (
                modeName: lib.genAttrs qtStyles (styleName: makeScreenshot sizeName geom modeName styleName)
              )
            ) sizes;

            allScreenshots = pkgs.runCommand "${ir.meta.name}-screenshots-all" { } ''
              mkdir -p $out
              ${lib.concatStringsSep "\n" (
                lib.flatten (
                  lib.mapAttrsToList (
                    sizeName: modesSet:
                    lib.mapAttrsToList (
                      modeName: stylesSet:
                      lib.mapAttrsToList (
                        styleName: drv: "ln -s ${drv}/screenshot.png $out/${sizeName}_${modeName}_${styleName}.png"
                      ) stylesSet
                    ) modesSet
                  ) screenshots
                )
              )}
            '';
          in
          {
            screenshot = allScreenshots // screenshots;
          };
      });
    effects = defaultCapabilities.Effects;
    components = {
      displayValue =
        {
          label,
          tooltip ? "",
          value,
          ...
        }:
        {
          _type = "displayValue";
          inherit label tooltip value;
        };
      action =
        {
          name,
          tooltip ? "",
          onClick,
          ...
        }:
        {
          _type = "action";
          inherit name tooltip onClick;
        };
      actionGroup =
        { actions, ... }:
        {
          _type = "actionGroup";
          # Hand-rolled to avoid pulling lib.mapAttrsToList (and transitively
          # all of lib) into the reified IR.
          actions = map (id: actions.${id} // { inherit id; }) (builtins.attrNames actions);
        };
      section = x: x;
    };
    modules = [ standardPageView ];
    name = "kirigami";
  };
}
