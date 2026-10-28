{ config, lib, pkgs, ... }:
{
  imports = [
    ./binds.nix
    ./settings.nix
    ./rules.nix
  ];

  programs.niri = {
    enable = true;
    package = pkgs.niri-unstable;
  };

  xdg.configFile.niri-config.source = lib.mkForce (
    pkgs.runCommand "config.kdl"
      {
        config = config.programs.niri.finalConfig + "\n";
        passAsFile = [ "config" ];
        buildInputs = [ config.programs.niri.package ];
      }
      ''
        niri validate -c $configPath
        cp $configPath $out
      ''
  );

  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    gtk4.theme = null;
    iconTheme = {
      name = "Colloid-Grey-Dark";
      package = pkgs.colloid-icon-theme.override { colorVariants = [ "grey" ]; };
    };
  };

  home.packages = with pkgs; [
    playerctl
    bc
    jq
    brightnessctl
    rofi
    libnotify
    slurp
    grim
    xwayland-satellite-unstable
    nwg-look
  ];

  services.playerctld.enable = true;
}
