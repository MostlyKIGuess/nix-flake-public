{ inputs, pkgs, ... }:
{
  imports = [
    ./binds.nix
    ./settings.nix
    ./rules.nix
  ];

  programs.niri = {
    enable = true;
    # Use the niri-flake's own unstable package rather than relying on
    # a separate unstable nixpkgs channel.
    package = inputs.niri-flake.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  };

  gtk.iconTheme.name = "Papirus-Dark";

  home.packages = with pkgs; [
    swww
    playerctl
    bc
    jq
    brightnessctl
    rofi
    papirus-icon-theme
    libnotify
    slurp
    grim
    cliphist
    xwayland-satellite
    nwg-look
  ];

  services.playerctld.enable = true;
}
