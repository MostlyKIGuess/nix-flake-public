{ pkgs, ... }:
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

  gtk.iconTheme.name = "Papirus-Dark";

  home.packages = with pkgs; [
    playerctl
    bc
    jq
    brightnessctl
    rofi
    papirus-icon-theme
    libnotify
    slurp
    grim
    xwayland-satellite-unstable
    nwg-look
  ];

  services.playerctld.enable = true;
}
