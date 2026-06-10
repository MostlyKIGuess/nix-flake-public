{ inputs, pkgs, ... }:
let
  stablePkgs = import inputs.nixpkgs-stable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  lutris-clean = pkgs.writeShellScriptBin "lutris-clean" ''
    unset ACLOCAL_PATH
    unset GIO_EXTRA_MODULES
    unset GST_PLUGIN_SYSTEM_PATH
    unset GST_PLUGIN_SYSTEM_PATH_1_0
    unset LD_LIBRARY_PATH
    unset LD_PRELOAD
    unset NIX_CFLAGS_COMPILE
    unset NIX_CFLAGS_LINK
    unset NIX_LD
    unset NIX_LDFLAGS
    unset NIX_LD_LIBRARY_PATH
    unset PKG_CONFIG_PATH

    exec ${stablePkgs.lutris}/bin/lutris "$@"
  '';
in
{
  programs.gamemode.enable = true;

  environment.systemPackages =
    (with stablePkgs; [
      lutris
      transmission_4-gtk
      wineWow64Packages.stable
      protonup-qt
    ])
    ++ [
      lutris-clean
    ];
}
